module Unpoly
  module Guide
    class Param
      include Logger

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

      def option_hash_name
        name =~ OPTION_PREFIX
        $1
      end

      def guide_path
        "#{feature.guide_path}##{guide_anchor}"
      end

      def guide_anchor
        Util.slugify(name)
      end

    end
  end
end
