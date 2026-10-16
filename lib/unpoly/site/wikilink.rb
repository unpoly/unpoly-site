module Unpoly
  module Site
    # `[[slug]]` and `[[slug#anchor]]` in prose, expanded to a Markdown link whose label
    # is derived from the target page.
    #
    # Wikilinks are only recognized outside code, so a fenced block or an inline code
    # span can show the syntax without it being expanded. Custom labels don't use
    # wikilinks at all: they are written as plain Markdown links.
    #
    # A paragraph consisting only of `[[more: slug]]` is the box that closes a section of
    # a chapter overview and leads to the page with the whole story ("More: Following
    # links"). It is the only way to write that box, so its markup cannot go wrong.
    module Wikilink
      class Malformed < Error; end

      SPEC = '[A-Za-z0-9\-_.:$\/]+(?:\#[^\s\#\[\]]+)?'.freeze

      # Deliberately does not match dynamic tokens (`[[=version]]`).
      PATTERN = /\[\[(#{SPEC})\]\]/

      # A line of its own. Expanded before PATTERN, which doesn't match it (a space).
      READ_MORE_PATTERN = /^[ \t]*\[\[more:[ \t]+(#{SPEC})\]\][ \t]*$/
      READ_MORE_OPENER = '[[more:'.freeze

      CODE_PATTERN = /((?:^[ \t]*(?:```|~~~).*?^[ \t]*(?:```|~~~)[ \t]*$)|(?:`[^`\n]*`))/m

      class << self
        def expand(markdown, repository: Site.current, source: nil)
          return markdown unless markdown&.include?('[[')

          map_prose(markdown) do |prose|
            prose = prose.gsub(READ_MORE_PATTERN) do
              read_more_html(PageRef.parse($1, repository: repository, source: source))
            end

            if prose.include?(READ_MORE_OPENER)
              raise Malformed, "#{READ_MORE_OPENER} slug]] must be a paragraph of its own#{PageRef.in_source(source)}"
            end

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
            prose = prose.gsub(READ_MORE_PATTERN) { specs << $1; '' }
            prose.scan(PATTERN) { specs << $1 }
            prose
          end
          specs
        end

        private

        # Blank lines around it, so the Markdown renderer takes it as an HTML block of its own.
        def read_more_html(ref)
          "\n#{PageRef.learn_refs_html(:more, [[ref.path, ref.wikilink_label]])}\n"
        end

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
