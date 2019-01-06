module Unpoly
  module Guide
    class Feature
      include Logger

      def initialize(kind, name)
        @name = name
        @visibility = 'internal'
        @visibility_comment = nil
        @kind = kind
        @params = []
        @guide_markdown = ''
        @response = nil
        @default = nil
        @optional = false
        @klass = nil
        # @preventable = false
      end

      attr_accessor :response
      attr_accessor :name
      attr_accessor :visibility
      attr_accessor :guide_markdown
      attr_accessor :params
      attr_accessor :event
      attr_accessor :klass
      attr_accessor :kind
      attr_accessor :text_source

      # attr_accessor :preventable

      attr_writer :visibility_comment

      def visibility_comment
        comment = @visibility_comment.strip
        if comment.present?
          if deprecated?
            "**This feature has been deprecated**. #{comment}"
          else
            comment
          end
        else
          if deprecated?
            '**This feature has been deprecated**. It will be removed in a future version.'
          elsif experimental?
            '**This feature is experimental**. It may be changed or removed in a future version without prior notice or deprecation.'
          end
        end
      end

      def signature
        if selector? || event?
          name

        elsif property?
          signature = ''
          signature << name
          # if params.present?
          #   signature << ' = '
          #   signature << (params[0].option_hash_name || params[0].name)
          # end
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
              else
                param.option_hash_name
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

      def short_signature
        if function?
          "#{name}()"
        else
          name
        end
      end

      def stable?
        visibility == 'stable'
      end

      def guide_params
        if selector?
          params.reject { |param|
            selector? && name =~ /^[a-z\-]*\[([a-z\-]+)\]$/ && $1 == param.name
          }
        else
          []
        end
      end

      def guide_params?
        guide_params.present?
      end

      def deprecated?
        visibility == 'deprecated'
      end

      def internal?
        visibility == 'internal'
      end

      def experimental?
        visibility == 'experimental'
      end

      def function?
        @kind == 'function'
      end

      def selector?
        @kind == 'selector'
      end

      def property?
        @kind == 'property'
      end

      def constructor?
        @kind == 'constructor'
      end

      def event?
        @kind == 'event'
      end

      def short_kind
        case kind
        when 'selector'
          'CSS'
        when 'function'
          'JS'
        when 'event'
          'EVENT'
        when 'property'
          'PROP'
        end
      end

      # def preventable?
      #   @preventable
      # end

      def guide_anchor
        Util.slugify(name)
      end

      def <=>(other)
        sort_name <=> other.sort_name
      end

      def sort_name
        sort_name = name.dup
        sort_name.gsub!(/[^A-Za-z0-9\-]/, '-')
        sort_name =~ /(^|\-)up\-(.*)$/
        $2 || sort_name
      end

      def search_text

        strings = []
        strings << name
        strings << klass.name
        strings << short_kind
        strings += params.collect(&:name) if selector?
        parts = []
        strings.each do |string|
           unless parts.any? { |part| part.include?(string) }
             parts << string.downcase
           end
        end
        parts.join(' ')
      end

      def summary_markdown
        Util.first_markdown_paragraph(@guide_markdown)
      end

      def guide_id
        str = name

        # Constructors and "classes" are the same thing
        # in JS, but we want two separate guide pages
        if constructor? && !str.include?('.constructor')
          str += '.constructor'
        end

        if function? || property?
          str = str.sub('#', '.prototype.')
        end

        Util.slugify(str)
      end

      def guide_path
        "/#{guide_id}"
      end

    end

  end
end
