require 'algolia'

module Unpoly
  module Guide
    class Algolia

      def push_all
        key = ENV.fetch('ALGOLIA_KEY')
        stage = ENV.fetch('ALGOLIA_STAGE')
        index = "unpoly-site_#{stage}"

        client = ::Algolia::Search::Client.create('HQEWMGFXBZ', key)

        index = client.init_index(index)
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

        {
          objectID: documentable.guide_id,
          path: documentable.guide_path,
          name: documentable.name,
          title: documentable.title,
          kind: documentable.kind,
          shortKind: documentable.short_kind,
          longKind: documentable.long_kind,
          visibility: documentable.visibility,
          text: to_text(documentable),
        }
      end

      def markdown_renderer
        @markdown_renderer ||= MarkdownRenderer.new(autolink_code: true, strip_links: true, pictures: false)
      end

      def to_html(documentable)
        markdown_renderer.to_html(documentable.guide_markdown)
      end

      def to_text(documentable)
        # We don't need to inclide the title since that's in a separate object property

        html = to_html(documentable)
        text = Util.strip_tags(html)

        if documentable.kind?(:feature)
          if documentable.params_note.present?
            text += "\n" + documentable.params_note
          end

          documentable.params.each do |param|
            text += "\n" + param.signature
            text += "\n" + to_text(param)
          end
        end

        text
      end

    end
  end
end
