module Unpoly
  module Guide
    class DocComment

      def initialize(text)
        @text = text
      end

      attr_accessor :text
      attr_accessor :text_source

      delegate :path, :start_line, :end_line, :local_position, to: :text_source

      def path_with_lines
        [path, start_line, end_line].join(':')
      end

      class << self
        def find_in_path(path)
          extension = path.match(/\.[^\/]+$/)[0] or raise "Cannot extract extension from path: #{path}"
          code = File.read(path)

          if extension.include?('.coffee')
            comments = find_fenced(
              code: code,
              path: path,
              start_marker: /###\*\*/,
              end_marker: /###/
            )

            # We cannot use triple-hashes for h3 since
            # that would close CS block comments
            comments.each do |comment|
              comment.text.gsub! /(\\#){3,}/ do |match|
                "#" * (match.size / 2)
              end
            end

            comments
          elsif extension.include?('.js')
            find_fenced(
              code: code,
              path: path,
              start_marker: /\/\*\*\*/,
              end_marker: /\*\//
            )
          elsif extension.include?('.md')
            last_line_number = Util.count_linefeeds(code) # line after last line feed does not appear in GitHub
            [TextSource.new(
              code,
              path: path,
              start_line: 1,
              end_line: last_line_number
            )]
          else
            raise "Unsupported extension: #{extension}"
          end
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