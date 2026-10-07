require 'nokogiri'

module Unpoly
  module Guide
    # Converts a rendered page (its template output, without the layout) into Markdown
    # for agents and LLMs. The web's .md twins and the skill's reference files both come
    # out of here; they differ only in their link resolver (MarkdownLinks).
    #
    # The conversion is generic HTML → Markdown. What it needs to know about the site,
    # the templates say with semantics: real headings or [role=heading][aria-level],
    # aria-label on links, <nav> for navigation, [data-markdown] for the rest. See the
    # marker map in the contributing docs (docs/contributing/documentation.md in unpoly).
    #
    # The bar is "key information stays understandable for agents", not perfection.
    # Golden files in spec/fixtures/markdown make every change of the output reviewable.
    #
    # Content the converter cannot render faithfully (an image without alt text, a
    # diagram without a name) raises an Error, which fails the build and the preview.
    class HtmlToMarkdown
      class Error < Guide::Error; end

      # What each element becomes, by CSS selector. The first matching rule wins, and an
      # element without a rule is a transparent container: a block if it is a block
      # element (BLOCK_TAGS), inline text otherwise.
      #
      # An action is a method name, or a lambda taking the converter and the element.
      RULES = {
        # Chrome for humans ([data-markdown=ignore]), decorative or duplicate content
        # ([aria-hidden]), and what never renders. Dropped with all their contents.
        '[data-markdown="ignore"], [aria-hidden="true"], [hidden], script, style, template, noscript' => :drop,
        # A badge or tag that qualifies what it sits next to: "(JavaScript function)".
        '[data-markdown="chip"]' => :chip,
        'svg[role="img"]' => :diagram,
        'svg' => :drop,
        '[role="img"][aria-label]' => :labelled_image,
        'h1, h2, h3, h4, h5, h6, [role="heading"][aria-level]' => :heading,
        'nav, [role="navigation"]' => :nav,
        'pre' => :code_block,
        'blockquote' => :blockquote,
        'ul, ol' => :list,
        'table' => :table,
        'hr' => :rule,
        'img' => :image,
        'video' => :video,
        'p' => :paragraph,
        'br' => ->(_converter, _element) { "\n" },
        'code, kbd, samp' => :code_span,
        'a' => :link,
        'strong, b' => ->(converter, element) { converter.send(:wrap_inline, element, '**') },
        'em, i' => ->(converter, element) { converter.send(:wrap_inline, element, '_') },
      }.freeze

      # Actions that produce a block of their own (the rest is inline text).
      BLOCK_ACTIONS = %i[diagram heading nav code_block blockquote list table rule video paragraph].freeze

      BLOCK_TAGS = %w[
        address article aside dd details dialog div dl dt fieldset figcaption figure footer
        form header li main section summary tbody thead tfoot tr td th
      ].freeze

      # Magic comments in code blocks, which drive the site's highlighting
      # (syntax_highlighting.js). Marks are presentation and go. A chip or label keeps its
      # text without the directive. A result stays as it is.
      COMMENT_OPENER = %r{(?:<!--|//|/\*|#)}
      MARK_COMMENT = %r{[ \t]*#{COMMENT_OPENER}[ \t]*(?:mark-line\b|mark:)[^\n]*}
      DIRECTIVE_PREFIX = %r{(#{COMMENT_OPENER}[ \t]*)(?:chip|label):[ \t]*}

      # links: a MarkdownLinks resolver.
      def initialize(links:)
        @links = links
      end

      def convert(html)
        @doc = Nokogiri::HTML5.fragment(html.to_s)
        @actions = {}
        RULES.each do |selector, action|
          @doc.css(selector).each { |element| @actions[element.pointer_id] ||= action }
        end
        @used_ids = {}

        markdown = render_blocks(@doc)
        markdown = markdown.gsub(/[ \t]+$/, '').gsub(/\n{3,}/, "\n\n").strip
        markdown.empty? ? '' : "#{markdown}\n"
      end

      # Inline Markdown of an HTML snippet, e.g. a summary for an index line.
      def convert_inline(html)
        convert(html).gsub(/\s+/, ' ').strip
      end

      private

      # ---------- Dispatch ----------

      def action_for(element)
        @actions[element.pointer_id]
      end

      def run(action, element)
        action.respond_to?(:call) ? action.call(self, element) : send(action, element)
      end

      def block?(node)
        return false unless node.element?
        action = action_for(node)
        return false if action == :drop
        return BLOCK_ACTIONS.include?(action) if action
        BLOCK_TAGS.include?(node.name) || contains_block?(node)
      end

      # An inline element without a rule that wraps blocks is rendered as its blocks.
      def contains_block?(element)
        element.element_children.any? { |child| block?(child) }
      end

      # ---------- Block level ----------

      # The children of a node as Markdown blocks, separated by blank lines. Inline
      # content between blocks becomes a paragraph.
      def render_blocks(node)
        blocks = []
        buffer = +''

        flush = lambda do
          paragraph = squish_paragraph(buffer)
          blocks << paragraph unless paragraph.empty?
          buffer = +''
        end

        node.children.each do |child|
          if block?(child)
            flush.call
            block = render_block(child)
            blocks << block unless block.strip.empty?
          else
            buffer << render_inline_node(child)
          end
        end
        flush.call

        blocks.join("\n\n")
      end

      def render_block(element)
        action = action_for(element)
        action ? run(action, element) : render_blocks(element)
      end

      def paragraph(element)
        squish_paragraph(render_inline(element))
      end

      def heading(element)
        level = element.name[/\Ah([1-6])\z/, 1] || element['aria-level']
        level = level.to_i.clamp(1, 6)
        text = squish(render_inline(element))
        return '' if text.empty?

        id = heading_id(element)
        "#{'#' * level} #{text}#{" {##{id}}" if id}"
      end

      # A heading is linked by its own id, or by the id of the [anchor-link] block it
      # heads (a parameter: the id sits on .feature--param, the heading inside it).
      def heading_id(element)
        id = element['id'].presence
        unless id
          wrapper = element.ancestors('[anchor-link][id]').first
          id = wrapper['id'] if wrapper && !@used_ids[wrapper['id']]
        end
        @used_ids[id] = true if id
        id
      end

      # A <nav> stays a <nav> block, so readers and the skill's search can tell
      # navigation from content. Its links become a bullet list; headings inside stay.
      def nav(element)
        label = element['aria-label'].presence || labelled_by(element)
        items = nav_items(element)
        return '' if items.empty?

        body = items.chunk_while { |a, b| a.start_with?('- ') && b.start_with?('- ') }
          .map { |chunk| chunk.join("\n") }
          .join("\n\n")
        opening = label ? %(<nav aria-label="#{CGI.escapeHTML(label)}">) : '<nav>'
        "#{opening}\n\n#{body}\n\n</nav>"
      end

      def nav_items(node)
        node.element_children.flat_map do |child|
          case action_for(child)
          when :drop then []
          when :heading then [heading(child)].reject(&:empty?)
          when :link
            item = link(child)
            item.empty? ? [] : ["- #{item}"]
          when :list then [list(child)].reject(&:empty?)
          else nav_items(child)
          end
        end
      end

      def labelled_by(element)
        ids = element['aria-labelledby'].to_s.split
        text = ids.map { |id| @doc.at_xpath('.//*[@id=$id]', nil, id: id)&.text }.compact.join(' ')
        squish(text).presence
      end

      def code_block(element)
        code = element.at_css('code') || element
        language = [code, element].map { |node| node['class'].to_s[/\blanguage-([\w-]+)/, 1] }.compact.first
        text = strip_magic_comments(code.text).sub(/\A\n+/, '').rstrip
        fence = '```'
        fence += '`' while text.include?(fence)
        "#{fence}#{language}\n#{text}\n#{fence}"
      end

      def strip_magic_comments(code)
        code.lines.filter_map { |line|
          stripped = line.sub(MARK_COMMENT, '')
          # A line that was nothing but a mark goes entirely.
          next if stripped.strip.empty? && !line.strip.empty?
          stripped.sub(DIRECTIVE_PREFIX, '\1')
        }.join
      end

      def blockquote(element)
        inner = render_blocks(element)
        return '' if inner.strip.empty?
        inner.lines.map { |line| line.strip.empty? ? '>' : "> #{line.chomp}" }.join("\n")
      end

      def list(element)
        number = (element['start'] || 1).to_i
        items = element.element_children.select { |child| child.name == 'li' && action_for(child) != :drop }

        bodies = items.map { |item| list_item_body(item) }.reject(&:empty?)
        # Items of more than one paragraph make a loose list, with blank lines between.
        separator = bodies.any? { |body| body.include?("\n\n") } ? "\n\n" : "\n"

        bodies.map { |body|
          marker = element.name == 'ol' ? "#{number}. " : '- '
          number += 1
          indent = ' ' * marker.size
          marker + body.gsub("\n", "\n#{indent}").gsub(/^ +$/, '')
        }.join(separator)
      end

      # A list item's blocks. A nested list hugs the line before it, so a list of short
      # items stays tight.
      def list_item_body(item)
        blocks = render_blocks(item).split(/\n{2,}(?=(?:- |\d+\. ))/)
        blocks.map(&:strip).reject(&:empty?).join("\n")
      end

      def table(element)
        rows = element.css('tr').select { |row| row.ancestors('table').first == element }
        rows = rows.map { |row| row.element_children.select { |cell| %w[th td].include?(cell.name) } }
        rows = rows.reject(&:empty?)
        return '' if rows.empty?

        cells = rows.map { |row| row.map { |cell| squish(render_inline(cell)).gsub('|', '\|') } }
        width = cells.map(&:size).max
        cells = cells.map { |row| row + [''] * (width - row.size) }

        lines = ["| #{cells.first.join(' | ')} |", "|#{' --- |' * width}"]
        cells.drop(1).each { |row| lines << "| #{row.join(' | ')} |" }
        lines.join("\n")
      end

      def rule(_element)
        '---'
      end

      # An inline diagram: its name links to the diagram on the HTML page, its
      # description follows as text.
      def diagram(element)
        name = element['aria-label'].presence || element.at_css('title')&.text
        name = squish(name.to_s)
        id = element['id'].presence || element.ancestors('figure[id]').first&.[]('id')
        raise Error, "A diagram (svg[role=img]) needs a name (<title> or aria-label)" if name.empty?
        raise Error, "Diagram \"#{name}\" needs an id (on the svg or its <figure>) to be linked" unless id

        description = squish(element.at_css('desc')&.text.to_s)
        link = "[Diagram: #{name}](#{@links.page_url}##{id})"
        description.empty? ? link : "#{link}\n\n#{description}"
      end

      def video(element)
        src = element['src'].presence || element.at_css('source[src]')&.[]('src')
        figure = element.ancestors('figure').first
        description = element['aria-label'].presence || element['title'].presence ||
          figure&.at_css('figcaption')&.text
        description = squish(description.to_s)
        raise Error, "A video (#{src}) needs a description (aria-label, title or <figcaption>)" if description.empty?

        "[Video: #{description}](#{@links.media_url(src)})"
      end

      # ---------- Inline level ----------

      def render_inline(node)
        node.children.map { |child| render_inline_node(child) }.join
      end

      def render_inline_node(node)
        if node.text?
          node.text.gsub(/\s+/, ' ')
        elsif node.element?
          action = action_for(node)
          if action.nil?
            # A block element inside inline content (a <div> in a heading) is a word
            # boundary.
            text = render_inline(node)
            BLOCK_TAGS.include?(node.name) ? " #{text} " : text
          elsif BLOCK_ACTIONS.include?(action)
            # Blocks inside inline content (a table cell with paragraphs) run together.
            " #{squish(run_inline(action, node))} "
          else
            run(action, node)
          end
        else
          '' # comments, processing instructions
        end
      end

      def run_inline(action, element)
        case action
        when :code_block then code_span(element)
        when :heading, :paragraph then render_inline(element)
        else run(action, element)
        end
      end

      def drop(_element)
        ''
      end

      def chip(element)
        text = element['title'].presence || squish(render_inline(element))
        text.to_s.empty? ? '' : " (#{text}) "
      end

      def labelled_image(element)
        " (#{squish(element['aria-label'])}) "
      end

      def code_span(element)
        text = element.text.gsub(/\s+/, ' ')
        return '' if text.strip.empty?
        ticks = '`'
        ticks += '`' while text.include?(ticks)
        padding = text.start_with?('`') || text.end_with?('`') ? ' ' : ''
        "#{ticks}#{padding}#{text}#{padding}#{ticks}"
      end

      def link(element)
        text = element['aria-label'].presence || squish(render_inline(element))
        return '' if text.to_s.empty?

        href = element['href'].to_s.strip
        return text if href.empty?
        "[#{text}](#{@links.href(href)})"
      end

      def wrap_inline(element, marker)
        text = render_inline(element)
        return text if text.strip.empty?
        leading = text[/\A\s*/]
        trailing = text[/\s*\z/]
        "#{leading}#{marker}#{text.strip}#{marker}#{trailing}"
      end

      # A content image must say what it shows. A decorative image is hidden from
      # screen readers with [aria-hidden] and dropped before it gets here. (An empty
      # alt is no way out: Middleman's image_tag writes alt="" by default.)
      def image(element)
        alt = squish(element['alt'])
        raise Error, "An image (#{element['src']}) needs alt text" if alt.empty?

        "![#{alt}](#{@links.media_url(element['src'].to_s)})"
      end

      # ---------- Text ----------

      def squish(text)
        text.to_s.gsub(/\s+/, ' ').strip
      end

      # Whitespace runs collapse, and a <br> (a newline here) ends a line.
      def squish_paragraph(text)
        text.split("\n").map { |line| squish(line) }.reject(&:empty?).join("\n")
      end
    end
  end
end
