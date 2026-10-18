module Unpoly
  module Site
    # Fails when our sources link to a document's old root path (/up.render, /caching,
    # https://unpoly.com/caching) instead of its final one (/api/up.render,
    # /learn/caching). The server would redirect the old path, but a link should not
    # take a redirect. /install and /skill too: they are short URLs for slides, not for
    # links.
    #
    # Checks the Unpoly sources (doc comments, guide pages, release notes, READMEs,
    # contributing docs) and the site's own templates, scripts and examples. Runs with
    # the build's link check and with `rake docs:check_urls`.
    class LegacyLinkCheck
      def initialize(repository = Site.current, links: LegacyLinks.new(repository))
        @links = links
      end

      # "file:line: /old -> /new" for every link to an old path.
      def problems
        @problems ||= unpoly_problems + site_problems
      end

      def run
        if problems.empty?
          puts 'No legacy link: our sources link every document at its /learn or /api path.'
          true
        else
          puts 'LEGACY LINKS (link to the /learn or /api path instead; script/url_move.rb can rewrite them):'
          problems.each { |problem| puts "  #{problem}" }
          puts
          false
        end
      end

      private

      def unpoly_problems
        @links.unpoly_files.flat_map do |file, code_aware|
          text = File.read(file)
          found = []
          @links.rewrite(text, file: file, code_aware: code_aware) do |_form, path, moved|
            found << [path, moved] if moved
          end
          describe(text, file.delete_prefix("#{@links.unpoly}/"), found)
        end
      end

      def site_problems
        @links.site_files.flat_map do |file|
          text = File.read(file)
          found = []
          @links.scan_site(text) { |path, moved| found << [path, moved] }
          describe(text, file, found)
        end
      end

      def describe(text, file, found)
        lines = text.lines
        found.uniq.map do |path, moved|
          line = lines.index { |candidate| candidate.match?(/#{Regexp.escape(path)}(?![A-Za-z0-9\-_.:$\/])/) }
          "#{file}#{line ? ":#{line + 1}" : ''}: #{path} -> #{moved}"
        end
      end
    end
  end
end
