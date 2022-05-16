module Unpoly
  module Guide
    class Param
      include Documentable
      include Logger
      include Referencer

      OPTION_PREFIX = /^(options|opts|request|response|params|config|attrs|attributes|props|properties|eventProps)\./

      def initialize(name = nil)
        @name = name
        @types = []
        @guide_markdown = ''
        @optional = false
        @default = nil
        @feature = nil
      end

      attr_accessor :optional
      attr_accessor :name
      attr_accessor :types
      attr_accessor :guide_markdown
      attr_accessor :default
      attr_accessor :feature

      alias_method :optional?, :optional

      def required?
        not optional?
      end

      def default?
        @default.present?
      end

      def option?
        !!(name =~ OPTION_PREFIX)
      end

      def signature(with_default: true)
        signature = ""
        signature << name
        signature << "=#{default}" if with_default && default?
        signature = "[#{signature}]" if optional?
        signature
      end

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
        feature.selector?
      end

    end
  end
end
