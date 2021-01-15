module Unpoly
  module Guide
    class Interface
      include Logger

      def initialize(kind, name)
        @kind = kind
        @name = name
        # @visibility = 'internal'
        @features = []
        @guide_markdown = ''
        @title
      end

      # attr_accessor :visibility
      attr_accessor :kind
      attr_accessor :name
      attr_accessor :guide_markdown
      attr_accessor :text_source
      attr_reader :features

      attr_accessor :explicit_title

      def title
        explicit_title.presence || name
      end

      def guide_filename(extension)
        "#{@name}#{extension}"
      end

      attr_accessor :guide_markdown

      def guide_features
        features.reject(&:internal?)
      end

      def guide_features?
        guide_features.present?
      end

      def constructor
        features.detect(&:constructor?)
      end

      def functions
        features.select(&:function?)
      end

      def instance_methods
        features.select(&:instance_method?)
      end

      def class_methods
        features.select(&:class_method?)
      end

      def properties
        features.select(&:property?)
      end

      def events
        features.select(&:event?)
      end

      def selectors
        features.select(&:selector?)
      end

      def headers
        features.select(&:header?)
      end

      def cookies
        features.select(&:cookie?)
      end

      def class?
        kind == 'class'
      end

      def module?
        kind == 'module'
      end

      def guide_id
        Util.slugify(name)
      end

      def guide_path
        "/#{guide_id}"
      end

      def summary_markdown
        Util.first_markdown_paragraph(@guide_markdown)
      end

      def inspect
        "#<#{self.class.name} @name=#{name}>"
      end

    end
  end
end

