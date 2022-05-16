module Unpoly
  module Guide
    module Documentable
      include Referencer

      attr_accessor :kind

      attr_accessor :guide_markdown
      attr_accessor :text_source
      attr_accessor :explicit_parent_name

      def long_kind
        kind.capitalize
      end

      def guide_id
        Util.slugify(name)
      end

      # The name in the documentation.
      attr_accessor :name

      # The name displayed in the menu.
      # This is usually the same as #name, but in case of @params of a @selector
      # we display the param in square brackets to indicate that it's an attribute.
      # We cannot use square brackets in the documentation, as it means "optional" there.
      def menu_title
        name
      end

      def guide_path
        "/#{guide_id}"
      end

      def menu_modifiers
        []
      end

      def summary_markdown
        Util.first_markdown_paragraph(@guide_markdown)
      end

      def inspect
        "#<#{self.class.name} @name=#{name}>"
      end

      def <=>(other)
        sort_name <=> other.sort_name
      end

      def sort_name
        sort_name = name
        sort_name = sort_name.downcase
        # sort_name = sort_name.sub(/^.+\bup\b/, 'up')
        sort_name = sort_name.gsub(/[^A-Za-z0-9\-]/, '-')
        sort_name = sort_name.sub(/-{2,}/, '-')
        sort_name = sort_name.sub(/^-+/, '')
        sort_name = sort_name.sub(/-+$/, '')
        if name.starts_with?('up.$')
          sort_name << 'z' # sort up.$compiler behing up.compiler
        end
        sort_name
      end

      # An interface can explicitly set a parent using the @parent directive
      # to move itself under another module in the menu tree.
      #
      # E.g. the up.Params class sets @parent up.form.
      def explicit_children
        Guide.current.all_by_explicit_parent_name(name)
      end

      alias :children :explicit_children

      # The children shown in the menu tree.
      # This is usually the same as #children, but in case of
      # features we only show their params when the feature is a selector.
      alias :menu_children :children

      def kind?(*kinds)
        kinds = kinds.map(&:to_s)
        # Allow to find both by #kind and the lowercase class name, e.g. kind?(:feature)
        kinds.include?(kind) || kinds.include?(self.class.name.demodulize.underscore)
      end

      def menu_children
        children.select(&:menu_node?)
      end

      def menu_node?
        guide_page?
      end

      def guide_page?
        true
      end

      # def topic_kind?
      #
      # end
      #
      # def javascript_kind?
      #   kind?(:function, :property, :constructor, :class)
      # end
      #
      # def html_kind?
      #   kind?(:selector)
      # end
      #
      # def event_kind?
      #   kind?(:event)
      # end
      #
      # def http_kind?
      #   kind?(:header, :cookie)
      # end

    end
  end
end
