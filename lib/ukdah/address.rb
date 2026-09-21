# frozen_string_literal: true

module Ukdah
  Address = Struct.new(:name, :email, :group, keyword_init: true) do
    class << self
      def parse_list(value)
        return [] if value.nil? || value.to_s.strip.empty?

        result = []
        split_top_level(value.to_s, ",").each do |token|
          if token =~ /\A\s*(.*?)\s*:\s*(.*?)\s*;\s*\z/m
            group = clean_name(Regexp.last_match(1))
            split_top_level(Regexp.last_match(2), ",").each do |member|
              address = parse_one(member, group)
              result << address if address
            end
          else
            address = parse_one(token, nil)
            result << address if address
          end
        end
        result
      end

      private

      def parse_one(token, group)
        value = remove_comments(token.to_s).strip
        return nil if value.empty?

        if value =~ /\A(.*?)\s*<\s*([^<>]+?)\s*>\s*\z/m
          name = clean_name(Regexp.last_match(1))
          email = Regexp.last_match(2).strip
        else
          name = nil
          email = value.gsub(/[<>]/, "").strip
        end
        return nil if email.empty?

        Address.new(name: name, email: email, group: group)
      end

      def clean_name(value)
        name = value.to_s.strip
        if name.start_with?('"') && name.end_with?('"') && name.length >= 2
          name = name[1...-1].gsub(/\\(.)/, '\\1')
        end
        Header.decode(name).strip
      end

      def remove_comments(value)
        result = +""
        depth = 0
        quoted = false
        escaped = false
        value.each_char do |char|
          if escaped
            result << char if depth.zero?
            escaped = false
          elsif char == "\\" && quoted
            result << char if depth.zero?
            escaped = true
          elsif char == '"' && depth.zero?
            quoted = !quoted
            result << char
          elsif char == "(" && !quoted
            depth += 1
          elsif char == ")" && depth.positive?
            depth -= 1
          elsif depth.zero?
            result << char
          end
        end
        result
      end

      def split_top_level(value, separator)
        pieces = []
        current = +""
        quote = false
        angle = false
        comment = 0
        group = false
        escaped = false
        value.each_char do |char|
          if escaped
            current << char
            escaped = false
          elsif char == "\\" && (quote || comment.positive?)
            current << char
            escaped = true
          elsif char == '"' && comment.zero?
            quote = !quote
            current << char
          elsif char == "<" && !quote && comment.zero?
            angle = true
            current << char
          elsif char == ">" && !quote && comment.zero?
            angle = false
            current << char
          elsif char == "(" && !quote
            comment += 1
            current << char
          elsif char == ")" && comment.positive? && !quote
            comment -= 1
            current << char
          elsif char == ":" && separator == "," && !quote && !angle && comment.zero?
            group = true
            current << char
          elsif char == ";" && separator == "," && !quote && !angle && comment.zero?
            group = false
            current << char
          elsif char == separator && !quote && !angle && comment.zero? && !group
            pieces << current.strip
            current = +""
          else
            current << char
          end
        end
        pieces << current.strip unless current.strip.empty?
        pieces
      end
    end
  end
end
