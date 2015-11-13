module Upjs
  module Guide
    class Klass
      include Logger

      def initialize(name)
        @name = name
        @visibility = 'public'
        @features = []
        @guide_markdown = ''
        @title
      end

      attr_accessor :visibility
      attr_accessor :name
      attr_accessor :guide_markdown
      attr_reader :features
      attr_accessor :title

      def guide_filename(extension)
        "#{@name}#{extension}"
      end

      attr_accessor :guide_markdown

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

    end
  end
end

