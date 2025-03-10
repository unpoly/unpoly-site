module Unpoly
  module Guide
    module Documentable
      include Referencer

      attr_accessor :kind

      attr_accessor :guide_markdown
      attr_accessor :text_source
      attr_accessor :explicit_parent_name

      def guide_markdown?
        guide_markdown.strip.present?
      end

      def long_kind
        kind.capitalize
      end

      def guide_id
        Util.slugify(index_name)
      end

      # The name in the documentation.
      attr_accessor :name

      # What is indexed for guide.find_by_name()
      # Constructors append a ".new" here to not conflict with the class,
      # which gets its own guide page
      alias :index_name :name

      # The name displayed in the menu.
      # This is usually the same as #name, but in case of @params of a @selector
      # we display the param in square brackets to indicate that it's an attribute.
      # We cannot use square brackets in the documentation, as it means "optional" there.
      def menu_title
        name
      end

      def guide_path(hash: nil)
        ["/#{guide_id}", hash].compact.join('#')
      end

      def guide_url(hash: nil)
        "https://unpoly.com#{guide_path(hash: hash)}"
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

        # Ignore case.
        # Also allow us to force-prepend items with uppercase letters below ('Z' < 'a')
        sort_name = sort_name.downcase

        sort_name = sort_name.sub('()', '')

        # List instance methods first
        sort_name = sort_name.sub('.prototype.', '.A.')
        # # List constructor after instance methods, but before class methods
        # sort_name = sort_name.sub(/^new (.+)$/, '\1.B.new')

        # sort_name = sort_name.sub(/^.+\bup\b/, 'up')
        sort_name = sort_name.gsub(/[^A-Za-z0-9\-]/, '-')
        sort_name = sort_name.sub(/-{2,}/, '-')
        sort_name = sort_name.sub(/^-+/, '')
        sort_name = sort_name.sub(/-+$/, '')

        if name.starts_with?('up.$')
          sort_name << 'z' # sort up.$compiler behind up.compiler
        end

        if class?
          sort_name.prepend('z')
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

      def class?
        kind == 'class'
      end

      def module?
        kind == 'module'
      end

      def page?
        kind == 'page'
      end

      def function?
        kind == 'function'
      end

      def instance_method?
        is_a?(Feature) && interface.class? && function? && name.include?('.prototype.')
      end

      def class_method?
        is_a?(Feature) && interface.class? && function? && !name.include?('.prototype.')
      end

      def selector?
        kind == 'selector'
      end

      def property?
        kind == 'property'
      end

      def config?
        property? && name.end_with?('.config')
      end

      def constructor?
        kind == 'constructor'
      end

      def event?
        kind == 'event'
      end

      def header?
        kind == 'header'
      end

      def cookie?
        kind == 'cookie'
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

      def visibility
        @visibility || 'stable'
      end

      attr_writer :visibility

      attr_accessor :visibility_comment

      def stable?
        visibility == 'stable'
      end

      def deprecated?
        visibility == 'deprecated'
      end

      def internal?
        visibility == 'internal'
      end

      def experimental?
        visibility == 'experimental'
      end

      def published?
        not internal?
      end

      # def ==(other)
      #   self.class == other.class && guide_id == other.guide_id
      # end

    end
  end
end
