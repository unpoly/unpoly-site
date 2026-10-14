require 'json'

module Unpoly
  module Site
    # The pages that get a Markdown twin (/up.render → /up.render.md), registered by
    # config.rb next to each page's own proxy. The skill's reference files are made from
    # the same list (Skill).
    #
    # A twin keeps only names and ids, never parsed objects, so that it still works
    # after the preview has reloaded the guide.
    class MarkdownTwins
      include Enumerable

      def initialize
        @twins = {}
      end

      # path: the HTML page's path, e.g. "/up.render".
      # subject: what the page shows, one of
      #   documentable: guide_id   a feature, module, class or guide page
      #   topic_index: [area_key, slug]
      #   release: version
      #   page: :learn | :api | :changes | :upgrading | :support
      def add(path, **subject)
        @twins[path] = Twin.new(path, subject)
      end

      def each(&block)
        @twins.values.each(&block)
      end

      def fetch(path)
        @twins.fetch(path)
      end

      def paths
        @paths ||= Set.new(@twins.keys)
      end

      class Twin
        attr_reader :path, :subject

        def initialize(path, subject)
          @path = path
          @subject = subject
        end

        def documentable
          subject[:documentable] && Site.current.find_by_guide_id!(subject[:documentable])
        end

        def release
          subject[:release] && Site.current.release_for_version(subject[:release])
        end

        # Where the HTML page lands in the build (directory indexes).
        def html_destination
          "#{path.delete_prefix('/')}/index.html"
        end

        def fixture?
          !!documentable&.fixture?
        end

        # Learn, API, Changes or Support.
        def area
          if (toc_area = self.toc_area)
            toc_area.key == 'api' ? 'API' : toc_area.title
          elsif subject[:release]
            'Changes'
          else
            { learn: 'Learn', api: 'API', changes: 'Changes', upgrading: 'Changes', support: 'Support' }.fetch(subject[:page])
          end
        end

        # The page's front matter: what the skill's search shows for a result, and what an
        # agent peeking at the file sees first. The title is the first heading.
        def front_matter(url:)
          documentable = self.documentable
          data = {}
          data['name'] = symbol.name if symbol
          data['area'] = area
          data['kind'] = kind_label if symbol
          if (hub = self.hub)
            data['parent'] = hub.first
          end
          if documentable && %w[deprecated experimental].include?(documentable.visibility)
            data['visibility'] = documentable.visibility
          end
          data['url'] = url
          data['released'] = release.date.iso8601 if release&.date
          data.map { |key, value| "#{key}: #{JSON.generate(value)}" }.join("\n")
        end

        # The closest page above this one, as [label, path], or nil when that is the
        # root index: a feature's module or class, a class's module, a Learn page's
        # chapter, and otherwise the area's hub (for a module, a chapter's first page).
        def hub
          documentable = self.documentable
          if documentable&.kind?(:feature)
            interface = documentable.interface
            ["#{interface.name} #{interface.kind}", interface.guide_path]
          elsif documentable&.class? && (module_name = documentable.explicit_parent_name)
            mod = Site.current.find_module!(module_name)
            ["#{mod.name} module", mod.guide_path]
          elsif (chapter = self.chapter)
            chapter
          elsif (toc_area = self.toc_area)
            [toc_area.title, toc_area.path]
          elsif subject[:release] || subject[:page] == :upgrading
            ['Changes', '/changes']
          end
        end

        # The kind as the skill's filenames spell it, nil for pages.
        def kind
          symbol&.kind
        end

        # The kind as the page's title shows it on the web ("JavaScript function", "class"),
        # nil for pages.
        def kind_label
          symbol = self.symbol or return
          symbol.kind?(:feature) ? symbol.long_kind : symbol.kind.to_s
        end

        private

        # The page group a page belongs to, as [label, path] of its first page, unless the
        # page is that first page itself. A Learn chapter is labelled as one ("Forms chapter").
        def chapter
          documentable = self.documentable or return
          topic = Site.current.toc.topic_of(documentable)
          return unless topic.is_a?(Toc::PageGroup)

          start = topic.start_page
          return if start.nil? || start == documentable

          label = topic.area.key == 'learn' ? "#{topic.title} chapter" : topic.title
          [label, start.guide_path]
        end

        # The documentable, when it is an API symbol rather than a guide page.
        def symbol
          documentable = self.documentable
          documentable unless documentable.nil? || documentable.page?
        end

        # The Learn or API area of a documentation page or topic index.
        def toc_area
          toc = Site.current.toc
          if (documentable = self.documentable)
            toc.area_for(documentable)
          elsif subject[:topic_index]
            toc.area(subject[:topic_index].first)
          end
        end
      end
    end
  end
end
