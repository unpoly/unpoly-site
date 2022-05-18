module Unpoly
  module Guide
    class Interface
      include Documentable
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
      attr_reader :features

      attr_accessor :explicit_title

      def short_signature
        if page?
          title
        else
          name
        end
      end

      alias long_signature short_signature

      def title
        explicit_title.presence || name
      end

      def short_kind
        case kind
        when 'page'
          'DOC'
        when 'class', 'module'
          'JS'
        else
          throw "Unhandled kind: #{kind}"
        end
      end

      def code?
        kind != 'page'
      end

      def guide_filename(extension)
        "#{@name}#{extension}"
      end

      attr_accessor :guide_markdown

      def guide_features
        features.reject(&:internal?)
      end

      # def essential_features
      #   features.select(&:essential?)
      # end

      def essential_features
        # We're using @see feature to list an essential feature.
        references
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

      def page?
        kind == 'page'
      end

      def collapse_markdown?
        long_text = (guide_markdown.size > 1800) || (name == 'up.link')
        important_content_below_text = features.present?
        long_text && important_content_below_text
      end

      def merge!(new_interface)
        kind == new_interface.kind or raise "Cannot merge interfaces with different kinds"
        self.guide_markdown += new_interface.guide_markdown
        self.explicit_title ||= new_interface.explicit_title
        self.reference_names += new_interface.reference_names
      end

      def children
        super + features
      end

    end
  end
end

