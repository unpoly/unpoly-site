require 'set'

module Unpoly
  module Guide
    # "No lost URL": every address unpoly.com serves today must still resolve after the
    # docs rework, either to a page or through a redirect rule.
    #
    # We compare against the `master` revision of both repositories, since that is what
    # is deployed. API symbols are left out on purpose: a renamed symbol keeps its page
    # as `@deprecated`, so its URL never disappears.
    class UrlCheck
      REDIRECT_PATTERN = /^\s*RedirectPermanent\s+(\S+)\s+(\S+)\s*$/

      def initialize(repository = Guide.current, revision: 'master')
        @repository = repository
        @revision = revision
      end

      attr_reader :repository, :revision

      def run
        lost = old_paths.reject { |path| resolves?(path) }
        pending = redirects.reject { |_from, to| target_resolves?(to) }

        report('LOST (no page and no redirect)', lost)
        report('PENDING (redirect target not built yet)', pending.map { |from, to| "#{from} -> #{to}" })

        if lost.empty?
          puts "No lost URL: all #{old_paths.size} published addresses still resolve."
        end

        lost.empty?
      end

      # Paths the site serves after the rework.
      def current_paths
        @current_paths ||= Set.new(
          repository.documentables.select(&:guide_page?).map(&:guide_path) + site_paths(nil)
        )
      end

      # Paths the deployed site serves today.
      def old_paths
        @old_paths ||= (old_page_paths + site_paths(revision)).uniq.sort
      end

      def redirects
        @redirects ||= [
          File.read('source/.htaccess.erb'),
          repository.migrate_redirects,
        ].flat_map { |text| text.scan(REDIRECT_PATTERN) }.to_h
      end

      private

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

        documentable = repository.find_by_guide_id(path.delete_prefix('/'))
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
