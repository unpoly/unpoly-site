module Unpoly
  module Guide
    class Feature
      include Documentable
      include Memoized
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
        @interface = nil
      end

      attr_accessor :response
      attr_accessor :visibility
      attr_accessor :params
      attr_accessor :interface
      attr_accessor :params_note

      def visibility_comment
        comment = @visibility_comment&.strip
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
            '**This feature is experimental**. Please [share](https://github.com/unpoly/unpoly/discussions) your experiences so we know what to keep or change.'
          end
        end
      end

      def menu_title
        title = short_signature
        if function? || property?
          title = title.sub('.prototype.', '#')
        end
        title
      end

      def signature(short: false)
        if selector? || event? || header? || cookie?
          name

        elsif property?
          signature = ''
          signature << name
          # if params.present?
          #   signature << ' = '
          #   signature << (params[0].option_hash_name || params[0].name)
          # end
          signature

        elsif function? || constructor?

          signature = ""
          if constructor?
            signature << 'new '
          end

          signature << name
          signature << '('

          unless short
            option_params = published_params.select(&:option?)

            compressed_params = published_params.collect { |param|
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
          end

          signature << ')'
          signature
        else
          raise "Unknown feature kind: #{kind}"
        end
      end

      def short_signature
        signature(short: true)
      end

      def title
        short_signature
      end

      def code?
        true
      end

      def published_params
        params.select(&:published?)
      end

      def short_kind
        case kind
        when 'selector'
          if name.starts_with?(':')
            'CSS'
          else
            'HTML'
          end
        when 'function', 'constructor', 'property', 'event'
          'JS'
        when 'header', 'cookie'
          'HTTP'
        else
          "Unhandled feature kind: #{kind}"
        end
      end

      def long_kind
        case kind
        when 'selector'
          'HTML selector'
        when 'constructor'
          'Class constructor'
        when 'function'
          if interface.class?
            if instance_method?
              'Instance method'
            elsif class_method?
              'Class method'
            else
              raise "Unknown method nature"
            end
          else
            'JavaScript function'
          end
        when 'event'
          'DOM event'
        when 'property'
          if interface.class?
            'Property'
          elsif config?
            'Configuration object'
          else
            'JavaScript property'
          end
        when 'header'
          'HTTP header'
        when 'cookie'
          'Cookie'
        else
          "Unhandled feature kind: #{kind}"
        end
      end

      # def preventable?
      #   @preventable
      # end

      # def guide_anchor
      #   Util.slugify(name)
      # end

      # def search_text
      #   strings = []
      #   strings << name
      #   strings << interface.name
      #   # strings << short_kind
      #   if selector?
      #     strings += params.collect(&:name)
      #   elsif property?
      #     strings += params.select(&:option?).collect(&:name)
      #   end
      #   parts = []
      #   strings.each do |string|
      #      unless parts.any? { |part| part.include?(string) }
      #        parts << string.downcase
      #      end
      #   end
      #   parts.join(' ')
      # end

      def name
        str = super
        if function? || property?
          str = str.sub('#', '.prototype.')
        end
        str
      end

      def index_name
        str = name

        # Constructors and "classes" are the same thing
        # in JS, but we want two separate guide pages
        if constructor? && str !~ /\bnew\b/
          str += ".new"
        end

        str
      end

      memoize def param_groups
        groups = params.group_by { |param| param.option_hash_name || param.name }
        groups.map { |group|
          if group.first.option?
            OptionsParam.new(group)
          else
            group.first
          end
        }
      end

      def options_params
        param_groups.select { |group| group.is_a?(OptionsParam) }
      end

      def children
        super + params
      end

      def menu_modifiers
        [visibility]
      end

      def guide_page?
        !internal?
      end

    end

  end
end
