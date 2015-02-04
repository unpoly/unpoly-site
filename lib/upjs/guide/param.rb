module Upjs
  module Guide
    class Param
      include Logger

      def initialize(name = nil)
        @name = name
        @types = []
        @guide_markdown = ''
        @optional = false
      end

      attr_accessor :optional
      attr_accessor :name
      attr_accessor :types
      attr_accessor :guide_markdown

    end
  end
end
