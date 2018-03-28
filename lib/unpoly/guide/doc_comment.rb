module Unpoly
  module Guide
    class DocComment

      PATTERN = %r{
        (                                # entire doc comment ($1)
          ^[\ \t]*\#\#\#\*{2,}[\ \t]*\n  # start doc comment (###**)
          ((?:.|\n)*?)                   # block content ($2)
          ^[\ \t]*\#\#\#[\ \t]*\n        # end doc comment (###)
        )
      }x

      def initialize(text)
        @text = text
      end

      attr_accessor :text
      attr_accessor :text_source

      def self.find_in_path(path)
        code = File.read(path)

        code.scan(PATTERN).collect do |match|
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