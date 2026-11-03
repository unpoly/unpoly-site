require 'date'
require 'uri'
require 'zlib'

module Unpoly
  module Site
    # Reads Apache access logs in the combined format, as bin/markdown-stats and
    # bin/not-found-stats analyze them.
    class AccessLog

      LINE = %r{\A(?<client>\S+) \S+ \S+ \[(?<day>[^:]+)\S* \S+\] "(?<method>\S+) (?<path>\S+)[^"]*" (?<status>\d+) (?<size>\d+|-) "(?<referer>(?:[^"\\]|\\.)*)" "(?<agent>(?:[^"\\]|\\.)*)"}

      # One line of the log. The client is an IP address: keep it in memory, never print it.
      Request = Data.define(:client, :date, :method, :path, :status, :size, :referer, :agent) do
        # /api/up%3Arender/?foo=bar => /api/up:render. The landing page is ''.
        # nil for paths that are not in the site.
        def page
          page = URI.decode_uri_component(path.sub(/\?.*/, '')).scrub.chomp('/')
          page unless page.match?(/\.\.|\0/) # Probes for files outside the site
        rescue ArgumentError # Broken percent-encoding
          nil
        end

        # The user agent's product, without version: GPTBot, Chrome, curl.
        def agent_name
          agent[/compatible; ([^;)\/]+)/, 1]&.strip ||
            agent[/[a-z][\w-]*(bot|spider|crawler|agent)[\w-]*/i] ||
            { 'Edg/' => 'Edge', 'OPR/' => 'Opera', 'Firefox/' => 'Firefox', 'Chrome/' => 'Chrome', 'Safari/' => 'Safari' }
              .find { |token, _| agent.include?(token) }&.last ||
            agent[/\A[^\/\s(;]+/] ||
            '-'
        end
      end

      def initialize(folder)
        @folder = folder
      end

      # Yields a Request for every line of every *access.log* file below the folder,
      # plain or gzipped, or nil for a line we can't parse.
      def each
        Dir.glob(File.join(@folder, '**/*access.log*')).sort.each do |file|
          if file.end_with?('.gz')
            Zlib::GzipReader.open(file) { |gz| gz.each_line { |line| yield self.class.parse(line) } }
          else
            File.foreach(file) { |line| yield self.class.parse(line) }
          end
        end
      end

      def self.parse(line)
        match = LINE.match(line.scrub) or return
        Request.new(
          client: match[:client],
          date: Date.strptime(match[:day], '%d/%b/%Y'),
          method: match[:method],
          path: match[:path],
          status: match[:status].to_i,
          size: match[:size].to_i,
          referer: match[:referer],
          agent: match[:agent],
        )
      end

    end
  end
end
