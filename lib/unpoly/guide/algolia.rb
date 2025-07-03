require 'algolia'

module Unpoly
  module Guide
    class Algolia
      class CannotPush < StandardError; end

      def push_all
        key = ENV['ALGOLIA_KEY'] or raise CannotPush, "Requires environment variable ALGOLIA_KEY with the Algolia admin key"
        stage = ENV['ALGOLIA_STAGE'] || ENV['STAGE'] or raise "Requires ALGOLIA_STAGE or STAGE (from Capistrano)"
        index_name = "unpoly-site_#{stage}"

        client = ::Algolia::SearchClient.create('HQEWMGFXBZ', key)

        client.clear_objects(index_name)

        guide = Guide.current

        documentables = guide.interfaces + guide.features
        documentables.select!(&:guide_page?)
        objects = documentables.map { |documentable| documentable_to_algolia_object(documentable) }
        response = client.save_objects(index_name, objects, true)
        p response
      end

      private

      def documentable_to_algolia_object(documentable)
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
