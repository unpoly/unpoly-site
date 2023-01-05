module Unpoly
  module Guide
    # This is actually "return", but that's reserved in Ruby.
    class Response
      include Logger
      include Documentable

      def initialize
        @types = []
        @guide_markdown = ''
      end

      attr_accessor :types
      attr_accessor :guide_markdown

      def guide_page?
        # Responses are rendered on the feature page.
        false
      end

    end
  end
end
