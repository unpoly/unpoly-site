module Unpoly
  module Guide
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
        # The Markdown mark by Dustin Curtis (CC0, github.com/dcurtis/markdown-mark).
        'markdown' => {
          view_box: '0 0 208 128',
          body: '<rect width="198" height="118" x="5" y="5" ry="10" fill="none" stroke="currentColor" stroke-width="10"/>' \
                '<path fill="currentColor" d="M30 98V30h20l20 25 20-25h20v68H90V59L70 84 50 59v39zm125 0l-30-33h20V30h20v35h20z"/>',
        },
      }.freeze

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
