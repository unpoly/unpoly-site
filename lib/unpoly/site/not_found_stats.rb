require 'set'
require_relative 'access_log'

module Unpoly
  module Site
    # Lists the paths that got a 404 in Apache access logs, each with a page of the
    # current build that a redirect could send it to (bin/not-found-stats).
    #
    # Attack scanners cause most 404s. A client that requested a probe path even once is
    # a scanner, and we drop all of its requests. We group the remaining GET 404s by path
    # and try the rules in KINDS on each, in order. The first rule that finds a target
    # names the row's kind.
    class NotFoundStats

      # Paths that only attack scanners request: WordPress and PHP files, dotfiles
      # (except /.well-known), config files and secrets, paths that climb out of the site.
      PROBE = %r{wp-|wordpress|rest_route=|\.php|xmlrpc|cgi-bin|phpmyadmin|/\.(?!well-known/)|\.\.|\.(env|ya?ml|toml|ini|tfstate|tfvars|pem|sql|bak)(\z|\?)}i

      KINDS = {
        fixed: 'Fixed since: the current build serves or redirects these',
        cleanup: 'Cleanup: without junk from the text around a link, .html, case, or a wrong /api/ or /learn/',
        anchor: 'Anchor: the last segment names an attribute, function or event that our pages link to with #',
        fingerprint: 'Old fingerprint: an asset under an old hash',
        api_name: 'API name without a page: the successor that unpoly-migrate records, else a Learn page (guess)',
        similar: 'Similar: the page whose name shares the most words (score from 0 to 1)',
        unmatched: 'Unmatched',
      }

      # Agents and link extractors carry over text from around a URL:
      # /api/up.render.md). or /api/up.util.isNumber() or /up.compiler)13:
      # We cut at the first character that our URLs don't use, and drop trailing punctuation.
      JUNK = /[)(\]\[*`"'|\s].*|[.,:;_]+\z/

      # up.render, up:layer:open, up-follow, X-Up-Target
      API_NAME = /\A(up[.:-]|x-up-)/i

      # The lowest score of a Similar match. One shared word of two scores 0.5, and is
      # mostly a coincidence (/tasks and up.util.task), so we want more than half.
      SIMILAR = 0.6

      # These words name half the pages, so they don't make two names similar.
      COMMON_WORDS = %w[up api learn].to_set

      Row = Struct.new(:path, :requests, :clients, :agent, :kind, :target, :note)

      def initialize(build:, migrate:, from: nil, to: nil)
        @build = build
        @dates = (from || Date.new(0))..(to || Date.new(9999))
        @redirects = read_redirects(File.join(build, '.htaccess'))
        @renamed_namespaces, @successors = read_successors(migrate)
        @pages = Dir.glob('**/index.html', base: build).map { |file| "/#{File.dirname(file)}".chomp('/.') }
        @documents_by_name = (@pages + Dir.glob('**/*.md', base: build).map { |file| "/#{file}" })
          .to_h { |document| [clean(document).downcase, document] }
        @links, @anchors = read_links
        @assets = Dir.glob('**/*.*', base: build).to_h { |file| [unfingerprinted("/#{file}"), "/#{file}"] }
        @page_words = @pages.to_h { |page| [page, words(page)] }
        @not_found = Hash.new { |hash, path| hash[path] = { clients: Hash.new(0), agents: Hash.new(0) } }
        @scanners = Set.new
        @requests_by_client = Hash.new(0)
      end

      def read(folder)
        AccessLog.new(folder).each do |request|
          next unless request && @dates.cover?(request.date)
          @requests_by_client[request.client] += 1
          @scanners << request.client if probe?(request.path)
          next unless request.method == 'GET' && request.status == 404
          path = request.page || request.path
          @not_found[path][:clients][request.client] += 1
          @not_found[path][:agents][request.agent_name] += 1
        end
        self
      end

      # The 404 paths that non-scanners requested, most clients first: a bot that repeats
      # itself inflates the request count, not the client count.
      def rows
        @rows ||= @not_found.filter_map { |path, counts|
          clients = counts[:clients].except(*@scanners)
          next if clients.empty?
          Row.new(path, clients.values.sum, clients.size, counts[:agents].max_by(&:last).first, *match(path))
        }.sort_by { |row| [-row.clients, -row.requests, row.path] }
      end

      def report(top: 30)
        all_404s = @not_found.sum { |_, counts| counts[:clients].values.sum }
        lines = [
          "#{all_404s} GET 404s. Dropped #{@scanners.size} scanners (of #{@requests_by_client.size} clients) " \
            "with #{@scanners.sum { |client| @requests_by_client[client] }} requests, " \
            "#{all_404s - rows.sum(&:requests)} of them GET 404s.",
          "Left: #{rows.sum(&:requests)} requests for #{rows.size} paths.",
        ]
        rows.group_by(&:kind).sort_by { |kind, _| KINDS.keys.index(kind) }.each do |kind, group|
          shown = group.first(top)
          lines << '' << "#{KINDS[kind]} (#{group.size} paths, #{group.sum(&:requests)} requests)"
          lines << format('%7s %8s  %s', 'Clients', 'Requests', 'Path → Target (note) [top user agent]')
          shown.each do |row|
            target = " → #{row.target}" if row.target
            note = " (#{row.note})" if row.note
            lines << format('%7d %8d  %s%s%s  [%s]', row.clients, row.requests, display(row.path), target, note, row.agent)
          end
          lines << "        … and #{group.size - top} more" if group.size > shown.size
        end
        lines << '' << 'Draft redirects for API names and anchors, from paths without junk'
        rows.each do |row|
          next unless %i[api_name anchor].include?(row.kind) && row.target && !row.path.match?(JUNK)
          guess = '  # Guess' if row.note&.start_with?('guess')
          lines << "RedirectPermanent #{row.path} #{row.target}#{guess}"
        end
        lines.join("\n")
      end

      private

      def probe?(path)
        decoded = URI.decode_uri_component(path).scrub rescue path # Finds /settings%2F.env
        decoded.match?(PROBE)
      end

      def display(path)
        (path.empty? ? '/' : path)[0, 100]
      end

      # [kind, target, note]
      def match(path)
        if (target = resolve(path)) then [:fixed, target]
        elsif (target = cleanup(path)) then [:cleanup, target]
        elsif (target = anchor(path)) then [:anchor, target]
        elsif (target = @assets[unfingerprinted(path)]) then [:fingerprint, target]
        elsif name(path).match?(API_NAME) then [:api_name, *successor(path)]
        elsif (target, score = similar(path)) && score >= SIMILAR then [:similar, target, format('%.2f', score)]
        else [:unmatched]
        end
      end

      # Where the current site sends a path: to itself if the build has it, else as
      # .htaccess does (the short-path rule, then the redirects). nil for a 404.
      def resolve(path)
        return path if File.file?(File.join(@build, path)) || document?(path)
        # /foo to /learn/foo, else to /api/foo. The same for /foo.md.
        short = ['/learn', '/api'].map { |prefix| prefix + path }.find { |long| document?(long) } and return short
        # A .md URL without a file goes to its page.
        return resolve(path.delete_suffix('.md')) if path.end_with?('.md')
        @redirects.each do |pattern, target|
          match = pattern.match(path) and return target.gsub(/\$(\d)/) { match[$1.to_i] }
        end
        nil
      end

      # A page, or the Markdown twin of one.
      def document?(path)
        File.file?(File.join(@build, path.end_with?('.md') ? path : File.join(path, 'index.html')))
      end

      # [pattern, target] for each RedirectPermanent and RedirectMatch.
      def read_redirects(file)
        File.foreach(file).filter_map do |line|
          case line
          # A prefix: /from also redirects /from/foo, to /to/foo.
          when /^\s*RedirectPermanent\s+(\S+)\s+(\S+)/ then [%r{\A#{Regexp.escape($1)}(/.*)?\z}, "#{$2}$1"]
          when /^\s*RedirectMatch\s+(?:permanent\s+)?(\S+)\s+(\S+)/ then [Regexp.new($1), $2]
          end
        end
      end

      # '/api/up.util.isNumber()' => '/up.util.isNumber'. '/[up-target]' => '/up-target'.
      def clean(path)
        path.gsub(%r{/\[([^\]]*)\]}, '/\1').sub(JUNK, '').sub(/(\/index)?\.html\z/, '').chomp('/').sub(%r{\A(/(api|learn))+(?=/)}i, '')
      end

      # '/api/up.util.isNumber()' => 'up.util.isNumber'
      def name(path)
        File.basename(clean(path))
      end

      def cleanup(path)
        clean = clean(path)
        resolve(clean) || @documents_by_name[clean.downcase]
      end

      # '/up-target' => '/api/up-follow#up-target'
      def anchor(path)
        @anchors[name(path).downcase] if name(path).match?(API_NAME)
      end

      # How many links point to each page, and for each #id the page that has the most
      # links among those we link to with that #id. So a param of both [up-follow] and
      # [up-submit] goes to [up-follow].
      def read_links
        links = Hash.new(0)
        pages_by_id = Hash.new { |hash, id| hash[id] = Set.new }
        @pages.each do |page|
          File.read(File.join(@build, page, 'index.html')).scan(/href="(\/[^"#]*)(?:#([^"]+))?"/) do |target, id|
            links[target] += 1
            pages_by_id[id.downcase] << target if id
          end
        end
        [links, pages_by_id.to_h { |id, pages| [id, "#{pages.max_by { |page| [links[page], page] }}##{id}"] }]
      end

      # /images/favicon-2d52fc7a.png => /images/favicon.png
      def unfingerprinted(path)
        path.sub(/-\h{8}(?=\.\w+\z)/, '')
      end

      # [page, note] for an old API name: its successor as unpoly-migrate records it, or
      # else a Learn page with a similar name, as a guess.
      def successor(path)
        name = name(path)
        successor = @successors[name] || @renamed_namespaces.filter_map { |old, new| name.sub(old, new) if name.start_with?("#{old}.") }.first
        if successor
          successor = @successors[successor] while @successors[successor] && !page_for(successor) # Renamed twice
          page = page_for(successor) and return [page, "successor #{successor}"]
          [nil, "successor #{successor} has no page"]
        else
          page, score = similar(path, @pages.grep(%r{\A/learn/}))
          [page, "guess, score #{format('%.2f', score)}"] if score && score >= SIMILAR
        end
      end

      def page_for(name)
        path = "/#{name}"
        resolve(path) || cleanup(path) || anchor(path)
      end

      # Old names and their successors, from the calls in unpoly-migrate:
      #
      #     renamedNamespace('layout', 'viewport')
      #     renamedEvent('up:modal:open', 'up:layer:open')
      #     renamedProperty(config, 'fields', 'fieldSelectors', { label: 'up.form.config' })
      #     deprecated('up.util.any()', 'up.util.some()')
      #
      # A renamed namespace also renames everything in it (up.layout.revealHash). An old
      # namespace without a rename of its own (up.modal) goes where most of its recorded
      # members went (up.layer). Returns [renamed namespaces, successors].
      def read_successors(dir)
        namespaces = {}
        successors = {}
        Dir.glob(File.join(dir, '**/*.js')).sort.each do |file|
          File.foreach(file) do |line|
            call = line.match(/up\.migrate\.(renamed\w+|deprecated)\((.*)\)/) or next
            function, args = call.captures
            old, new = args.scan(/'([^']*)'|"([^"]*)"|`([^`]*)`/).flatten.compact
            case function
            when 'renamedNamespace'
              old, new = "up.#{old}", "up.#{new}"
              namespaces[old] = new
            when 'renamedProperty'
              owner = args[/\A(up\.[\w.]+)/, 1] || args[/label: '([^']+)'/, 1] or next
              old, new = "#{owner}.#{old}", "#{owner}.#{new}"
            else
              old, new = api_name(old), api_name(new)
            end
            successors[old] ||= new if old&.match?(API_NAME) && new
          end
        end
        successors.keys.group_by { |old| old[/\Aup\.\w+(?=\.)/] }.each do |namespace, members|
          new, count = members.map { |member| successors[member][/\A[^.]+\.[^.]+/] }.tally.max_by(&:last)
          successors[namespace] ||= new if namespace && new != namespace && count > members.size / 2
        end
        [namespaces, successors]
      end

      # 'up.util.pick(object, keys)' => 'up.util.pick'. 'up.Request#loadPage()' =>
      # 'up.Request.prototype.loadPage'. nil for prose like "a `for` loop".
      def api_name(code)
        code&.delete_prefix('!')&.[](/\A[\w.:#-]+(?=\(|\s*=|\s*\{|\z)/)&.sub('#', '.prototype.')
      end

      # [page, score] for the page whose words overlap most with the path's, from 0 to 1.
      # A tie goes to the page with more links to it.
      def similar(path, pages = @pages)
        words = words(clean(path))
        return if words.empty?
        pages.map { |page| [page, (words & @page_words[page]).size.to_f / (words | @page_words[page]).size] }
          .max_by { |page, score| [score, @links[page]] }
      end

      # A path's words, crudely stemmed, without numbers: '/loading-indicators' => {'load', 'indicator'}
      def words(path)
        path.split(/[^a-zA-Z]+|(?<=[a-z])(?=[A-Z])/).map { |word| word.downcase.sub(/(ing|ed|s)\z/, '').sub(/(?<=\w{3})e\z/, '') }
          .reject { |word| word.size < 2 || COMMON_WORDS.include?(word) }.to_set
      end

    end
  end
end
