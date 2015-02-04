module Upjs
  module Guide
    # This is actually "return", but that's reserved in Ruby.
    class Response
      include Logger

      def initialize
        @types = []
        @guide_markdown = ''
      end

      attr_accessor :types
      attr_accessor :guide_markdown

    end
  end
end
