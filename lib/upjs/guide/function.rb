module Upjs
  module Guide

    class Function
      include Logger

      def initialize(name)
        @name = name
        @visibility = 'public'
        @ujs = false
        @params = []
        @guide_markdown = ''
        @response = nil
        @default = nil
        @optional = false
      end

      attr_accessor :response
      attr_accessor :name
      attr_accessor :visibility
      attr_accessor :guide_markdown
      attr_accessor :params
      attr_accessor :ujs

      def signature
        signature = ""
        signature << name
        signature << '('
        signature << params.collect { |param|
          param.optional? ? "[#{param.name}]" : param.name
        }.join(", ")
        signature << ')'
        signature
      end

      def ujs?
        @ujs
      end

    end

  end
end
