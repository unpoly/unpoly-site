module Unpoly
  module Guide
    class Changelog
      include Logger

      class Release
        include Memoized

        def initialize(attrs)
          @version = attrs.fetch(:version)
          @is_current_major = attrs.fetch(:is_current_major)
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

        def current_major?
          @is_current_major
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
        @current_major = nil
        parse()
      end

      attr_reader :releases
      attr_reader :current_major

      def versions
        releases.map(&:version)
      end

      def release_for_version(version)
        releases.detect { |release| release.version == version }
      end

      private

      def extract_major(version_string)
        version_string.scan(/\d+/).first
      end

      attr_reader :repository_path, :changelog_path

      def parse
        log "parse()"
        all_markdown = File.read(changelog_path)
        all_markdown.gsub!("\r", '')
        sections = all_markdown.split(/^(\d+\.\d+\.\d+(?:-[a-z\d]+)?)\n-+\n+/)
        sections.shift # remove introduction text
        first_version = nil
        sections.each_slice(2) do |version, release_markdown|
          @current_major ||= extract_major(version)
          release_major = extract_major(version)

          releases << Release.new(
            version: version,
            markdown: release_markdown,
            repository_path: repository_path,
            is_current_major: (current_major == release_major),
          )
        end

        releases_by_version = Naturally.sort_by(releases) { |release|
          version = release.version
          unless version.include?('-')
            # Sort "2.0.0" behind a pre-release like "2.0.0.-rc9".
            version += '-zzzzzzzz'
          end
          version
        }

        releases_by_version.each_with_index do |release, index|
          if index > 0
            previous_release = releases_by_version[index - 1]
            release.previous_release = previous_release
          end
        end
      end

    end
  end
end
