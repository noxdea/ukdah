# frozen_string_literal: true

module Ukdah
  module Header
    ENCODED_WORD = /=\?([^?\s]+)\?([bBqQ])\?([^?]*)\?=/
    BASE64_ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

    module_function

    def parse(section, diagnostics = nil)
      result = Hash.new { |hash, key| hash[key] = [] }
      current = nil
      section.to_s.split(/\r?\n/, -1).each do |line|
        if line.match?(/\A[ \t]/)
          if current
            current[:value] << " " << line.strip
          elsif diagnostics
            diagnostics << "header continuation without a header"
          end
        elsif (match = line.match(/\A([^:]+):(.*)\z/))
          current = { name: match[1].strip.downcase, value: match[2].strip }
          result[current[:name]] << current[:value]
        elsif !line.empty? && diagnostics
          diagnostics << "malformed header ignored: #{line.byteslice(0, 80)}"
        end
      end
      result
    end

    def decode(value)
      original = value.to_s
      return original unless original.include?("=?")

      text = value.to_s.dup.force_encoding(Encoding::BINARY)
      loop do
        changed = text.gsub(/(=\?[^?\s]+\?[bBqQ]\?[^?]*\?=)[ \t\r\n]+(?==\?)/, "\\1")
        break if changed == text

        text = changed
      end
      text.gsub(ENCODED_WORD) do
        decode_word(Regexp.last_match(1), Regexp.last_match(2), Regexp.last_match(3))
      end
    rescue StandardError
      value.to_s
    end

    def decode_word(charset, mode, payload)
      bytes = if mode.casecmp("b").zero?
                decode_base64(payload)
              else
                payload.tr("_", " ").gsub(/=([0-9A-Fa-f]{2})/) { Regexp.last_match(1).to_i(16).chr }
              end
      Ukdah.decode_bytes(bytes, charset)
    rescue StandardError
      payload
    end

    def decode_base64(payload)
      buffer = 0
      bits = 0
      output = []
      payload.to_s.each_byte do |byte|
        char = byte.chr
        next if char == "=" || char.match?(/[ \t\r\n]/)

        value = BASE64_ALPHABET.index(char)
        next if value.nil?

        buffer = (buffer << 6) | value
        bits += 6
        while bits >= 8
          bits -= 8
          output << ((buffer >> bits) & 0xff)
        end
      end
      output.pack("C*")
    end

    def split_parameters(value)
      pieces = []
      current = +""
      quoted = false
      escaped = false
      value.to_s.each_char do |char|
        if escaped
          current << char
          escaped = false
        elsif char == "\\" && quoted
          current << char
          escaped = true
        elsif char == '"'
          quoted = !quoted
          current << char
        elsif char == ";" && !quoted
          pieces << current.strip
          current = +""
        else
          current << char
        end
      end
      pieces << current.strip unless current.empty?
      pieces
    end

    def unquote(value)
      text = value.to_s.strip
      text = text[1...-1] if text.start_with?('"') && text.end_with?('"') && text.length >= 2
      text.gsub(/\\(.)/, '\\1')
    end

    def content_type(value, diagnostics = nil)
      parse_parameterized(value, diagnostics)
    end

    def disposition(value, diagnostics = nil)
      parse_parameterized(value, diagnostics)
    end

    def parse_parameterized(value, diagnostics = nil)
      pieces = split_parameters(value)
      main = pieces.shift.to_s.strip.downcase
      raw = {}
      pieces.each do |piece|
        name, parameter = piece.split("=", 2)
        if parameter.nil?
          diagnostics << "malformed parameter ignored: #{piece}" if diagnostics
          next
        end
        raw[name.to_s.strip.downcase] = unquote(parameter)
      end
      [main, decode_parameters(raw, diagnostics)]
    end

    def decode_parameters(raw, diagnostics = nil)
      parameters = {}
      grouped = Hash.new { |hash, key| hash[key] = [] }
      raw.each do |name, value|
        if (match = name.match(/\A(.+)\*(\d+)(\*)?\z/))
          grouped[match[1]] << [match[2].to_i, !match[3].nil?, value]
        elsif name.end_with?("*")
          parameters[name[0...-1]] = decode_extended(value, diagnostics)
        else
          parameters[name] = value
        end
      end
      grouped.each do |name, segments|
        segments.sort_by!(&:first)
        expected = 0
        charset = nil
        encoded = +""
        segments.each do |index, is_encoded, value|
          if index != expected
            diagnostics << "missing RFC 2231 parameter segment: #{name}*#{expected}" if diagnostics
            expected = index
          end
          expected += 1
          segment = value
          if index.zero? && is_encoded && segment =~ /\A([^']*)'[^']*'(.*)\z/m
            charset = Regexp.last_match(1)
            segment = Regexp.last_match(2)
          end
          encoded << (is_encoded ? percent_decode(segment) : segment)
        end
        parameters[name] = Ukdah.decode_bytes(encoded, charset)
      end
      parameters
    end

    def decode_extended(value, diagnostics = nil)
      text = value.to_s
      if text =~ /\A([^']*)'[^']*'(.*)\z/m
        Ukdah.decode_bytes(percent_decode(Regexp.last_match(2)), Regexp.last_match(1))
      else
        diagnostics << "malformed RFC 2231 parameter" if diagnostics
        percent_decode(text)
      end
    end

    def percent_decode(value)
      value.to_s.gsub(/%([0-9A-Fa-f]{2})/) { Regexp.last_match(1).to_i(16).chr }
    end

    def message_ids(value)
      value.to_s.scan(/<([^>]+)>/).flatten.tap do |ids|
        if ids.empty?
          ids.concat(value.to_s.split(/[ \t,]+/).map { |id| id.gsub(/[<>]/, "") }.reject(&:empty?))
        end
      end
    end
  end
end
