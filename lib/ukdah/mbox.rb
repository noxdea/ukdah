# frozen_string_literal: true

module Ukdah
  module Mbox
    module_function

    def each(io)
      return enum_for(:each, io) unless block_given?

      data = io.respond_to?(:read) ? io.read.to_s : io.to_s
      starts = envelope_offsets(data)
      if starts.empty?
        yield Message.parse(data) unless data.empty?
        return
      end

      index = 0
      while index < starts.length
        start = starts[index]
        message_start = line_end(data, start)
        next_start = starts[index + 1] || data.bytesize
        explicit_end = content_length_end(data, message_start, next_start)
        finish = explicit_end || next_start
        finish = next_start if finish > data.bytesize
        yield Message.parse(data.byteslice(message_start, finish - message_start).to_s)
        if explicit_end
          index += 1
          index += 1 while index < starts.length && starts[index] < finish
        else
          index += 1
        end
      end
    end

    def envelope_offsets(data)
      result = []
      offset = 0
      data.to_s.each_line do |line|
        if line.match?(/\AFrom \S+ (?:Mon|Tue|Wed|Thu|Fri|Sat|Sun)\s/)
          result << offset
        end
        offset += line.bytesize
      end
      result
    end

    def line_end(data, offset)
      newline = data.index("\n", offset)
      newline ? newline + 1 : data.bytesize
    end

    def content_length_end(data, start, limit)
      lf_end = data.index("\n\n", start)
      crlf_end = data.index("\r\n\r\n", start)
      header_end = if lf_end.nil?
                     crlf_end
                   elsif crlf_end.nil?
                     lf_end
                   else
                     [lf_end, crlf_end].min
                   end
      return nil unless header_end && header_end < limit

      header = data.byteslice(start, header_end - start)
      match = header.match(/(?:\A|\r?\n)Content-Length\s*:\s*(\d+)/i)
      return nil unless match

      separator_length = data.byteslice(header_end, 4) == "\r\n\r\n" ? 4 : 2
      header_end + separator_length + match[1].to_i
    end
  end
end
