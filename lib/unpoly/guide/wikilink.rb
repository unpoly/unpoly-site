module Unpoly
  module Guide
    # `[[slug]]` and `[[slug#anchor]]` in prose, expanded to a Markdown link whose label
    # is derived from the target page.
    #
    # Wikilinks are only recognized outside code, so a fenced block or an inline code
    # span can show the syntax without it being expanded. Custom labels don't use
    # wikilinks at all: they are written as plain Markdown links.
    module Wikilink
      # Deliberately does not match dynamic tokens (`[[=version]]`).
      PATTERN = /\[\[([A-Za-z0-9\-_.:$\/]+(?:\#[^\s\#\[\]]+)?)\]\]/

      CODE_PATTERN = /((?:^[ \t]*(?:```|~~~).*?^[ \t]*(?:```|~~~)[ \t]*$)|(?:`[^`\n]*`))/m

      class << self
        def expand(markdown, repository: Guide.current, source: nil)
          return markdown unless markdown&.include?('[[')

          map_prose(markdown) do |prose|
            prose.gsub(PATTERN) do
              ref = PageRef.parse($1, repository: repository, source: source)
              "[#{ref.wikilink_label}](#{ref.path})"
            end
          end
        end

        # Every wikilink spec in the given prose, for build checks.
        def specs(markdown)
          return [] unless markdown&.include?('[[')

          specs = []
          map_prose(markdown) do |prose|
            prose.scan(PATTERN) { specs << $1 }
            prose
          end
          specs
        end

        private

        # Yields the parts of the text that are not code, and keeps the rest verbatim.
        def map_prose(text)
          text.split(CODE_PATTERN).each_with_index.map { |part, index|
            index.odd? ? part : yield(part)
          }.join
        end
      end
    end
  end
end
