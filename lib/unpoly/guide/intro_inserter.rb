require 'nokogiri'

module Unpoly
  module Guide
    # Places a block of HTML in a document's intro slot: after the lead paragraphs, but
    # before the first heading, separator and auto-generated table of contents.
    class IntroInserter
      POSITION_SELECTOR = 'h1, h2, h3, h4, h5, h6, hr'.freeze

      def self.insert(html, intro_html)
        return html if intro_html.blank?

        doc = Nokogiri::HTML.fragment(html)
        position = doc.css(POSITION_SELECTOR).first

        if position
          position.add_previous_sibling(intro_html)
        else
          doc.add_child(intro_html)
        end

        doc.to_html
      end
    end
  end
end
