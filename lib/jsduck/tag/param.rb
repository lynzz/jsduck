require "jsduck/tag/tag"

module JsDuck::Tag
  class Param < Tag
    def initialize
      @pattern = "param"
    end

    # @param {Type} [name=default] (optional) ...
    def parse(p)
      tag = p.standard_tag({:tagname => :param})
      tag[:optional] = true if parse_optional(p)
      tag
    end

    def parse_optional(p)
      p.hw.match(/\(optional\)/i)
    end
  end
end
