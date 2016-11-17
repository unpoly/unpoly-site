module Unpoly
  module Guide
    class Klass
      include Logger

      def initialize(name)
        @name = name
        # @visibility = 'internal'
        @features = []
        @guide_markdown = ''
        @title
      end

      # attr_accessor :visibility
      attr_accessor :name
      attr_accessor :guide_markdown
      attr_reader :features
      attr_accessor :title

      def guide_filename(extension)
        "#{@name}#{extension}"
      end

      attr_accessor :guide_markdown

      def guide_features
        features.reject(&:internal?).sort_by(&:guide_id)
      end

      def guide_features?
        guide_features.present?
      end

      def functions
        features.select(&:function?)
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

      def guide_id
        Util.slugify(name)
      end

      def guide_path
        "/#{guide_id}"
      end

      def summary_markdown
        Util.first_markdown_paragraph(@guide_markdown)
      end

    end
  end
end

