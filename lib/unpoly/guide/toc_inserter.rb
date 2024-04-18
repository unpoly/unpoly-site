require 'nokogiri'

module Unpoly
  module Guide
    class TOCInserter

      def auto_insert(html)
        nokogiri_doc = Nokogiri::HTML.fragment(html)
        headings = find_top_level_headings_with_id(nokogiri_doc)

        last_heading = headings.last

        chars_before_last_heading = text_size_before(nokogiri_doc, last_heading)

        if (headings.size >= 4) || (chars_before_last_heading >= 1000)
          insert_toc_before(headings.first, headings)
        end

        nokogiri_doc.to_html
      end

      private

      def text_size_before(root, stop_element)
        text_size_before_inner(0, root, stop_element)
        raise "Stop element (#{stop_element}) not found"
      rescue StopElementFound => found
        found.size
      end

      class StopElementFound < StandardError
        def initialize(size)
          @size = size
        end

        attr_reader :size
      end

      def text_size_before_inner(aggregated_size, root, stop_element)
        subtree_size = 0

        root.children.each do |child|
          if child == stop_element
            raise StopElementFound.new(aggregated_size)
          end

          more = if child.is_a?(Nokogiri::XML::Text)
            child.content.squish.size
          else
            text_size_before_inner(aggregated_size, child, stop_element)
          end

          subtree_size += more
          aggregated_size += more
        end

        subtree_size
      end

      def insert_toc_before(position_after, headings)
        html = ''
        html << '<nav class="toc">'
        html << '<h4 class="toc--title">Contents</h4>'
        headings.each do |heading|
          html << "<div class='toc--item'><a href='##{heading[:id]}'><i class='fa fa-bookmark-o'></i> #{Util.escape_html heading.text}</a></div>"
        end
        html << '</nav>'

        # Prefer inserting before (not after) a <hr class="separator">
        if position_after.previous_element.matches?('hr')
          position_after = position_after.previous_element
        end

        position_after.add_previous_sibling(html)
      end

      def find_headings(nokogiri_doc)
        nokogiri_doc.css('h1, h2, h3, h4:not(.admonition--title), h5, h6').to_a.dup
      end

      def find_top_level_headings_with_id(nokogiri_doc)
        min_level = nil
        results = []

        find_headings(nokogiri_doc).each do |heading|
          level = heading_level(heading)

          # A lot of legacy pages start out with <h3> levels, but have <h2> farther down
          if heading[:id].present? && heading[:toc] != 'false' && (min_level.nil? || level <= min_level)
            results << heading
            min_level = level
          end
        end

        results
      end

      def heading_level(heading)
        heading.name[1].to_i
      end

    end
  end
end

