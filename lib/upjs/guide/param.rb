module Upjs
  module Guide
    class Param
      include Logger

      OPTION_PREFIX = /^(options|opts|request|config)\./

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

      def required?
        not optional?
      end

      def default?
        @default.present?
      end

      def option?
        name =~ OPTION_PREFIX
      end

      def signature
        signature = ""
        signature << name
        signature << "=#{default}" if default?
        signature = "[#{signature}]" if optional?
        signature
      end

      def option_hash_name
        name =~ OPTION_PREFIX
        $1
      end

    end
  end
end
