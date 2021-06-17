module Unpoly
  module Guide
    class TextSource

      def initialize(text, path: nil, start_line: nil, end_line: nil)
        @text = text
        @path = path
        @start_line = start_line
        @end_line = end_line
      end

      attr_accessor :text, :path, :start_line, :end_line

      def github_url(repository, commit: repository.git_version_tag)
        relative_path = path.sub(repository.path, '')
        "#{repository.github_url}/blob/#{commit}#{relative_path}#L#{start_line}:L#{end_line}"
      end

      def local_position
        "#{path}:#{start_line}:#{end_line}"
      end

    end
  end
end