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

      attr_accessor :explicit_menu_title

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

      # Internal interfaces (e.g. up.browser) render no page and no menu node,
      # and mentions of them are left unlinked.
      def guide_page?
        !internal?
      end

      def guide_filename(extension)
        "#{@name}#{extension}"
      end

      attr_accessor :guide_markdown

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

      # def collapse_markdown?
      #   long_text = (guide_markdown.size > 1800) || (name == 'up.link')
      #   important_content_below_text = features.present?
      #   long_text && important_content_below_text
      # end

      def merge!(new_interface)
        kind == new_interface.kind or raise "Cannot merge interfaces with different kinds"
        self.guide_markdown += new_interface.guide_markdown
        self.explicit_title ||= new_interface.explicit_title
        self.explicit_menu_title ||= new_interface.explicit_menu_title
        self.reference_names += new_interface.reference_names
        self.learn_ref_specs.concat(new_interface.learn_ref_specs)
        self.explicit_parent_name ||= new_interface.explicit_parent_name
        # A repeated declaration may carry the visibility tag (e.g. @module up.browser
        # is declared in both unpoly and unpoly-migrate, and both say @internal).
        self.visibility = new_interface.declared_visibility if declared_visibility.nil?
      end

      def children
        super + features
      end

      def menu_title
        if explicit_menu_title.present?
          explicit_menu_title
        elsif page?
          title
        else
          name
        end
      end

      def menu_modifiers
        if page?
          ['page']
        else
          []
        end
      end

      def guide_features
        features.select(&:guide_page?)
      end

      # TODO(content): @see is being retired. These feature targets keep rendering as
      # "Essentials" cards until the Content station replaces each module's cards with
      # intro prose and deletes the @see machinery in that same pass.
      def essential_features
        references.select { |reference| reference.kind?(:feature) }
      end

    end
  end
end

