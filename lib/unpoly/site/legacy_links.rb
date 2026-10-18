require 'set'

module Unpoly
  module Site
    # Links to the root paths that documents had before the docs rework 2026 moved them
    # under /learn and /api (/caching, /up.render).
    #
    # The server still redirects such a path (source/.htaccess.erb), but our own sources
    # must link to the final path. script/url_move.rb rewrites the links once, and
    # LegacyLinkCheck fails the build on any that comes back.
    #
    # Only paths of documents count. Everything else at the root (/, /learn, /api,
    # /changes/..., /support, /images/..., /index.md) is no legacy path.
    class LegacyLinks
      # A path as the docs spell it: up.render, up:link:follow, up.$compiler, start/overview.
      PATH = %r{/[A-Za-z0-9\-_.:$/]*}

      # Fenced code blocks and code spans (as in Wikilink::CODE_PATTERN).
      CODE_PATTERN = /((?:^[ \t]*(?:```|~~~).*?^[ \t]*(?:```|~~~)[ \t]*$)|(?:`[^`\n]*`))/m

      # Comments in library code, where the doc comments live.
      JS_COMMENT = %r{/\*.*?\*/|^[ \t]*//[^\n]*}m

      # Link forms in prose: [label](/path), href="/path".
      PROSE_LINKS = [
        /(?<=\]\()(#{PATH})/,
        /(?<=\bhref=["'])(#{PATH})/,
      ].freeze

      # Link forms that can only mean this site, rewritten even in code.
      SITE_LINKS = [
        /(?<=\[\[=base_url\]\])(#{PATH})/,
        %r{(?<=\bhttps://unpoly\.com|\bhttp://unpoly\.com)(#{PATH})},
        %r{(?<![\w./]unpoly\.com)(?<=unpoly\.com)(#{PATH})}, # spelled out as text: [unpoly.com/skill](...)
      ].freeze

      # In the site's own templates and scripts, a path in quotes: hyperlink 'Next', '/caching'.
      QUOTED_PATH = /(?<=["'])(#{PATH})(?=["'#?])/

      FORM_NAMES = [
        'Markdown links [label](/path)',
        'href="/path" in prose',
        '[[=base_url]]/path',
        'https://unpoly.com/path',
        'unpoly.com/path as text',
      ].freeze

      def initialize(repository = Site.current)
        @repository = repository
        @unpoly = File.realpath(repository.path)
      end

      attr_reader :unpoly

      # Every document's old path and its new one: "/up.render" => "/api/up.render".
      def moves
        @moves ||= begin
          moves = {}
          @repository.documentables.select(&:guide_page?).reject(&:fixture?).each do |documentable|
            moves["/#{documentable.guide_id}"] = documentable.guide_path
          end
          @repository.toc.areas.each do |area|
            area.topics.filter_map(&:index).each { |index| moves["/#{index.slug}"] = index.guide_path }
          end
          moves
        end
      end

      # The new path for a link target, or nil when it is not a document's old path.
      # Keeps an .md suffix (a Markdown twin) and trailing punctuation.
      def move(path)
        return moves[path] if moves.key?(path)

        if path.end_with?('.md') && moves.key?(base = path.delete_suffix('.md'))
          return "#{moves[base]}.md"
        end

        if (match = path.match(/\A(.+?)([.:\/]+)\z/)) && (moved = move(match[1]))
          return "#{moved}#{match[2]}"
        end

        nil
      end

      # Files in the Unpoly repository with links to the site, and whether their code
      # blocks are examples to leave alone (doc comments, guide pages, partials,
      # release notes, READMEs). In the other files, Markdown links are examples of the
      # docs' own syntax, so they are rewritten even in code.
      def unpoly_files
        code_aware = %w[src/**/*.{js,md,erb,coffee,sass} docs/changes/*.md README.md CHANGELOG.md]
        other = %w[docs/contributing/*.md dist/README.md dist/CHANGELOG.md .github/**/*.yml]
        files = code_aware.flat_map { |pattern| Dir[File.join(@unpoly, pattern)].map { |file| [file, true] } } +
          other.flat_map { |pattern| Dir[File.join(@unpoly, pattern)].map { |file| [file, false] } }
        files.uniq(&:first).sort
      end

      # The text of an Unpoly file with its links to old paths rewritten. Yields the
      # form, the old path and the new one (nil for a root path that is no document).
      # In .js files, links count in comments (the doc comments), and outside of them
      # only full unpoly.com URLs (error messages): a path like '/users' in code is an
      # example or an app's URL. Unpoly and the site deploy minutes apart, so a moved
      # URL in a message is no problem.
      def rewrite(text, file:, code_aware:, &block)
        if file.end_with?('.js')
          text.split(/(#{JS_COMMENT})/m).each_with_index.map { |part, index|
            index.odd? ? rewrite_docs(part, &block) : rewrite_links(part, [SITE_LINKS[1]], &block)
          }.join
        elsif code_aware
          rewrite_docs(text, &block)
        else
          rewrite_links(text, PROSE_LINKS + SITE_LINKS, &block)
        end
      end

      # Templates, scripts and examples of the site itself (this repository).
      def site_files
        %w[source/**/*.{erb,js,md,yml,rb} examples/**/*.{erb,html,md,yml,js} config.rb].flat_map { |pattern|
          Dir[pattern]
        }.uniq.sort - ['source/.htaccess.erb']
      end

      # Links to old paths in a file of the site: quoted paths and unpoly.com URLs.
      # Yields the old path and the new one.
      def scan_site(text)
        rewrite_links(text, [QUOTED_PATH, PROSE_LINKS[0]] + SITE_LINKS) do |_form, path, moved|
          yield path, moved if moved
        end
      end

      private

      def rewrite_docs(text, &block)
        text.split(CODE_PATTERN).each_with_index.map { |part, index|
          part = rewrite_links(part, PROSE_LINKS, &block) if index.even?
          rewrite_links(part, SITE_LINKS, &block)
        }.join
      end

      def rewrite_links(text, patterns)
        patterns.inject(text) do |memo, pattern|
          memo.gsub(pattern) do |path|
            moved = move(path)
            yield form_name(pattern), path, moved
            moved || path
          end
        end
      end

      def form_name(pattern)
        index = (PROSE_LINKS + SITE_LINKS).index { |form| form.equal?(pattern) }
        index ? FORM_NAMES[index] : 'quoted path'
      end
    end
  end
end
