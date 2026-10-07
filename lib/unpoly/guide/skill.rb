module Unpoly
  module Guide
    # The unpoly-docs agent skill: the documentation as local Markdown files plus a search
    # script, built by Middleman into build/skills/unpoly-docs/ (config.rb registers its
    # pages) and packed for distribution after the build (SkillPackage).
    #
    #   SKILL.md                   source/skills/unpoly-docs/skill.txt.erb
    #   scripts/search.py          source/skills/unpoly-docs/scripts/
    #   references/api/*.md        the API reference, the /api hub as index.md
    #   references/learn/*.md      the guides, the /learn hub as index.md
    #   references/changes/*.md    release notes of 2.x and later, upgrading, the hub
    #
    # The folders mirror the URL shape the site is moving to (/api/…, /learn/…), so the
    # skill stays put when the site's URLs move.
    class Skill
      class Invalid < Error; end

      NAME = 'unpoly-docs'
      ROOT = "skills/#{NAME}"

      # Earlier majors are documented on sites of their own; their release notes link to
      # pages of their time.
      MIN_RELEASE_MAJOR = 2

      def initialize(twins)
        pairs = twins.select { |twin| include?(twin) }.map { |twin|
          [twin.path, "references/#{twin.area.downcase}/#{self.class.filename(twin)}.md"]
        }
        check_collisions!(pairs)
        @files = pairs.to_h
      end

      # The reference files of the skill, by the path of their page:
      # { "/up.render" => "references/api/up-render-function.md", ... }
      attr_reader :files

      # A file name that survives every file system and shell: lowercase, [a-z0-9-] only,
      # "$" spelled out, plus the kind of an API symbol (up.layer the module and
      # up.Layer the class only differ in case). The real name is in the front matter.
      def self.filename(twin)
        return 'index' if %i[learn api changes].include?(twin.subject[:page])

        base = twin.path.delete_prefix('/').delete_prefix('changes/').downcase
        base = base.gsub('$', 'dollar-').gsub(/[^a-z0-9]+/, '-').gsub(/\A-+|-+\z/, '')
        [base, twin.kind].compact.join('-')
      end

      # A calendar version, YYYY.MMDD.HHMM in UTC (2026.1007.1430), that is valid semver
      # and grows with every build: the marketplace only updates a plugin whose version
      # changed. Computed once per build, in config.rb, before Middleman forks renderers.
      def self.stamp(time = Time.now.utc)
        # As numbers, so that no part starts with a zero (semver forbids that).
        "#{time.year}.#{time.month * 100 + time.day}.#{time.hour * 100 + time.min}"
      end

      private

      def include?(twin)
        return false if twin.fixture?
        return false if twin.area == 'Support'
        return twin.subject[:release].to_i >= MIN_RELEASE_MAJOR if twin.subject[:release]
        true
      end

      # Two pages written to one file would silently overwrite each other.
      def check_collisions!(pairs)
        clashes = pairs.group_by(&:last).select { |_file, group| group.size > 1 }
        return if clashes.empty?

        raise Invalid, clashes.map { |file, group| "#{file}: #{group.map(&:first).join(', ')}" }.join("\n")
      end
    end
  end
end
