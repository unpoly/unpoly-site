require 'nokogiri'
require 'kramdown'
require 'kramdown-parser-gfm'

module Unpoly
  module Guide
    class MarkdownRenderer

      def initialize(**options)
        @strip_links = options.fetch(:strip_links, false)
        @autolink_code = options.fetch(:autolink_code, true) && !strip_links
        @pictures = options.fetch(:pictures, true)
        @fix_relative_image_paths = options.fetch(:fix_relative_image_paths, true)
        @admonitions = options.fetch(:admonitions, true)
        @link_current_path = options.fetch(:link_current_path, false)
        @current_path = options.fetch(:current_path) if autolink_code && !link_current_path
        # @mark_code = options.fetch(:mark_code, true)
      end

      attr_reader :autolink_code
      attr_reader :strip_links
      attr_reader :pictures
      attr_reader :fix_relative_image_paths
      attr_reader :link_current_path
      attr_reader :current_path
      attr_reader :admonitions
      # attr_reader :mark_code

      def to_html(text)
        doc = Kramdown::Document.new(text,
          input: 'GFM',
          enable_coderay: false,
          smart_quotes: ["apos", "apos", "quot", "quot"],
          hard_wrap: false
        )

        html = doc.to_html
        html = postprocess(html)
        html
      end

      private

      def postprocess(html)
        nokogiri_doc = Nokogiri::HTML.fragment(html)

        if strip_links
          nokogiri_doc.css('a').each do |link|
            link.replace(link.children)
          end
        end

        if autolink_code
          autolink_code_in_nokogiri_doc(nokogiri_doc)
        end

        # if mark_code
        #   mark_code_in_nokogiri_doc(nokogiri_doc)
        # end

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

        html = nokogiri_doc.to_html

        if admonitions
          # This would be cleaner on the Nokogiri doc, but we could port some
          # existing code that works on strings.
          html = parse_msdoc_admonitions(html)
        end

        html
      end

      def autolink_code_in_nokogiri_doc(nokogiri_doc, link_current_path: false)
        codes = nokogiri_doc.css('code')

        # current_path = normalized_current_path

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

      # def mark_code_in_nokogiri_doc(nokogiri_doc)
      #   code_blocks = nokogiri_doc.css('pre code')
      #
      #   code_blocks.each do |code_element|
      #     html = code_element.inner_html
      #     marked_html = html.gsub(/^(.*)\s*{mark}$/, '<mark>\1</mark>')
      #     if html != marked_html
      #       code_element.inner_html = marked_html
      #     end
      #   end
      # end

      ADMONITION_ICONS = {
        'WARNING' => 'exclamation-triangle',
        'ATTENTION' => 'exclamation-triangle',
        'CAUTION' => 'exclamation-triangle',
        'NOTE' => 'exclamation-circle',
        'IMPORTANT' => 'exclamation-circle',
        'TIP' => 'eye',
        'HINT' => 'eye',
        'INFO' => 'info-circle',
      }.freeze

      ADMONITION_TYPES = ADMONITION_ICONS.keys.freeze

      # The types of admonition boxes we support.
      # Types on the same line get the same visual style, as e.g. "tip" and "hint"
      # is really the same thing.
      ADMONITION_TYPE_PATTERN = Regexp.new(ADMONITION_TYPES.join('|'), 'i')

      ADMONITION_SIGNATURE_PATTERN = %r{
        (#{ADMONITION_TYPE_PATTERN}) # type ($1)
        (?:\ "([^\n"]*)")?           # optional title ($2)
      }xi

      RENDERED_MSDOC_ADMONITION_PATTERN = %r{
        <blockquote>                           # opening <blockquote>
        ((?:\s|<p>|<br>)*)                     # content start ($1)
        \[!?#{ADMONITION_SIGNATURE_PATTERN}\]  # admonition type ($2) and optional title ($3)
        (?:\s*</p>\s*<p>\s*)?                  # redundant paragraph if user puts a newline below the signature
        ((?:<br>|\s)*)                         # signature/content separator to discard ($4)
        # Don't match the end which is non-trivial for nested blockquotes
      }xi

      # Convert admonition markdown in the style of docs.microsoft.com to a
      # BEM block <div class="admonition">.
      def parse_msdoc_admonitions(html)
        html.gsub(RENDERED_MSDOC_ADMONITION_PATTERN) do
          content_start = $1
          admonition_type = $2.upcase
          admonition_title = $3.presence || admonition_type.titleize
          admonition_icon = ADMONITION_ICONS.fetch(admonition_type)
          <<~HTML.html_safe
            <blockquote class='admonition -#{admonition_type.downcase}'>
              <h4 class='admonition--title'><i class='fa fa-#{admonition_icon}'></i> #{admonition_title}</h4>
              #{content_start}
          HTML
        end
      end

      def guide
        Guide.current
      end

    end
  end
end
