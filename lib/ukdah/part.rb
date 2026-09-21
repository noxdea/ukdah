# frozen_string_literal: true

module Ukdah
  Part = Struct.new(:content_type, :parameters, :disposition, :filename,
                    :content_id, :encoding, :body, :parts, keyword_init: true) do
    def multipart?
      content_type.to_s.start_with?("multipart/")
    end

    def leaf?
      !multipart? && Array(parts).empty?
    end

    def each_leaf(&block)
      return enum_for(:each_leaf) unless block

      if Array(parts).empty?
        yield self
      else
        parts.each { |part| part.each_leaf(&block) }
      end
    end

    def media_type
      content_type.to_s.split("/", 2).first.to_s
    end

    def subtype
      content_type.to_s.split("/", 2).last.to_s
    end
  end
end
