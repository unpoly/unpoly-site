require 'nokogiri'
require 'kramdown'
require 'kramdown-parser-gfm'

module Unpoly
  module Guide
    class MarkdownRenderer

      def initialize(**options)
        @autolink_code = options.fetch(:autolink_code, true)
        @strip_links = options.fetch(:strip_links, false)
        @pictures = options.fetch(:pictures, true)
        @fix_relative_image_paths = options.fetch(:fix_relative_image_paths, true)
        @link_current_path = options.fetch(:link_current_path, false)
        @current_path = options.fetch(:current_path) if link_current_path
      end

      attr_reader :autolink_code
      attr_reader :strip_links
      attr_reader :pictures
      attr_reader :fix_relative_image_paths
      attr_reader :link_current_path
      attr_reader :current_path

      def to_html(text)
        # text = text.gsub(/<`(.*?)`>/) do |match|
        #   code = $1
        #   slug = Unpoly::Guide::Util.slugify(code)
        #   "[`#{code}`](/#{slug})"
        # end

        doc = Kramdown::Document.new(text,
          input: 'GFM',
          remove_span_html_tags: true,
          enable_coderay: false,
          smart_quotes: ["apos", "apos", "quot", "quot"],
          hard_wrap: false
        )

        # Blindly remove any HTML tag from the document, including "span" elements
        # (see option above). This will NOT remove HTML tags from code examples.
        doc.to_remove_html_tags
        html = doc.to_html
        html = postprocess(html)
        html
      end

      private

      def postprocess(html)
        if autolink_code || strip_links || pictures || fix_relative_image_paths
          nokogiri_doc = Nokogiri::HTML.fragment(html)
        end

        if strip_links
          nokogiri_doc.css('a').each do |link|
            link.replace(link.children)
          end
        elsif autolink_code
          autolink_code_in_nokogiri_doc(nokogiri_doc)
        end

        if pictures
          nokogiri_doc.css('img:not([class])').each do |img|
            img[:class] = 'picture has_border'
          end
        end

        if fix_relative_image_paths
          nokogiri_doc.css('img[src^="images/"]').each do |img|
            img[:src] = img[:src].sub(/^images/, "/images/api")
          end
        end

        nokogiri_doc.to_html
      end

      def autolink_code_in_nokogiri_doc(nokogiri_doc, link_current_path: false)
        codes = nokogiri_doc.css('code')

        current_path = normalized_current_path

        codes.each do |code_element|
          text = code_element.text
          if code_element.ancestors('a, pre').blank?
            if (parsed = guide.code_to_location(text))
              if link_current_path || (parsed[:path] != current_path)
                href = parsed[:full_path]
                code_element.wrap("<a href='#{Util.escape_html href}'></a>")
              end
            end
          end
        end
      end

      def normalized_current_path

      end

      def guide
        Guide.current
      end

    end
  end
end
