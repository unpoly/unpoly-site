require 'digest'
require 'json'
require 'fileutils'

module Unpoly
  module Site
    # The preview image of a page that link unfurlers (Slack, LinkedIn, X) show above its
    # title (og:image in layouts/_head). Every page that search engines may list
    # (indexable? in config.rb) gets one.
    #
    #   ┌─────────────────────────────────────────────────────────┐
    #   │ UNPOLY                                                  │
    #   │                                                         │
    #   │ up.render()                                             │  title
    #   │ Replaces elements on the current page with matching…    │  text
    #   │ ─────────────────────────────────────────────────────── │
    #   │ [{}] JavaScript function     unpoly.com/api/up.fragment │  glyph, label, URL
    #   └─────────────────────────────────────────────────────────┘
    #
    # The page gives its title (as its <h1> says it) and its text: its description, else its
    # subtitle (a release's date). The rest comes from its Markdown twin (MarkdownTwins):
    #
    # - An API symbol shows its kind's glyph and name ("JavaScript function").
    # - Any other page shows its area's glyph and name ("Learn Unpoly"), if it has one
    #   (AREAS). The landing page and /support have none.
    # - The URL is the page's breadcrumb parent: the last step of its trail (Trail), else
    #   the page itself. A parent's name is short, so the URL never runs out of room.
    #
    # An image is named after a digest of what it shows (/og/<digest>.png), so its URL
    # changes when its content does, and stays the same across deploys while it does not.
    # The build renders only the images it has not rendered before (OgImage.build!).
    class OgImage
      WIDTH = 1200
      HEIGHT = 630

      # The glyph and name of an area (MarkdownTwins::Twin#area), for pages that are not an
      # API symbol.
      AREAS = {
        'Learn' => ['book', 'Learn Unpoly'],
        'API' => ['package', 'API reference'],
        'Changes' => ['tag', 'Changes'],
      }.freeze

      TEMPLATE_DIR = File.expand_path('og_image', __dir__)
      TEMPLATE = File.join(TEMPLATE_DIR, 'template.html')
      LOGO = File.expand_path('../../../source/images/unpoly_logo.svg', __dir__)

      # Rendered images and the data they were rendered from, by digest. tmp/ survives
      # builds, so a build only renders what is new (OgImage.build!).
      CACHE_DIR = File.expand_path('../../../tmp/og-cache', __dir__)

      # A cached image that no build has used for this long is deleted. A build that only
      # renders some pages (`middleman build --glob`) uses only some images, so the cache
      # cannot be pruned by what one build used.
      CACHE_TTL = 30 * 24 * 60 * 60

      # title: the page's title, as its <h1> says it.
      # text: the page's description, else its subtitle as plain text.
      # page_path: the page's canonical path, e.g. "/api/up.render".
      # twin: the page's MarkdownTwins::Twin, if it has one.
      def initialize(title:, text:, page_path:, twin: nil)
        @title = title
        @text = text
        @page_path = page_path
        @twin = twin
      end

      # What the template draws (template.html, fill()).
      def data
        @data ||= begin
          glyph, label = symbol ? [symbol.glyph, symbol.long_kind] : AREAS[@twin&.area]
          {
            title: @title,
            code: !!symbol,
            text: @text,
            glyph: glyph && Icon.html(glyph),
            label: label,
            url: "#{Site.base_url.sub(%r{\A\w+://}, '')}#{footer_path}".chomp('/'),
          }
        end
      end

      def digest
        Digest::SHA256.hexdigest(JSON.generate(data) + self.class.template_digest)[0, 16]
      end

      def path
        "/og/#{digest}.png"
      end

      def url
        "#{Site.base_url}#{path}"
      end

      # The image's alternative text: what it says.
      def alt
        [@title, @text].compact_blank.join(': ')
      end

      # Tells the running build that a page shows this image. Middleman renders pages in
      # forked processes, so they leave the image's data in the cache for the build's last
      # step (OgImage.build!), which picks up what changed since the build started.
      def register!(cache_dir: CACHE_DIR)
        file = File.join(cache_dir, "#{digest}.json")
        if File.exist?(file)
          FileUtils.touch(file)
        else
          FileUtils.mkdir_p(cache_dir)
          # Two pages with the same image may register it at the same time.
          temp = "#{file}.#{Process.pid}"
          File.write(temp, JSON.generate(data))
          File.rename(temp, file)
        end
      end

      # The build's last step: renders the images that the build's pages registered since
      # `since` and that the cache does not have yet, and copies all of them into
      # `build_dir`/og. Chrome only starts if there is something to render. Returns what it
      # did, for the build's log.
      def self.build!(build_dir:, since:, cache_dir: CACHE_DIR)
        registered = Dir[File.join(cache_dir, '*.json')].select { |file| File.mtime(file) >= since }
        missing = registered.reject { |file| File.exist?(file.sub(/\.json\z/, '.png')) }

        if missing.any?
          Renderer.open do |renderer|
            missing.each do |file|
              png = renderer.render(JSON.parse(File.read(file)))
              File.binwrite(file.sub(/\.json\z/, '.png'), png)
            end
          end
        end

        FileUtils.mkdir_p(File.join(build_dir, 'og'))
        registered.each do |file|
          png = file.sub(/\.json\z/, '.png')
          FileUtils.cp(png, File.join(build_dir, 'og', File.basename(png)))
          FileUtils.touch(png)
        end

        cutoff = Time.now - CACHE_TTL
        Dir[File.join(cache_dir, '*')].each { |file| File.delete(file) if File.mtime(file) < cutoff }

        "#{registered.size} preview images in #{build_dir}/og, #{missing.size} of them newly rendered."
      end

      # Everything besides an image's data that decides its pixels, so that changing the
      # template, a font or the logo renders every image again. Not the Chrome version, or
      # every browser update would render every image again.
      def self.template_digest
        @template_digest ||= begin
          files = [TEMPLATE, *Dir[File.join(TEMPLATE_DIR, 'fonts', '*')].sort, LOGO]
          Digest::SHA256.hexdigest(files.map { |file| Digest::SHA256.file(file).hexdigest }.join)
        end
      end

      private

      def symbol
        @twin&.symbol
      end

      def footer_path
        @twin&.trail&.last&.last || @page_path
      end
    end
  end
end

require_relative 'og_image/renderer'
