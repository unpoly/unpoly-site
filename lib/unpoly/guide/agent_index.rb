module Unpoly
  module Guide
    # The one-level index of the docs that agents start from, in the llms.txt shape: a
    # `##` section per area, each a list of links with a one-sentence description.
    #
    # /index.md and /llms.txt render it with web links, the skill's SKILL.md with
    # relative ones. The lead and closing paragraphs are copy and live in the templates.
    class AgentIndex
      # links: a MarkdownLinks resolver. support: whether to list /support (the skill
      # points to it in a sentence of its own). level: of the section headings.
      def initialize(links:, support: true, level: 2)
        @links = links
        @support = support
        @level = level
      end

      def to_markdown
        toc = Guide.current.toc
        sections = [
          area_section('Learn', toc.learn, 'Every guide, chapter by chapter, in reading order.'),
          area_section('API', toc.api, 'Every module, with its most important features.'),
          changes,
        ]
        sections << support if @support
        sections.join("\n\n")
      end

      private

      # The area's hub, then its topics: Learn's chapters, API's modules.
      def area_section(title, area, hub_description)
        items = [item(area.title, area.path, hub_description)]
        items += area.topics.map { |topic| item(topic.title, topic.menu_path, sentence(topic.summary_markdown)) }
        section(title, items)
      end

      def changes
        section('Changes', [
          item('Changes', '/changes', 'Release notes for every version of Unpoly.'),
          item('Upgrading Unpoly', '/changes/upgrading', 'How unpoly-migrate.js polyfills APIs that a new version renamed or removed.'),
        ])
      end

      def support
        section('Support', [
          item('Support', '/support', 'Community support on GitHub Discussions, and professional support from the people who build Unpoly.'),
        ])
      end

      def section(title, items)
        "#{'#' * @level} #{title}\n\n#{items.join("\n")}"
      end

      def item(title, path, description)
        line = "- [#{title}](#{@links.href(path)})"
        description.present? ? "#{line}: #{description}" : line
      end

      # The first sentence of a summary, as inline Markdown without links.
      def sentence(markdown)
        return nil if markdown.blank?

        html = MarkdownRenderer.new(strip_links: true).to_html(markdown)
        text = HtmlToMarkdown.new(links: @links).convert_inline(html)
        text = text.split(/(?<=[.!?])\s+(?=[A-Z`\[])/).first.to_s
        text unless text == 'This page is being written.'
      end
    end
  end
end
