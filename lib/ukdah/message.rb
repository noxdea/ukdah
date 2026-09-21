# frozen_string_literal: true

require "time"

module Ukdah
  class Message
    attr_reader :headers, :parts, :raw, :diagnostics

    def initialize(headers:, parts:, raw:, diagnostics: [])
      @headers = headers
      @parts = parts
      @raw = raw
      @diagnostics = diagnostics
    end

    def self.parse(bytes)
      Parser.new(bytes).parse
    end

    def header(name)
      headers_all(name).first
    end

    def headers_all(name)
      Array(@headers[name.to_s.downcase]).map { |value| Header.decode(value) }
    end

    def from
      addresses("from")
    end

    def to
      addresses("to")
    end

    def cc
      addresses("cc")
    end

    def bcc
      addresses("bcc")
    end

    def reply_to
      addresses("reply-to")
    end

    def subject
      header("subject")
    end

    def date
      value = header("date")
      return nil if value.nil? || value.empty?

      Time.rfc2822(value)
    rescue ArgumentError
      begin
        Time.parse(value)
      rescue ArgumentError
        nil
      end
    end

    def message_id
      Header.message_ids(header("message-id")).first
    end

    def in_reply_to
      Header.message_ids(header("in-reply-to"))
    end

    def references
      Header.message_ids(header("references"))
    end

    def text_part
      find_part { |part| part.content_type == "text/plain" }
    end

    def html_part
      find_part { |part| part.content_type == "text/html" }
    end

    def attachments
      leaves.select do |part|
        part.disposition == "attachment" || !part.filename.to_s.empty?
      end
    end

    def inline_parts
      leaves.each_with_object({}) do |part, result|
        next if part.content_id.to_s.empty?
        next unless part.disposition == "inline" || part.disposition.to_s.empty?

        id = normalize_content_id(part.content_id)
        result[id] = part
        result["<#{id}>"] = part
      end
    end

    def decoded(part, decoder: nil)
      return "" unless part

      bytes = part.body.to_s.dup.force_encoding(Encoding::BINARY)
      charset = part.parameters["charset"]
      if decoder
        result = decoder.arity == 1 ? decoder.call(bytes) : decoder.call(bytes, charset)
        return result.to_s
      end
      Ukdah.decode_bytes(bytes, charset)
    end

    def leaves
      parts.flat_map { |part| part.each_leaf.to_a }
    end

    private

    def addresses(name)
      headers_all(name).flat_map { |value| Address.parse_list(value) }
    end

    def find_part
      leaves.find { |part| yield part }
    end

    def normalize_content_id(value)
      value.to_s.strip.gsub(/\A<|>\z/, "").downcase
    end

    class Parser
      def initialize(bytes)
        @raw = bytes.to_s.dup.force_encoding(Encoding::BINARY)
        @diagnostics = []
      end

      def parse
        headers, body = entity(@raw)
        root = part_from(headers, body)
        parts = root.multipart? ? root.parts : [root]
        Message.new(headers: headers, parts: parts, raw: @raw, diagnostics: @diagnostics)
      rescue StandardError => error
        @diagnostics << "parser recovered from #{error.class}: #{error.message}"
        Message.new(headers: {}, parts: [], raw: @raw, diagnostics: @diagnostics)
      end

      private

      def entity(bytes)
        match = bytes.match(/\r?\n\r?\n/)
        return [Header.parse(bytes, @diagnostics), ""] unless match

        [Header.parse(bytes.byteslice(0, match.begin(0)), @diagnostics), bytes.byteslice(match.end(0)..-1).to_s]
      end

      def part_from(headers, body)
        type, parameters = Header.content_type(first(headers, "content-type"), @diagnostics)
        type = "text/plain" if type.nil? || type.empty?
        disposition, disposition_parameters = Header.disposition(first(headers, "content-disposition"), @diagnostics)
        disposition = nil if disposition.nil? || disposition.empty?
        filename = disposition_parameters["filename"] || parameters["name"]
        content_id = Header.decode(first(headers, "content-id").to_s).strip
        encoding = first(headers, "content-transfer-encoding").to_s.downcase

        if type.start_with?("multipart/")
          children = multipart_children(body, parameters["boundary"])
          return Part.new(content_type: type, parameters: parameters, disposition: disposition,
                          filename: filename, content_id: content_id, encoding: encoding,
                          body: children.empty? ? transfer_decode(body, encoding) : nil, parts: children)
        end

        Part.new(content_type: type, parameters: parameters, disposition: disposition,
                 filename: filename, content_id: content_id, encoding: encoding,
                 body: transfer_decode(body, encoding), parts: [])
      end

      def multipart_children(body, boundary)
        unless boundary && !boundary.empty?
          @diagnostics << "multipart has no boundary"
          return []
        end

        marker = "--#{boundary}"
        children = []
        current = nil
        closed = false
        body.to_s.split(/\r?\n/, -1).each do |line|
          if line =~ /\A#{Regexp.escape(marker)}(--)?[ \t]*\z/
            if current
              child = current.join("\n")
              children << part_from(*entity(child)) unless child.strip.empty?
            end
            if Regexp.last_match(1)
              current = nil
              closed = true
            else
              current = []
            end
          elsif current
            current << line
          end
        end
        if current && !current.empty?
          child = current.join("\n")
          children << part_from(*entity(child)) unless child.strip.empty?
          @diagnostics << "multipart boundary terminator missing"
        elsif !closed
          @diagnostics << "multipart boundary not found"
        end
        children
      end

      def transfer_decode(body, encoding)
        value = body.to_s.dup.force_encoding(Encoding::BINARY)
        case encoding.to_s.downcase
        when "base64"
          Header.decode_base64(value)
        when "quoted-printable"
          value.gsub(/=\r?\n/, "").gsub(/=([0-9A-Fa-f]{2})/) { Regexp.last_match(1).to_i(16).chr }
        else
          value
        end
      rescue StandardError => error
        @diagnostics << "transfer decoding failed for #{encoding}: #{error.message}"
        value
      end

      def first(headers, name)
        Array(headers[name]).first.to_s
      end
    end
  end
end
