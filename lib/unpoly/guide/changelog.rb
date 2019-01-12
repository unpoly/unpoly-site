module Unpoly
  module Guide
    class Changelog

      class Release
        def initialize(attrs)
          @version = attrs.fetch(:version)
          @markdown = attrs.fetch(:markdown)
          @repository_path = attrs.fetch(:repository_path)
          @date = nil
        end

        attr_reader :version, :markdown

        def date
          @date ||= begin
            Dir.chdir(@repository_path) do
              # $ git log -1 --format=%ai v0.50.0
              # => 2017-12-06 08:14:52 +0100
              raw = `git log -1 --format=%ai #{git_tag}`
              if raw.present?<
                Time.parse(raw).to_date
              end
            end
          end
        end

        def git_tag
          "v#{version}"
        end

      end

      def initialize(repository_path)
        @repository_path = repository_path
        @changelog_path = File.join(@repository_path, 'CHANGELOG.md')
        @releases = []
        parse()
      end

      attr_reader :releases

      private

      attr_reader :repository_path, :changelog_path

      def parse
        all_markdown = File.read(changelog_path)
        all_markdown.gsub!("\r", '')
        sections = all_markdown.split(/^(\d+\.\d+\.\d+)\n\-+\n+/)
        sections.shift # remove introduction text
        sections.each_slice(2) do |version, release_markdown|
          releases << Release.new(
            version: version,
            markdown: release_markdown,
            repository_path: repository_path
          )
        end
      end

    end
  end
end