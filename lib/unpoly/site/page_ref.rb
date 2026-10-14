module Unpoly
  module Site
    # A reference to another document, optionally to one of its headings.
    #
    # One resolver serves both mechanisms that address a document by slug: the
    # `@learn-ref` directive and `[[wikilinks]]` in prose. Both derive their link label
    # from the target, so a retitled page updates every reference to it.
    class PageRef
      class Unresolvable < Error; end

      # A slug, optionally followed by an anchor: `caching`, `caching#expiration`.
      SPEC_PATTERN = %r{\A([A-Za-z0-9\-_.:$/]+)(?:\#([^\s\#]+))?\z}

      def self.parse(spec, repository: Site.current, source: nil)
        match = SPEC_PATTERN.match(spec.to_s.strip) or
          raise Unresolvable, "Malformed reference #{spec.inspect}#{in_source(source)}"

        slug, anchor = match.captures

        documentable = repository.find_by_guide_id(slug) or
          raise Unresolvable, "Reference to unknown page #{slug.inspect}#{in_source(source)}"

        heading = nil
        if anchor
          heading = documentable.heading(anchor) or
            raise Unresolvable, "Reference to unknown anchor ##{anchor} on page #{slug.inspect}#{in_source(source)}"
        end

        new(documentable, heading)
      end

      # The boxes that lead to Learn pages, in two kinds: the learn-refs of a reference
      # page (`@learn-ref`, config.rb) and the box that closes a section of a chapter
      # overview (`[[more: slug]]`, Wikilink). One nav holds one box per link:
      #
      #     <nav class="learn-refs -learn" aria-label="Guides" data-pagefind-ignore>
      #       <a class="learn-ref" href="/forms">
      #         <svg class="icon -book learn-ref--icon" ...></svg>
      #         <span class="learn-ref--prefix">Learn:</span>
      #         <span class="learn-ref--destination">Forms</span>
      #       </a>
      #     </nav>
      #
      # Pagefind skips the nav: it only names other pages and would clutter search
      # snippets. Styled by learn-refs.sass and learn-ref.sass.
      LEARN_REFS_KINDS = {
        learn: { prefix: 'Learn:', aria_label: 'Guides' },
        more: { prefix: 'More:', aria_label: 'Read more' },
      }.freeze

      # links: pairs of path and destination label.
      def self.learn_refs_html(kind, links)
        prefix, aria_label = LEARN_REFS_KINDS.fetch(kind).values_at(:prefix, :aria_label)
        refs = links.map do |path, destination|
          %(<a class="learn-ref" href="#{CGI.escapeHTML(path)}">) +
            Icon.html('book', class: 'learn-ref--icon') +
            %( <span class="learn-ref--prefix">#{prefix}</span>) +
            %( <span class="learn-ref--destination">#{CGI.escapeHTML(destination)}</span></a>)
        end
        %(<nav class="learn-refs -#{kind}" aria-label="#{aria_label}" data-pagefind-ignore>#{refs.join}</nav>)
      end

      def self.in_source(source)
        source ? " (in #{source})" : ''
      end

      def initialize(documentable, heading = nil)
        @documentable = documentable
        @heading = heading
      end

      attr_reader :documentable, :heading

      def path
        documentable.guide_path(hash: heading&.id)
      end

      def title
        documentable.title
      end

      # The label of a `@learn-ref`: the page's title, also for a reference to one of
      # its headings (the link still leads to the heading).
      def learn_ref_label
        title
      end

      # The label a `[[wikilink]]` expands to.
      def wikilink_label
        heading ? "#{title}: #{heading.text}" : title
      end
    end

    # One `@learn-ref` directive: a reference plus an optional hand-written label.
    class LearnRef
      def initialize(page_ref, label = nil)
        @page_ref = page_ref
        @label = label
      end

      attr_reader :page_ref

      delegate :path, :documentable, :heading, to: :page_ref

      def label
        @label.presence || page_ref.learn_ref_label
      end
    end
  end
end
