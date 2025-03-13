module Unpoly
  module Guide
    class Param
      include Documentable
      include Logger
      include Referencer
      include Mimic

      OPTION_PREFIX = /^(options|opts|request|response|params|config|attrs|attributes|props|properties|eventProps)\./

      def initialize(name = nil)
        @name = name
        @types = []
        @guide_markdown = ''
        @optional = nil
        @default = nil
        @feature = nil
        @explicit_visibility = nil
        @section_title = nil
      end

      attr_accessor :optional
      attr_accessor :name
      attr_accessor :types
      attr_accessor :guide_markdown
      attr_accessor :default
      attr_accessor :feature
      attr_accessor :explicit_visibility
      attr_writer :section_title

      def section_title
        @section_title || 'General'
      end

      def optional?
        if @optional.nil?
          false
        else
          @optional
        end
      end

      def required?
        !optional?
      end

      def default?
        @default.present?
      end

      def option?
        !!(name =~ OPTION_PREFIX)
      end

      def should_document_types?
        if feature.event?
          # For events we sometimes document event.preventDefault() as a @param
          feature.should_document_types? && !name.include?('(')
        else
          feature.should_document_types?
        end
      end

      def signature(with_default: true, em_name: false)
        signature = "".html_safe
        signature << "[" if optional?
        signature << '<em>'.html_safe if em_name
        signature << name
        signature << '</em>'.html_safe if em_name
        signature << "=#{default}" if with_default && default?
        signature << "]" if optional?
        signature
      end

      # def types
      #   if feature&.selector?
      #     ['Attribute']
      #   else
      #     @types
      #   end
      # end

      def title
        signature(with_default: false)
      end

      def option_hash_name
        name =~ OPTION_PREFIX
        $1
      end

      def name_without_option_prefix
        name.sub(OPTION_PREFIX, '')
      end

      def menu_title
        if feature.selector?
          "[#{name}]"
        # elsif feature.property? && option?
        #   "#{feature.name}.#{name_without_option_prefix}"
        else
          name
        end
      end

      def index_name
        "#{feature.index_name}#{super}"
      end

      def guide_path
        "#{feature.guide_path}##{guide_anchor}"
      end

      def guide_anchor
        Util.slugify(name)
      end

      def guide_page?
        # Params are rendered on the feature page.
        false
      end

      def menu_node?
        published? && (feature.selector? || feature.config?)
      end

      def visibility
        explicit_visibility || feature.visibility
      end

      def mimic!(other_param)
        if optional.nil?
          self.optional = other_param.optional
        end

        if default.nil?
          self.default = other_param.default
        end

        if types.blank?
          self.types = other_param.types
        end

        if explicit_visibility.nil?
          self.explicit_visibility = other_param.explicit_visibility
        end

        if guide_markdown.strip.blank?
          self.guide_markdown = other_param.guide_markdown
        end
      end
    end
  end
end
