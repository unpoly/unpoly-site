module Unpoly
  module Guide
    # This is actually "return", but that's reserved in Ruby.
    class Response
      include Logger
      include Documentable
      include Mimic

      def initialize
        @types = []
        @guide_markdown = ''
        @like_name = nil
        @feature = nil
      end

      attr_accessor :types
      attr_accessor :guide_markdown
      attr_accessor :feature

      def name
        raise "A Response has no name"
      end

      def guide_page?
        # Responses are rendered on the feature page.
        false
      end

      def mimic!(other_response)
        if types.blank?
          self.types = other_response.types
        end

        if guide_markdown.strip.blank?
          self.guide_markdown = other_response.guide_markdown
        end
      end

    end
  end
end
