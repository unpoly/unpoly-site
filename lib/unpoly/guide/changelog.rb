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
        end

        attr_reader :version, :markdown
        # The release with the next lower version *number*, which may not be the
        # release before it in time: we sometimes release a patch for an older major.
        attr_accessor :previous_release_by_version

        memoize def time
          in_repository do
            # $ git log -1 --format=%ai v0.50.0
            # => 2017-12-06 08:14:52 +0100
            raw = `git log -1 --format=%ai #{git_tag}`.strip
            if raw.present?
              Time.parse(raw)
            end
          end
        end

        memoize def date
          time&.to_date
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
          previous_release_by_version&.git_tag
        end

        def last_commit
          git_tag
        end

        memoize def commit_count
          if version == "0.1.0"
            in_repository do
              raw = `git rev-list --count #{last_commit}`.strip
              if raw.present? && raw != '0'
                raw.to_i
              end
            end
          elsif first_commit && last_commit
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

        def can_unpoly_migrate?
          !version.starts_with?("0.") && !version.starts_with?("1.")
        end

      end

      def initialize(repository_path)
        log "initialize()"
        @repository_path = repository_path
        # The changelog is split into one file per major version.
        # Sort by major version, descending.
        @changelog_paths = Dir[File.join(@repository_path, 'docs', 'changes', 'CHANGELOG_*.md')].sort_by { |path| -extract_major(File.basename(path)).to_i }
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

      attr_reader :repository_path, :changelog_paths

      def parse
        log "parse()"
        releases_by_file = changelog_paths.map { |path| parse_file(path) }
        @releases = merge_chronologically(releases_by_file)

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
            release.previous_release_by_version = releases_by_version[index - 1]
          end
        end
      end

      # Parses one CHANGELOG_<major>.x.md file into an array of Releases,
      # keeping the file's order (newest first).
      def parse_file(path)
        file_releases = []
        all_markdown = File.read(path)
        all_markdown.gsub!("\r", '')
        sections = all_markdown.split(/^(\d+\.\d+\.\d+(?:-[a-z\d]+)?)\n-+\n+/)
        sections.shift # remove text before the first version heading, like the "Unreleased" section
        sections.each_slice(2) do |version, release_markdown|
          # Files are sorted by major version (descending), so the first release we see
          # belongs to the current major.
          @current_major ||= extract_major(version)
          release_major = extract_major(version)

          file_releases << Release.new(
            version: version,
            markdown: release_markdown.strip,
            repository_path: repository_path,
            is_current_major: (current_major == release_major),
          )
        end
        file_releases
      end

      # Merges per-major release lists into a single list ordered by release time
      # (newest first), like the single CHANGELOG.md we used to have. We cannot simply
      # concatenate the files, since a maintenance release for an older major may have
      # been published between two releases of a newer major (e.g. 1.0.3 between
      # 2.3.0 and 2.2.1).
      def merge_chronologically(releases_by_file)
        lists = releases_by_file.reject(&:empty?)
        merged = []
        while lists.any?
          # A release without a git tag (e.g. an upcoming version that is already
          # documented) has no time and is considered the newest. Ties keep the
          # release with the higher major version first.
          newest_list = lists.max_by { |list| list.first.time&.to_f || Float::INFINITY }
          merged << newest_list.shift
          lists.reject!(&:empty?)
        end
        merged
      end

    end
  end
end
