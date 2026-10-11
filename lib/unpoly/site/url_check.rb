require 'set'

module Unpoly
  module Site
    # "No lost URL": every address unpoly.com serves today must still resolve after the
    # docs rework, either to a page or through a redirect rule.
    #
    # We compare against the `master` revision of both repositories, since that is what
    # is deployed. API symbols are not read from master: a renamed symbol keeps its page
    # as `@deprecated`, so every symbol master documents is still documented here, and
    # the check makes sure that its old root path (/up.render, from before documents
    # moved under /learn and /api) still redirects.
    #
    # Every redirect must lead to a page in one hop: no redirect may point to a path
    # that is only another redirect.
    class UrlCheck
      REDIRECT_PATTERN = /^\s*RedirectPermanent\s+(\S+)\s+(\S+)\s*$/

      # The exact-match rules of the URL move: RedirectMatch 301 ^/up\.render/?$ /api/up.render
      EXACT_REDIRECT_PATTERN = %r{^\s*RedirectMatch\s+301\s+\^(\S+?)/\?\$\s+(\S+)\s*$}

      def initialize(repository = Site.current, revision: 'master')
        @repository = repository
        @revision = revision
      end

      attr_reader :repository, :revision

      def run
        lost = old_paths.reject { |path| resolves?(path) }
        moved = moved_paths.reject { |path| resolves?(path) }
        pending = redirects.reject { |_from, to| target_resolves?(to) }
        chains = redirects.select { |_from, to| chained?(to) }

        report('LOST (no page and no redirect)', lost)
        report('MOVED WITHOUT REDIRECT (old root path of a document)', moved)
        report('PENDING (redirect target not built yet)', pending.map { |from, to| "#{from} -> #{to}" })
        report('CHAINED (redirect to another redirect)', chains.map { |from, to| "#{from} -> #{to} -> #{redirects[to.split('#').first]}" })

        if lost.empty? && moved.empty?
          puts "No lost URL: all #{old_paths.size} published addresses and #{moved_paths.size} old document paths still resolve."
        end
        if chains.empty?
          puts "No redirect chain: all #{redirects.size} redirects lead to their target in one hop."
        end

        lost.empty? && moved.empty? && chains.empty?
      end

      # Paths the site serves after the rework.
      def current_paths
        @current_paths ||= Set.new(
          documents.map(&:guide_path) + topic_indexes.map(&:guide_path) + site_paths(nil)
        )
      end

      # The root paths documents had before they moved under /learn and /api
      # (/up.render, /caching), which must redirect to their new home.
      def moved_paths
        @moved_paths ||= (documents.map { |document| "/#{document.guide_id}" } +
          topic_indexes.map { |index| "/#{index.slug}" }).uniq.sort
      end

      # Paths the deployed site serves today.
      def old_paths
        @old_paths ||= (old_page_paths + site_paths(revision)).uniq.sort
      end

      def redirects
        @redirects ||= [
          File.read('source/.htaccess.erb'),
          repository.migrate_redirects,
        ].flat_map { |text|
          text.scan(REDIRECT_PATTERN) +
            text.scan(EXACT_REDIRECT_PATTERN).map { |from, to| [unescape(from), unescape(to)] }
        }.reverse.to_h # Apache applies the first rule for a path
      end

      private

      def documents
        repository.documentables.select(&:guide_page?).reject(&:fixture?)
      end

      def topic_indexes
        repository.toc.areas.flat_map(&:topics).filter_map(&:index)
      end

      # A regular expression's escapes (^/up\.\$compiler) or a target's ($ as \$).
      def unescape(text)
        text.gsub(/\\(.)/, '\\1')
      end

      # A target that is no page of its own but the source of another redirect.
      def chained?(target)
        return false if external?(target)

        path = target.split('#', 2).first
        !current_paths.include?(path) && redirects.key?(path)
      end

      # A path is kept alive either by a page of its own or by a redirect rule. Whether
      # the rule's target exists yet is what the pending list is for.
      def resolves?(path)
        current_paths.include?(path) || redirects.key?(path)
      end

      def target_resolves?(target)
        return true if external?(target)

        path, anchor = target.split('#', 2)
        return false unless current_paths.include?(path)
        return true unless anchor

        documentable = repository.find_by_guide_path(path)
        # Site-side pages are not parsed, so we cannot index their headings.
        documentable.nil? || !documentable.heading(anchor).nil?
      end

      def external?(target)
        target.include?('://')
      end

      def old_page_paths
        slugs = git(repository.path, 'grep', '-h', '--no-color', '^@page ', revision, '--', 'src/unpoly/pages')
        slugs.to_s.scan(/^@page (\S+)$/).flatten.map { |slug| "/#{slug}" }
      end

      # Pages implemented in this repository, either at the given revision or on disk.
      def site_paths(at_revision)
        files = if at_revision
          git('.', 'ls-tree', '-r', '--name-only', at_revision, '--', 'source').to_s.split("\n")
        else
          Dir['source/**/*'].select { |path| File.file?(path) }
        end

        files.filter_map do |file|
          next unless file =~ %r{\Asource/(.+)\.html\.erb\z}

          path = $1.sub(%r{(\A|/)index\z}, '')
          next if path.start_with?('api/', 'examples/', 'layouts/', 'nodes/', 'menu/')
          next if File.basename(path).start_with?('_') || File.basename(path) == 'menu'
          next if path.end_with?('_template')

          "/#{path}"
        end
      end

      def git(dir, *args)
        Dir.chdir(dir) { `git #{args.map { |arg| arg.include?(' ') ? arg.inspect : arg }.join(' ')} 2>/dev/null` }
      end

      def report(title, entries)
        return if entries.empty?

        puts "#{title}:"
        entries.sort.each { |entry| puts "  #{entry}" }
        puts
      end
    end
  end
end
