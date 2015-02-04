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

        option_params = params.select(&:option?)

        compressed_params = params.collect { |param|
          if param.option?
            if option_params.all?(&:optional?)
              '[options]'
            else
              'options'
            end
          elsif param.optional?
            "[xx#{param.name}xx]"
          else
            param.name
          end
        }.uniq

        signature << compressed_params.join(', ')
        signature << ')'
        signature
      end

      def ujs?
        @ujs
      end

    end

  end
end
