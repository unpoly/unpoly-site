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
        @klass = nil
      end

      attr_accessor :response
      attr_accessor :name
      attr_accessor :visibility
      attr_accessor :guide_markdown
      attr_accessor :params
      attr_accessor :ujs
      attr_accessor :property
      attr_accessor :event
      attr_accessor :klass

      def signature
        if ujs?
          name

        elsif property?
          signature = name
          signature << ' = '
          signature << params[0].option_hash_name || params[0].name
          signature

        else

          signature = ""
          signature << name
          signature << '('

          option_params = params.select(&:option?)

          compressed_params = params.collect { |param|
            if param.option?
              if option_params.all?(&:optional?)
                "[#{param.option_hash_name}]"
              elsif option_params.all?(&:required?)
                param.option_hash_name
              else
                param.name
              end
            elsif param.optional?
              "[#{param.name}]"
            else
              param.name
            end
          }.uniq

          signature << compressed_params.join(', ')
          signature << ')'
          signature
        end
      end

      def ujs?
        @ujs
      end

      def property?
        @property
      end

      def event?
        @event
      end

      def private?
        visibility == 'private'
      end

      def guide_path
        "#{@klass.guide_path}##{guide_anchor}"
      end

      def guide_anchor
        anchor = name.dup
        anchor.gsub!(/[^a-zA-Z0-9\-\_\.]/, '-')
        anchor.gsub!(/\-{2,}/, '-')
        anchor.gsub!(/^\-+/, '')
        anchor.gsub!(/\-+$/, '')
        anchor
      end

    end

  end
end
