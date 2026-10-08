require 'json'

module Unpoly
  module Guide
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
          subject[:documentable] && Guide.current.find_by_guide_id!(subject[:documentable])
        end

        def release
          subject[:release] && Guide.current.release_for_version(subject[:release])
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

        # The page's front matter. Only what the body does not already say in a fixed
        # place: the title is the first heading.
        def front_matter(url:)
          documentable = self.documentable
          data = {}
          data['name'] = symbol.name if symbol
          data['area'] = area
          if documentable && %w[deprecated experimental].include?(documentable.visibility)
            data['visibility'] = documentable.visibility
          end
          data['url'] = url
          data['released'] = release.date.iso8601 if release&.date
          data.map { |key, value| "#{key}: #{JSON.generate(value)}" }.join("\n")
        end

        # The closest page above this one, as [label, path], or nil when that is the
        # root index. A feature names its module, which nothing else in its Markdown does.
        def hub
          if documentable&.kind?(:feature)
            interface = documentable.interface
            ["#{interface.name} #{interface.kind}", interface.guide_path]
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

        private

        # The documentable, when it is an API symbol rather than a guide page.
        def symbol
          documentable = self.documentable
          documentable unless documentable.nil? || documentable.page?
        end

        # The Learn or API area of a documentation page or topic index.
        def toc_area
          toc = Guide.current.toc
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
