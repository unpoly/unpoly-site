module Unpoly
  module Guide
    # A reference to another document, optionally to one of its headings.
    #
    # One resolver serves both mechanisms that address a document by slug: the
    # `@learn-ref` directive and `[[wikilinks]]` in prose. Both derive their link label
    # from the target, so a retitled page updates every reference to it.
    class PageRef
      class Unresolvable < Error; end

      # A slug, optionally followed by an anchor: `caching`, `caching#expiration`.
      SPEC_PATTERN = %r{\A([A-Za-z0-9\-_.:$/]+)(?:\#([^\s\#]+))?\z}

      def self.parse(spec, repository: Guide.current, source: nil)
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

      # The label of a `@learn-ref`. Anchored refs name their heading so the reference
      # carries its own context.
      def learn_ref_label
        heading ? "#{title} › #{heading.text}" : title
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
