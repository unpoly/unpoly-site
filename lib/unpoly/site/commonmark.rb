require 'commonmarker'
require 'nokogiri'

module Unpoly
  module Site
    # Renders Markdown with commonmarker (CommonMark + GFM extensions).
    #
    # Headings may carry attributes on the heading line, in Pandoc's syntax:
    #
    #     ### Closing when a location is reached {#location-condition data-toc-include}
    #
    # We strip these suffixes before parsing and assign them to the rendered headings afterwards.
    # Headings without an explicit id get an auto-generated id, using the same algorithm as
    # kramdown's GFM parser, so existing anchors keep their values.
    module Commonmark

      OPTIONS = {
        parse: { smart: false },
        render: {
          unsafe: true,
          hardbreaks: false,
          github_pre_lang: false,
          escaped_char_spans: false,
          sourcepos: true,
        },
        extension: {
          table: true,
          strikethrough: true,
          autolink: true,
          tagfilter: false,
          tasklist: false,
          shortcodes: false,
          header_ids: nil,
        },
      }.freeze

      PLUGINS = { syntax_highlighter: nil }.freeze

      # One token of a Pandoc attribute list: `#id`, `.class`, `key`, `key=value`, `key="value"`.
      ATTRIBUTE_TOKEN = /
        \#([\w:.-]+)                                     # id ($1)
        | \.([\w-]+)                                     # class ($2)
        | ([A-Za-z_][\w-]*)(?:=(?:"([^"]*)"|'([^']*)'|([^\s"'{}=]+)))? # key ($3), value ($4, $5 or $6)
      /x

      # A Pandoc attribute list at the end of a heading line, like `{#id data-toc-include}`.
      # The braces must hug the tokens, so that literal braces in heading text (`{ target }`,
      # `{foo: 1}`) stay text.
      ATTRIBUTES_SUFFIX = /[ \t]+\{((?:#{ATTRIBUTE_TOKEN.source})(?:[ \t]+(?:#{ATTRIBUTE_TOKEN.source}))*)\}[ \t]*$/x

      ATX_HEADING = /\A {0,3}(?:>[ \t]?)*\#{1,6}[ \t]+\S/
      SETEXT_UNDERLINE = /\A {0,3}(?:>[ \t]?)*(?:=+|-+)[ \t]*\z/
      FENCE = /\A[ \t]*(?:>[ \t]?)*(`{3,}|~{3,})/

      class << self

        # Returns a Nokogiri fragment.
        def render(markdown)
          markdown, attributes_by_line = extract_heading_attributes(markdown)
          html = Commonmarker.to_html(markdown, options: OPTIONS, plugins: PLUGINS)
          doc = Nokogiri::HTML.fragment(html)
          assign_heading_attributes(doc, attributes_by_line)
          doc.css('[data-sourcepos]').each { |element| element.remove_attribute('data-sourcepos') }
          doc
        end

        # Strips `{#id …}` suffixes from ATX and setext heading lines.
        # Returns the stripped Markdown and a hash { line number of the heading's last line => attributes }.
        def extract_heading_attributes(markdown)
          lines = markdown.split("\n", -1)
          attributes_by_line = {}
          fence = nil

          lines.each_with_index do |line, index|
            if fence
              fence = nil if (match = line.match(FENCE)) && match[1][0] == fence[0] && match[1].length >= fence.length
              next
            elsif (match = line.match(FENCE))
              fence = match[1]
              next
            end

            next unless (suffix = line.match(ATTRIBUTES_SUFFIX))

            if line.match?(ATX_HEADING)
              heading_end_line = index + 1
            elsif (next_line = lines[index + 1]) && next_line.match?(SETEXT_UNDERLINE) && line.strip.present?
              heading_end_line = index + 2
            else
              next
            end

            attributes_by_line[heading_end_line] = parse_attributes(suffix[1])
            lines[index] = line.sub(ATTRIBUTES_SUFFIX, '')
          end

          [lines.join("\n"), attributes_by_line]
        end

        def parse_attributes(string)
          attributes = {}
          classes = []
          string.scan(ATTRIBUTE_TOKEN) do |id, klass, key, double_quoted, single_quoted, unquoted|
            if id
              attributes['id'] = id
            elsif klass
              classes << klass
            else
              attributes[key] = double_quoted || single_quoted || unquoted || ''
            end
          end
          attributes['class'] = classes.join(' ') if classes.any?
          attributes
        end

        def assign_heading_attributes(doc, attributes_by_line)
          id_counter = Hash.new(-1)

          doc.css('h1[data-sourcepos], h2[data-sourcepos], h3[data-sourcepos], h4[data-sourcepos], h5[data-sourcepos], h6[data-sourcepos]').each do |heading|
            end_line = heading['data-sourcepos'][/-(\d+):/, 1].to_i
            attributes = attributes_by_line[end_line] || {}
            attributes.each { |name, value| heading[name] = value }
            heading['id'] ||= generate_gfm_header_id(heading.text, id_counter)
          end
        end

        # Same as Kramdown::Parser::GFM#generate_gfm_header_id.
        NON_WORD_RE = /[^\p{Word}\- \t]/

        def generate_gfm_header_id(text, id_counter)
          result = text.downcase
          result.gsub!(NON_WORD_RE, '')
          result.tr!(" \t", '-')

          id_counter[result] += 1
          counter_result = id_counter[result]
          result << "-#{counter_result}" if counter_result > 0
          result
        end

      end
    end
  end
end
