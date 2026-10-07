require 'pathname'

module Unpoly
  module Guide
    # Where the links of a Markdown page point. HtmlToMarkdown asks its resolver for
    # every href, every media URL and the URL of the page's own HTML version.
    #
    # A link goes to the target's .md twin only when the target has one; otherwise it
    # keeps its extension-less URL. Anchors are kept.
    module MarkdownLinks
      # The site's own .md twins: absolute URLs on a base URL, so that a page fetched
      # into an agent's context still links somewhere.
      class Web
        # Prose sometimes links the site by its full URL.
        SITE_ORIGIN = %r{\Ahttps?://unpoly\.com(?=[/#]|\z)}

        # twin_paths: the paths ("/up.render") that have a .md twin.
        # page_path: the path of the page being converted.
        def initialize(base_url:, twin_paths:, page_path:)
          @base_url = base_url
          @twin_paths = twin_paths
          @page_path = page_path
        end

        def href(url)
          url = '/' + url.sub(SITE_ORIGIN, '').delete_prefix('/') if url =~ SITE_ORIGIN
          return url if url.start_with?('#') || url =~ /\A[a-z][a-z0-9+.-]*:/i

          path, fragment = url.split('#', 2)
          resolve_path(absolute_path(path), fragment && "##{fragment}")
        end

        # Images and videos are never copied, so they always point to the site.
        def media_url(src)
          return src if src =~ /\A[a-z][a-z0-9+.-]*:/i
          "#{@base_url}#{absolute_path(src)}"
        end

        # The HTML version of the page being converted.
        def page_url
          "#{@base_url}#{@page_path}"
        end

        private

        def absolute_path(path)
          return @page_path if path.empty?
          return path if path.start_with?('/')
          File.expand_path(path, File.dirname(@page_path))
        end

        # A link to the site: to the .md twin where there is one.
        def resolve_path(path, fragment)
          path = path.chomp('/') unless path == '/'
          markdown = path == '/' ? '/index.md' : "#{path}.md"
          "#{@base_url}#{@twin_paths.include?(path) || path == '/' ? markdown : path}#{fragment}"
        end
      end

      # The skill's reference files: a relative file path when the target is part of
      # the skill (it must work offline), a link to unpoly.com otherwise.
      class Skill < Web
        # files: { "/up.render" => "references/api/up-render-function.md", ... }
        # file: the skill-relative path of the file being written.
        def initialize(files:, file:, **options)
          super(base_url: Guide.base_url, **options)
          @files = files
          @file = file
        end

        # A skill-relative path, as seen from the file being written.
        def relative(target_file)
          Pathname.new(target_file).relative_path_from(Pathname.new(File.dirname(@file))).to_s
        end

        private

        def resolve_path(path, fragment)
          if (target = @files[path.chomp('/')])
            "#{relative(target)}#{fragment}"
          else
            super
          end
        end
      end
    end
  end
end
