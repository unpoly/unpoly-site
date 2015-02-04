module Upjs
  module Guide
    class Param
      include Logger

      def initialize(name = nil)
        @name = name
        @types = []
        @guide_markdown = ''
        @optional = false
        @default = nil
      end

      attr_accessor :optional
      attr_accessor :name
      attr_accessor :types
      attr_accessor :guide_markdown
      attr_accessor :default

      alias_method :optional?, :optional

      def option?
        name =~ /^options\./
      end

    end
  end
end
