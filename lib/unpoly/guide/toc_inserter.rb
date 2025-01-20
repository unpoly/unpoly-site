require 'nokogiri'

module Unpoly
  module Guide
    class TOCInserter

      def auto_insert(html)
        nokogiri_doc = Nokogiri::HTML.fragment(html)
        headings = find_top_level_headings_with_id(nokogiri_doc)

        return html if headings.blank?

        last_heading = headings.last

        chars_before_last_heading = text_size_before(nokogiri_doc, last_heading)

        if (headings.size >= 4) || (chars_before_last_heading >= 1000 && headings.size > 1)
          insert_toc_before(headings.first, headings)
          nokogiri_doc.to_html
        else
          html
        end
      end

      private

      def textualize_prefixes(heading)
        heading.css('.heading-prefix').each do |prefix|
          prefix.name = 'span'
          prefix.remove_attribute('class')
          prefix.content += ':'
        end
      end

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

      ELEMENTS_WITH_MARGIN = %w[h1 h2 h3 h4 pre li p tr dt dd]

      def text_size_before_inner(aggregated_size, root, stop_element)
        subtree_size = 0

        if root.is_a?(Nokogiri::XML::Node)
          # Add some more for block elements as they have some
          # margin_bonus = ELEMENTS_WITH_MARGIN.include?(root.name) ? 50 : 0
          margin_bonus = root.parent && root.matches?('h1, h2, h3, h4, pre, li, p, tr, dt, dd') ? 50 : 0
          subtree_size += margin_bonus
          aggregated_size += margin_bonus
        end

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
        headings = headings.map(&:dup)

        html = ''
        html << '<nav class="toc">'
        html << '<h4 class="toc--title">Contents</h4>'
        headings.each do |heading|
          textualize_prefixes(heading)
          html << "<div class='toc--item'><a href='##{heading[:id]}'><i class='fa fa-bookmark-o'></i> #{heading.inner_html}</a></div>"
        end
        html << '</nav>'

        # Prefer inserting before (not after) a <hr class="separator">
        if position_after.previous_element&.matches?('hr')
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

