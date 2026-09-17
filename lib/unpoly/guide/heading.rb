require 'kramdown'
require 'kramdown-parser-gfm'
require 'nokogiri'

module Unpoly
  module Guide
    # A heading inside a document's prose, together with the anchor it can be linked to.
    #
    # We let Kramdown produce the index instead of matching headings ourselves: it already
    # understands ATX (`## Title`) and Setext (`Title\n-----`) headings, generates the same
    # auto-IDs as the rendered page, and honors explicit `{#custom-slug}` suffixes.
    class Heading
      def initialize(id:, text:, level:)
        @id = id
        @text = text
        @level = level
      end

      attr_reader :id, :text, :level

      def inspect
        "#<#{self.class.name} #{id.inspect} (h#{level})>"
      end

      SELECTOR = 'h1, h2, h3, h4, h5, h6'.freeze

      def self.parse(markdown)
        return [] if markdown.blank?

        html = Kramdown::Document.new(markdown, input: 'GFM', enable_coderay: false, hard_wrap: false).to_html
        Nokogiri::HTML.fragment(html).css(SELECTOR).filter_map do |element|
          id = element['id'].presence or next
          new(id: id, text: element.text.strip, level: element.name[1].to_i)
        end
      end
    end
  end
end
