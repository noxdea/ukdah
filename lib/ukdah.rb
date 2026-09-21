# frozen_string_literal: true

require_relative "ukdah/version"
require_relative "ukdah/header"
require_relative "ukdah/address"
require_relative "ukdah/part"
require_relative "ukdah/message"
require_relative "ukdah/mbox"
require_relative "ukdah/quote"
require_relative "ukdah/thread"

module Ukdah
  class Error < StandardError; end

  class << self
    def decode_bytes(bytes, charset = nil)
      value = bytes.to_s.dup.force_encoding(Encoding::BINARY)
      return value.encode("UTF-8", invalid: :replace, undef: :replace) if charset.nil? || charset.empty?

      encoding = Encoding.find(charset.to_s.strip.gsub(/\A["']|["']\z/, ""))
      value.force_encoding(encoding).encode("UTF-8", invalid: :replace, undef: :replace)
    rescue ArgumentError, Encoding::UndefinedConversionError, Encoding::InvalidByteSequenceError
      value.force_encoding(Encoding::UTF_8).encode("UTF-8", invalid: :replace, undef: :replace)
    end
  end
end
