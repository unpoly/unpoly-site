module Unpoly
  module Site
    # An icon, for templates (through the `icon` helper in config.rb) and for HTML built
    # in lib/. Most come from the Font Awesome webfont; the few it lacks are inline SVGs
    # registered in SVG below.
    #
    # An icon is decorative by default: screen readers and the Markdown twins skip it
    # (aria-hidden). An icon that says something no text next to it says gets a label,
    # which makes it an image with an accessible name. The Markdown twin writes such an
    # icon as "(label)".
    module Icon
      # Icons Font Awesome 4 doesn't have, drawn in currentColor so they take the
      # surrounding text color. Sized like a webfont icon (icon.sass).
      SVG = {
        # Four tiles: a chapter's overview, on the Learn hub (_chapter_pages.html.erb)
        # and in the sidebar (menu.coffee).
        'overview' => {
          view_box: '0 0 16 16',
          body: '<g fill="none" stroke="currentColor" stroke-width="1.6"><rect x="1.5" y="1.5" width="5" height="5" rx="1"/><rect x="9.5" y="1.5" width="5" height="5" rx="1"/><rect x="1.5" y="9.5" width="5" height="5" rx="1"/><rect x="9.5" y="9.5" width="5" height="5" rx="1"/></g>',
        },
        # The Markdown mark by Dustin Curtis (CC0, github.com/dcurtis/markdown-mark).
        'markdown' => {
          view_box: '0 0 208 128',
          body: '<rect width="198" height="118" x="5" y="5" ry="10" fill="none" stroke="currentColor" stroke-width="10"/>' \
                '<path fill="currentColor" d="M30 98V30h20l20 25 20-25h20v68H90V59L70 84 50 59v39zm125 0l-30-33h20V30h20v35h20z"/>',
        },
      }.merge(
        # The glyph of each feature kind (Feature#short_kind) in a module's feature
        # list, as "kind-js" etc. Outlines after Lucide (ISC, lucide.dev), all in one
        # stroke weight: Font Awesome 4 has no braces or cookie, and its solid glyphs
        # would not match the outlines. Some are scaled down so they look as large as
        # the rest, with a thicker stroke so they keep its weight.
        #
        # "book" and "package" are drawn the same way and sit beside the kinds: a guide
        # page and a module or class in the search results (_search_dialog.html.erb), a
        # guide page in the sidebar (menu.coffee), a module on the /api hub.
        {
          'html' => '<polyline points="17.5 17 22.5 12 17.5 7"/><polyline points="6.5 7 1.5 12 6.5 17"/><line x1="14.5" y1="4" x2="9.5" y2="20"/>',
          'attr' => '<polyline points="17.5 17 22.5 12 17.5 7"/><polyline points="6.5 7 1.5 12 6.5 17"/><line x1="14.5" y1="4" x2="9.5" y2="20"/>',
          'css' => '<path d="m9.06 11.9 8.07-8.06a2.85 2.85 0 1 1 4.03 4.03l-8.06 8.08"/><path d="M7.07 14.94c-1.66 0-3 1.35-3 3.02 0 1.33-2.5 1.52-2 2.02 1.08 1.1 2.49 2.02 4 2.02 2.2 0 4-1.8 4-4.04a3.01 3.01 0 0 0-3-3.02z"/>',
          'target' => '<g transform="translate(12 12) scale(0.86) translate(-12 -12)" stroke-width="2.33"><circle cx="12" cy="12" r="8"/><line x1="22" y1="12" x2="17" y2="12"/><line x1="7" y1="12" x2="2" y2="12"/><line x1="12" y1="7" x2="12" y2="2"/><line x1="12" y1="22" x2="12" y2="17"/><path d="M12 12h.01"/></g>',
          'js' => '<path d="M9 5H7.5a2.5 2 0 0 0-2.5 2v3a2.5 2 0 0 1-2.5 2 2.5 2 0 0 1 2.5 2v3a2.5 2 0 0 0 2.5 2H9"/><path d="M15 19h1.5a2.5 2 0 0 0 2.5-2v-3a2.5 2 0 0 1 2.5-2 2.5 2 0 0 1-2.5-2V7a2.5 2 0 0 0-2.5-2H15"/>',
          'config' => '<g transform="translate(12 12) scale(0.84) translate(-12 -12)" stroke-width="2.38"><path d="M12.22 2h-.44a2 2 0 0 0-2 2v.18a2 2 0 0 1-1 1.73l-.43.25a2 2 0 0 1-2 0l-.15-.08a2 2 0 0 0-2.73.73l-.22.38a2 2 0 0 0 .73 2.73l.15.1a2 2 0 0 1 1 1.72v.51a2 2 0 0 1-1 1.74l-.15.09a2 2 0 0 0-.73 2.73l.22.38a2 2 0 0 0 2.73.73l.15-.08a2 2 0 0 1 2 0l.43.25a2 2 0 0 1 1 1.73V20a2 2 0 0 0 2 2h.44a2 2 0 0 0 2-2v-.18a2 2 0 0 1 1-1.73l.43-.25a2 2 0 0 1 2 0l.15.08a2 2 0 0 0 2.73-.73l.22-.39a2 2 0 0 0-.73-2.73l-.15-.08a2 2 0 0 1-1-1.74v-.5a2 2 0 0 1 1-1.74l.15-.09a2 2 0 0 0 .73-2.73l-.22-.38a2 2 0 0 0-2.73-.73l-.15.08a2 2 0 0 1-2 0l-.43-.25a2 2 0 0 1-1-1.73V4a2 2 0 0 0-2-2z"/><circle cx="12" cy="12" r="2.5"/></g>',
          'event' => '<g transform="translate(12 12) scale(0.9) translate(-12 -12)" stroke-width="2.22"><path d="M6 8a6 6 0 0 1 12 0c0 7 3 9 3 9H3s3-2 3-9"/><path d="M10.3 21a1.94 1.94 0 0 0 3.4 0"/></g>',
          'header' => '<path d="M8 3 4 7l4 4"/><path d="M4 7h16"/><path d="m16 21 4-4-4-4"/><path d="M20 17H4"/>',
          'cookie' => '<g transform="translate(12 12) scale(0.88) translate(-12 -12)" stroke-width="2.27"><path d="M12 2a10 10 0 1 0 10 10 4 4 0 0 1-5-5 4 4 0 0 1-5-5"/><path d="M8.5 8.5v.01"/><path d="M16 15.5v.01"/><path d="M12 12v.01"/><path d="M11 17v.01"/><path d="M7 14v.01"/></g>',
          'package' => '<path d="M21 8l-9-5-9 5v8l9 5 9-5z"/><path d="M3 8l9 5 9-5"/><path d="M12 13v8"/>',
          'book' => '<path d="M12 7v14"/><path d="M3 18a1 1 0 0 1-1-1V4a1 1 0 0 1 1-1h5a4 4 0 0 1 4 4 4 4 0 0 1 4-4h5a1 1 0 0 1 1 1v13a1 1 0 0 1-1 1h-6a3 3 0 0 0-3 3 3 3 0 0 0-3-3z"/>',
        }.to_h { |kind, paths|
          [%w[package book].include?(kind) ? kind : "kind-#{kind}", {
            view_box: '0 0 24 24',
            body: %(<g fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">#{paths}</g>),
          }]
        }
      ).freeze

      def self.html(name, label: nil, class: nil)
        extra_class = binding.local_variable_get(:class)
        aria = if label
          label = CGI.escapeHTML(label)
          %(role="img" aria-label="#{label}" title="#{label}")
        else
          'aria-hidden="true"'
        end

        if (svg = SVG[name])
          classes = ['icon', "-#{name}", extra_class].compact.join(' ')
          # An SVG shows a <title> child as its tooltip, not a title attribute.
          tooltip = label ? "<title>#{label}</title>" : ''
          %(<svg class="#{classes}" viewBox="#{svg[:view_box]}" #{aria}>#{tooltip}#{svg[:body]}</svg>)
        else
          classes = ['fa', "fa-#{name}", extra_class].compact.join(' ')
          %(<i class="#{classes}" #{aria}></i>)
        end
      end
    end
  end
end
