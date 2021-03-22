module Unpoly
  module Guide
    class Changelog
      include Logger

      class Release
        include Memoized

        def initialize(attrs)
          @version = attrs.fetch(:version)
          @markdown = attrs.fetch(:markdown)
          @repository_path = attrs.fetch(:repository_path)
          @date = nil
        end

        attr_reader :version, :markdown
        attr_accessor :previous_release

        memoize def date
          @date ||= begin
            in_repository do
              # $ git log -1 --format=%ai v0.50.0
              # => 2017-12-06 08:14:52 +0100
              raw = `git log -1 --format=%ai #{git_tag}`.strip
              if raw.present?
                Time.parse(raw).to_date
              end
            end
          end
        end

        def git_tag
          "v#{version}"
        end

        def github_browse_url
          "https://github.com/unpoly/unpoly/tree/#{git_tag}"
        end

        def github_commits_url
          "https://github.com/unpoly/unpoly/commits/#{git_tag}"
        end

        def github_diff_url
          if first_commit && last_commit
            "https://github.com/unpoly/unpoly/compare/#{first_commit}...#{last_commit}"
          end
        end

        def first_commit
          previous_release&.git_tag
        end

        def last_commit
          git_tag
        end

        memoize def commit_count
          if first_commit && last_commit
            in_repository do
              raw = `git log --pretty=oneline #{first_commit}...#{last_commit} | wc -l`.strip
              if raw.present? && raw != '0'
                raw.to_i
              end
            end
          end
        end

        def in_repository(&block)
          Dir.chdir(@repository_path, &block)
        end

      end

      def initialize(repository_path)
        log "initialize()"
        @repository_path = repository_path
        @changelog_path = File.join(@repository_path, 'CHANGELOG.md')
        @releases = []
        parse()
      end

      attr_reader :releases

      def versions
        releases.map(&:version)
      end

      def release_for_version(version)
        releases.detect { |release| release.version == version }
      end

      private

      attr_reader :repository_path, :changelog_path

      def parse
        log "parse()"
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

        releases.each_with_index do |release, index|
          # Recent releases are listed first
          if index < releases.length - 1
            release.previous_release = releases[index + 1]
          end
        end
      end

    end
  end
end
