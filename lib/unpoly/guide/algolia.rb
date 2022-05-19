require 'algolia'

module Unpoly
  module Guide
    class Algolia

      def push_all
        client = ::Algolia::Search::Client.create('HQEWMGFXBZ', '449a60d55ac3c067eda794e159b0f309')

        index = client.init_index('unpoly-site_development')
        index.clear_objects

        guide = Guide.current

        documentables = guide.interfaces + guide.features
        documentables.select!(&:guide_page?)
        objects = documentables.map { |documentable| documentable_to_algolia_object(documentable) }
        response = index.save_objects(objects)
        p response
      end

      private

      def documentable_to_algolia_object(documentable)
        html = markdown_renderer.to_html(documentable.guide_markdown)
        text = Util.strip_tags(html)

        {
          objectID: documentable.guide_id,
          path: documentable.guide_path,
          name: documentable.name,
          title: documentable.title,
          kind: documentable.kind,
          shortKind: documentable.short_kind,
          longKind: documentable.long_kind,
          visibility: documentable.visibility,
          text: text,
        }
      end

      def markdown_renderer
        @markdown_renderer ||= MarkdownRenderer.new(autolink_code: true, strip_links: true, pictures: false)
      end

    end
  end
end
