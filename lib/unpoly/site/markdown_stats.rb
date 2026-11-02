require 'date'
require 'set'
require 'uri'
require 'zlib'

module Unpoly
  module Site
    # Counts how often the site delivered a page as HTML or as its Markdown twin, from
    # Apache access logs in the combined format (bin/markdown-stats).
    #
    # The log doesn't show whether a request for /api/up.render got the twin through
    # content negotiation (see "Markdown for agents" in .htaccess). We tell from the
    # response size: a twin has exactly the size that a request for /api/up.render.md
    # got (on any day in the logs), or the size of the .md file in the build.
    #
    # The size must match exactly. A twin is often within a few percent of its gzipped
    # HTML, and site edits change sizes by more than that, so the closest size would
    # count HTML as Markdown.
    class MarkdownStats

      BUCKETS = {
        html: 'HTML',
        explicit: 'Markdown via .md URL',
        negotiated: 'Markdown via Accept',
      }

      QUOTED = /"(?:[^"\\]|\\.)*"/
      LINE = %r{\A\S+ \S+ \S+ \[(?<day>[^:]+)\S* \S+\] "(?<method>\S+) (?<path>\S+)[^"]*" (?<status>\d+) (?<size>\d+|-) #{QUOTED} "(?<agent>(?:[^"\\]|\\.)*)"}

      # Lines we don't count, by reason.
      attr_reader :skipped

      def initialize(build:, from: nil, to: nil)
        @build = build
        @dates = (from || Date.new(0))..(to || Date.new(9999))
        @requests = [] # [agent, page, size, explicit]
        @markdown_sizes = Hash.new { |hash, page| hash[page] = Set[build_markdown_size(page)] }
        @skipped = Hash.new(0)
      end

      # Reads all access logs below the given folder, plain or gzipped.
      def read(folder)
        Dir.glob(File.join(folder, '**/*access.log*')).sort.each do |file|
          if file.end_with?('.gz')
            Zlib::GzipReader.open(file) { |gz| gz.each_line { |line| add(line) } }
          else
            File.foreach(file) { |line| add(line) }
          end
        end
        self
      end

      def add(line)
        match = LINE.match(line.scrub) or return @skipped[:unparsable] += 1
        return @skipped[:outside_dates] += 1 unless @dates.cover?(Date.strptime(match[:day], '%d/%b/%Y'))
        # HEAD responses have no body to measure, and other statuses deliver no page.
        return @skipped[:not_a_GET_200] += 1 unless match[:method] == 'GET' && match[:status] == '200'

        path = page_path(match[:path])
        explicit = path&.end_with?('.md')
        page = explicit ? path.delete_suffix('.md').delete_suffix('/index') : path
        return @skipped[:not_a_page] += 1 unless page && File.file?(page_file(page, explicit))

        size = match[:size].to_i
        @markdown_sizes[page] << size if explicit
        @requests << [agent_name(match[:agent]), page, size, explicit]
      end

      # { 'ClaudeBot' => { html: 3, explicit: 2, negotiated: 1 }, ... }, busiest agent first.
      def by_agent
        counts = Hash.new { |hash, agent| hash[agent] = BUCKETS.keys.to_h { |bucket| [bucket, 0] } }
        @requests.each do |agent, page, size, explicit|
          bucket = explicit ? :explicit : (@markdown_sizes[page].include?(size) ? :negotiated : :html)
          counts[agent][bucket] += 1
        end
        counts.sort_by { |agent, agent_counts| [-agent_counts.values.sum, agent] }.to_h
      end

      def totals
        agents = by_agent.values
        BUCKETS.keys.to_h { |bucket| [bucket, agents.sum { |counts| counts[bucket] }] }
      end

      def report(by_agent: false)
        totals = self.totals
        total = totals.values.sum
        lines = totals.map do |bucket, count|
          format('%-22s %8d  %5.1f%%', BUCKETS[bucket], count, 100.0 * count / [total, 1].max)
        end
        lines << format('%-22s %8d', 'Total', total)
        lines << '' << "Skipped #{@skipped.values.sum} lines: " +
          @skipped.sort_by { |_, count| -count }.map { |reason, count| "#{count} #{reason.to_s.tr('_', ' ')}" }.join(', ')
        if by_agent
          lines << '' << format('%-30s %8s %8s %8s', 'User agent', 'HTML', '.md', 'Accept')
          self.by_agent.each do |agent, counts|
            lines << format('%-30s %8d %8d %8d', agent[0, 30], *counts.values)
          end
        end
        lines.join("\n")
      end

      private

      # /api/up%3Arender/?foo=bar => /api/up:render. The landing page is ''.
      # nil for paths that are not in the site.
      def page_path(path)
        path = URI.decode_uri_component(path.sub(/\?.*/, '')).chomp('/')
        path unless path.match?(/\.\.|\0/) # Probes for files outside the site
      rescue ArgumentError # Broken percent-encoding
        nil
      end

      def page_file(page, markdown)
        if markdown
          File.join(@build, page.empty? ? 'index.md' : "#{page}.md")
        else
          File.join(@build, page, 'index.html')
        end
      end

      def build_markdown_size(page)
        file = page_file(page, true)
        File.size(file) if File.file?(file)
      end

      # The user agent's product, without version: GPTBot, Chrome, curl.
      def agent_name(agent)
        agent[/compatible; ([^;)\/]+)/, 1]&.strip ||
          agent[/[a-z][\w-]*(bot|spider|crawler|agent)[\w-]*/i] ||
          { 'Edg/' => 'Edge', 'OPR/' => 'Opera', 'Firefox/' => 'Firefox', 'Chrome/' => 'Chrome', 'Safari/' => 'Safari' }
            .find { |token, _| agent.include?(token) }&.last ||
          agent[/\A[^\/\s(;]+/] ||
          '-'
      end

    end
  end
end
