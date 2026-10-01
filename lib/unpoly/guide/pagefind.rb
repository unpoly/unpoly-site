require 'shellwords'

module Unpoly
  module Guide
    # Runs the Pagefind indexer over a finished Middleman build.
    #
    # Pagefind is a build tool, not a frontend library: it reads the static HTML we just
    # wrote and emits its own runtime (`pagefind.js`, a wasm module and the index chunks)
    # into `build/pagefind`. Nothing here is bundled by Sprockets, and the site's
    # JavaScript loads that runtime from the URL the indexer wrote it to.
    #
    # We invoke it with `npx` at a pinned version, which is Pagefind's own documented way
    # of running it after a build. That keeps it a build-tool invocation, like the link
    # checker — there is no package.json and no frontend dependency.
    #
    # This class exists so that the pinned version lives in ONE place: the build hook in
    # config.rb and the `search:index` rake task both go through here.
    class Pagefind
      class Error < Guide::Error; end

      VERSION = '1.5.2'

      PACKAGE = "pagefind@#{VERSION}".freeze

      # Indexes a finished build. Returns a short report for the build log.
      def index!(site_dir)
        File.directory?(site_dir) or raise Error, "Not a directory: #{site_dir}"
        ensure_npx!

        started_at = Time.now
        output = `npx --yes #{PACKAGE.shellescape} --site #{site_dir.shellescape} 2>&1`
        $?.success? or raise Error, "Pagefind failed:\n#{output}"

        Report.new(output, Time.now - started_at, File.join(site_dir, 'pagefind'))
      end

      private

      def ensure_npx!
        return if system('npx', '--version', out: File::NULL, err: File::NULL)

        raise Error, <<~MESSAGE
          Cannot index the site for search: `npx` was not found.

          Search is built by #{PACKAGE}, which the build runs through npx. Install
          Node.js — the Unpoly repository needs it as well — or build without a search
          index using SKIP_SEARCH_INDEX=1.
        MESSAGE
      end

      # What the build log says about an index that was just written.
      class Report
        def initialize(output, seconds, index_dir)
          @output = output
          @seconds = seconds
          @index_dir = index_dir
        end

        attr_reader :output, :seconds, :index_dir

        def pages
          output[/Indexed (\d+) pages?/, 1]&.to_i
        end

        def bytes
          Dir.glob(File.join(index_dir, '**', '*')).sum { |file| File.file?(file) ? File.size(file) : 0 }
        end

        def to_s
          format('Indexed %s pages in %.2f s (%.1f MB in %s)',
                 pages || '?', seconds, bytes / 1_048_576.0, index_dir)
        end
      end

    end
  end
end
