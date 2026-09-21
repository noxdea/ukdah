# frozen_string_literal: true

module Ukdah
  module Quote
    module_function

    def segments(text)
      groups = []
      text.to_s.split(/\r?\n/, -1).each do |line|
        depth = line[/\A(?:>\s*)+/].to_s.count(">")
        if groups.last && groups.last[0] == depth
          groups.last[1] << line
        else
          groups << [depth, [line]]
        end
      end
      groups
    end
  end
end
