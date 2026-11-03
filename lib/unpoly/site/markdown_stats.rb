require 'set'
require 'zlib'
require_relative 'access_log'

module Unpoly
  module Site
    # Counts how often the site delivered a page as HTML or as its Markdown twin, from
    # Apache access logs in the combined format (bin/markdown-stats).
    #
    # The log doesn't show whether a request for /api/up.render got the twin through
    # content negotiation (see "Markdown for agents" in .htaccess). We tell from the
    # response size: a twin has the size that a request for /api/up.render.md got (on
    # any day in the logs), or the size of the .md file in the build.
    #
    # A typo fixed between two deploys moves a twin's size by a few bytes, so a size up
    # to TOLERANCE bytes off also counts. But only when the page's HTML, raw or gzipped,
    # is clearly farther away: a twin is often within a few percent of its gzipped HTML,
    # so the closest size alone would count HTML as Markdown.
    class MarkdownStats

      TOLERANCE = 32 # bytes
      HTML_MARGIN = 0.05 # of the response size

      BUCKETS = {
        html: 'HTML',
        explicit: 'Markdown via .md URL',
        negotiated: 'Markdown via Accept',
      }

      # Who asked for a .md URL. Crawlers fetch every link they find, so the other two
      # are the requests that wanted Markdown on purpose.
      ORIGINS = {
        for_user: 'agent for a user',
        clicked: 'from a page here',
        crawler: 'other (crawlers)',
      }

      # A click on a page's Markdown button sends the page as referer. Some crawlers send
      # one too (GPTBot, Applebot), so a referer only counts from a browser.
      OWN_PAGE = %r{\Ahttps?://unpoly\.com(/|\z)}
      CRAWLER = /bot|spider|crawler/i

      # Lines we don't count, by reason.
      attr_reader :skipped

      def initialize(build:, from: nil, to: nil)
        @build = build
        @dates = (from || Date.new(0))..(to || Date.new(9999))
        @requests = [] # [agent, page, size, explicit]
        @origins = ORIGINS.keys.to_h { |origin| [origin, 0] } # Of the .md URL requests
        @markdown_sizes = Hash.new { |hash, page| hash[page] = Set[build_markdown_size(page)] }
        @html_sizes = Hash.new { |hash, page| hash[page] = build_html_sizes(page) }
        @skipped = Hash.new(0)
      end

      # Reads all access logs below the given folder, plain or gzipped.
      def read(folder)
        AccessLog.new(folder).each { |request| add(request) }
        self
      end

      # Takes an AccessLog::Request, or nil for an unparsable line.
      def add(request)
        request or return @skipped[:unparsable] += 1
        return @skipped[:outside_dates] += 1 unless @dates.cover?(request.date)
        # HEAD responses have no body to measure, and other statuses deliver no page.
        return @skipped[:not_a_GET_200] += 1 unless request.method == 'GET' && request.status == 200

        path = request.page
        explicit = path&.end_with?('.md')
        page = explicit ? path.delete_suffix('.md').delete_suffix('/index') : path
        return @skipped[:not_a_page] += 1 unless page && File.file?(page_file(page, explicit))

        size = request.size
        agent = request.agent_name
        if explicit
          @markdown_sizes[page] << size
          @origins[origin(agent, request.referer)] += 1
        end
        @requests << [agent, page, size, explicit]
      end

      # { 'ClaudeBot' => { html: 3, explicit: 2, negotiated: 1 }, ... }, busiest agent first.
      def by_agent
        counts = Hash.new { |hash, agent| hash[agent] = BUCKETS.keys.to_h { |bucket| [bucket, 0] } }
        @requests.each do |agent, page, size, explicit|
          bucket = explicit ? :explicit : (markdown?(page, size) ? :negotiated : :html)
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
        percent = ->(count) { 100.0 * count / [total, 1].max }
        lines = totals.flat_map do |bucket, count|
          line = format('%-22s %8d  %5.1f%%', BUCKETS[bucket], count, percent.(count))
          next [line] unless bucket == :explicit
          [line, *@origins.map { |origin, count| format('  %-20s %8d  %5.1f%%', ORIGINS[origin], count, percent.(count)) }]
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

      def page_file(page, markdown)
        if markdown
          File.join(@build, page.empty? ? 'index.md' : "#{page}.md")
        else
          File.join(@build, page, 'index.html')
        end
      end

      def markdown?(page, size)
        distance = distance(@markdown_sizes[page], size) or return false
        distance.zero? || (distance <= TOLERANCE && distance(@html_sizes[page], size) > distance + HTML_MARGIN * size)
      end

      def distance(sizes, size)
        sizes.filter_map { |known| (known - size).abs if known }.min
      end

      # Raw and gzipped.
      def build_html_sizes(page)
        html = File.binread(page_file(page, false))
        [html.bytesize, Zlib.gzip(html).bytesize]
      end

      def build_markdown_size(page)
        file = page_file(page, true)
        File.size(file) if File.file?(file)
      end

      # Agents that fetch while answering a user name themselves Claude-User, ChatGPT-User,
      # ExaUser.
      def origin(agent, referer)
        if agent.end_with?('User') then :for_user
        elsif referer.match?(OWN_PAGE) && !agent.match?(CRAWLER) then :clicked
        else :crawler
        end
      end

    end
  end
end
