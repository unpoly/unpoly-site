module Upjs
  module Guide
    class Klass
      include Logger

      def initialize(name)
        @name = name
        @visibility = 'public'
        @functions = []
        @guide_markdown = ''
        @title
      end

      attr_accessor :visibility
      attr_accessor :name
      attr_accessor :guide_markdown
      attr_accessor :functions
      attr_accessor :title

      def guide_filename(extension)
        "#{@name}#{extension}"
      end

      attr_accessor :guide_markdown

      def js_functions
        functions.reject(&:ujs?)
      end

      def ujs_functions
        functions.select(&:ujs?)
      end

    end
  end
end

