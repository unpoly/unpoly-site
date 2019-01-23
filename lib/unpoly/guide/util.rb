module Unpoly
  module Guide
    class Util
      class << self

        def slugify(string)
          guide_id = string.dup
          # Don't downcase here, we want to keep separate up.viewport (module)
          # and up.Viewport (class).
          #
          # Even though we're OK with these characters in the middle of
          # a slug, we don't want them at the beginning
          guide_id.gsub!(/^[\:\-\.\$]+/, '-')
          # Colons (used in up:events) are valid URL segments, as used e.g. by
          # Wikipedia: https://en.wikipedia.org/wiki/Template:Welcome
          guide_id.gsub!(/[^A-Za-z0-9\:\-\.\$]/, '-')
          guide_id.gsub!(/\-{2,}/, '-') # no more than 2 dashes in a row
          guide_id.gsub!(/^\-/, '')
          guide_id.gsub!(/\-$/, '')
          guide_id
        end

        def first_markdown_paragraph(markdown)
          markdown.strip.split(/\n\n/).first
        end

        # Takes a multi-line string (or an Array of single lines)
        # and unindents all lines by the first line's indent.
        def unindent(text_or_lines)
          lines = text_or_lines.is_a?(String) ? split_lines(text_or_lines) : text_or_lines.dup
          # remove_preceding_blank_lines!(lines)
          if lines.size > 0
            first_indent = lines.first.match(/^[ \t]*/)[0]
            lines.collect { |line|
              line.gsub(/^[\ \t]{0,#{first_indent.size}}/, '')
            }.join("\n")
          else
            ''
          end
        end

        # Removes all leading whitespace from the first line
        # and unindents all subsequent lines by the second line's indent.
        def unindent_hanging(block)
          first_line, other_lines = first_and_other_lines(block)
          first_line.sub!(/^[\ \t]+/, '')
          unindented_other_lines = unindent(other_lines)
          [first_line, unindented_other_lines].join("\n")
        end

        def split_lines(text)
          text.split(/\n/)
        end

        def first_and_other_lines(text)
          lines = split_lines(text)
          if lines.length == 0
            ['', []]
          else
            first_line, *other_lines = lines
            [first_line, other_lines]
          end
        end

        # def remove_preceding_blank_lines!(lines)
        #   while lines.first =~ /^([ \t]*)$/
        #     lines.shift
        #   end
        #   lines
        # end

        def count_lines(text)
          split_lines(text).size
        end

        def count_linefeeds(text)
          text.scan("\n").size
        end

      end
    end
  end
end
