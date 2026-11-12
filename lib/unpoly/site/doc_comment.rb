module Unpoly
  module Site
    class DocComment

      SEPARATOR = /\A-{5,}[ \t]*\z/
      HEADING = /\A#[ \t]+(.+?)[ \t]*\z/
      OPENING_FENCE = /\A[ \t]*(`{3,}(?=[^`]*\z)|~{3,})/
      CLOSING_FENCE = /\A[ \t]*(`{3,}|~{3,})[ \t]*\z/

      def initialize(text)
        @text = text
      end

      attr_accessor :text
      attr_accessor :text_source

      # The H1 that heads an entry in a doc file (`up.render()` for `# up.render()`),
      # nil for a doc comment in a source file. Parser checks it against the entry's title.
      attr_accessor :heading

      delegate :path, :start_line, :end_line, :local_position, to: :text_source

      def path_with_lines
        [path, start_line, end_line].join(':')
      end

      class << self
        include Logger

        # The root is the directory that the path was found in.
        def find_in_path(path, root:)
          log "Parsing #{path}"

          extension = path.match(/\.[^\/]+$/)[0] or raise "Cannot extract extension from path: #{path}"
          code = File.read(path)

          if extension.include?('.coffee')
            find_fenced(
              code: code,
              path: path,
              start_marker: /###-/,
              end_marker: /###/
            )
          elsif extension.include?('.js') || extension.end_with?('.ts')
            find_fenced(
              code: code,
              path: path,
              start_marker: /\/\*-/,
              end_marker: /\*\//
            )
          elsif extension.include?('.md')
            if guide_page_path?(path, root)
              [build_for_whole_file(path, code)]
            else
              find_in_doc_file(path, code)
            end
          else
            raise "Unsupported extension: #{extension}"
          end
        end

        # A Markdown file in a pages/ directory is a guide page, one doc comment in its
        # entirety. Any other Markdown file is a doc file with many entries, holding the
        # API docs for the source file beside it (fragment.md for fragment.ts).
        # Only directories below the root count, not those above it (a checkout in ~/pages/).
        def guide_page_path?(path, root)
          Pathname.new(path).relative_path_from(Pathname.new(root)).each_filename.include?('pages')
        end

        def build_for_whole_file(path, text)
          last_line_number = Util.count_linefeeds(text) # line after last line feed does not appear in GitHub
          comment = new(text)
          comment.text_source = TextSource.new(
            text,
            path: path,
            start_line: 1,
            end_line: last_line_number
          )
          comment
        end

        # A doc file holds the doc comments that would otherwise sit in its source file.
        # Each entry is an H1 (`# up.render()`), followed by what used to be between
        # `/*-` and `*/`. Entries are separated by a line of five or more dashes with a
        # blank line above and below. Shorter rules, and dashes in code blocks or under a
        # line of text (a setext heading), belong to the entry.
        def find_in_doc_file(path, text)
          lines = text.lines.map(&:chomp)
          return [] if lines.all?(&:blank?)

          code = code_block_lines(lines, path)

          # A separator at the start or end of the file counts, so that it fails as an empty entry.
          separators = lines.each_index.select do |index|
            lines[index] =~ SEPARATOR && !code.include?(index) &&
              (index.zero? || lines[index - 1].blank?) && lines[index + 1].to_s.blank?
          end

          [-1, *separators, lines.size].each_cons(2).map do |separator, next_separator|
            build_for_doc_file_entry(path, lines, code, (separator + 1)...next_separator)
          end
        end

        # The indexes of lines in fenced code blocks, fences included. A fence may be
        # indented, like one in the body of a @param.
        def code_block_lines(lines, path)
          code = Set.new
          fence = nil
          fence_index = nil

          lines.each_with_index do |line, index|
            if fence
              code << index
              fence = nil if line =~ CLOSING_FENCE && $1[0] == fence[0] && $1.size >= fence.size
            elsif line =~ OPENING_FENCE
              code << index
              fence = $1
              fence_index = index
            end
          end

          fence and raise Parser::CannotParse, "Unclosed code fence: #{path}:#{fence_index + 1}"
          code
        end

        def build_for_doc_file_entry(path, lines, code, range)
          first = range.detect { |index| lines[index].present? } or
            raise Parser::CannotParse, "Empty entry (a stray ----- separator?): #{path}:#{[range.first, 1].max}"
          last = range.reverse_each.detect { |index| lines[index].present? }

          heading = lines[first][HEADING, 1] or
            raise Parser::CannotParse, "An entry must start with an H1 like '# up.render()': #{path}:#{first + 1}"

          # A second H1 most likely means a missing separator, which merges two entries into one.
          if (stray = (first + 1..last).detect { |index| lines[index] =~ HEADING && !code.include?(index) })
            raise Parser::CannotParse, "A second H1 in one entry (a missing ----- separator?): #{path}:#{stray + 1}"
          end

          # A blank line may hold spaces. Left in, it would set the indent that Util.unindent
          # takes from every line, and the bodies of @params would become prose.
          comment = new(lines[(first + 1)..last].drop_while(&:blank?).join("\n") + "\n")
          comment.heading = heading
          comment.text_source = TextSource.new(
            lines[first..last].join("\n") + "\n",
            path: path,
            start_line: first + 1, # one-based
            end_line: last + 1
          )
          comment
        end

        def find_fenced(code:, start_marker:, end_marker:, path:)
          pattern = %r{
            (                                       # entire doc comment ($1)
              ^[\ \t]*#{start_marker}[\ \t]*\n      # start doc comment (###**)
              ((?:.|\n)*?)                          # block content ($2)
              ^[\ \t]*#{end_marker}[\ \t]*(?:\n|$)  # end doc comment (###)
            )
          }x

          code.scan(pattern).map do |match|
            full_comment = match[0]
            text = Util.unindent(match[1])

            match_index = code.index(full_comment) or
              raise "Could not re-find match for line number detection"

            code_before = code[0, match_index]
            lines_before = Util.count_linefeeds(code_before)
            own_lines = Util.count_linefeeds(full_comment)

            start_line = lines_before + 1 # one-based
            end_line = start_line + own_lines - 1

            comment = new(text)
            comment.text_source = TextSource.new(full_comment,
              path: path,
              start_line: start_line,
              end_line: end_line
            )
            comment
          end
        end

      end

    end
  end
end
