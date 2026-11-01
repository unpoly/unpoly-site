module Unpoly
  module Site
    # The way up from a page: the pages above it, from its area down to the closest one, as
    # [label, path] steps. The root index and the page itself are not in it.
    #
    #   [up-submit]          API / up.form
    #   up.Layer#accept()    API / up.Layer
    #   up.form              API
    #   Feedback classes     Learn / Loading state
    #   Version 3.0.0        Changes
    #
    # The hubs (/learn, /api, /changes) and pages outside the docs have none.
    #
    # The HTML breadcrumb, the Markdown twin's nav line and parent, and the hub a search
    # result names (search_hub in config.rb) are all read from here, so that they agree.
    # A step is labelled by its page's name alone. What kind of page it is, the
    # Markdown twin says in its front matter (`kind:`).
    #
    # A page is given by its subject, as for MarkdownTwins#add, but with the documentable
    # itself instead of its guide id.
    module Trail
      CHANGES = ['Changes', '/changes'].freeze

      def self.of(documentable: nil, topic_index: nil, release: nil, page: nil)
        toc = Site.current.toc
        if documentable
          [area_step(toc.area_for(documentable)), documentable_step(documentable, toc)].compact
        elsif topic_index
          [area_step(toc.area(topic_index.first))]
        elsif release || page == :upgrading
          [CHANGES]
        else
          []
        end
      end

      def self.area_step(area)
        [area.key == 'api' ? 'API' : area.title, area.path]
      end

      # The step between a documentable and its area, if there is one: a feature's namespace
      # or class, a class's namespace, or a page's chapter (unless the page starts it).
      def self.documentable_step(documentable, toc)
        if documentable.kind?(:feature)
          interface = documentable.interface
          [interface.name, interface.guide_path]
        elsif documentable.class? && (namespace_name = documentable.explicit_parent_name)
          namespace = Site.current.find_namespace!(namespace_name)
          [namespace.name, namespace.guide_path]
        elsif (topic = toc.topic_of(documentable)).is_a?(Toc::PageGroup)
          start = topic.start_page
          [topic.title, start.guide_path] unless start.nil? || start == documentable
        end
      end

      private_class_method :area_step, :documentable_step
    end
  end
end
