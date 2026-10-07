module Unpoly
  module Guide
    # An icon from the Font Awesome webfont, for templates (through the `icon` helper in
    # config.rb) and for HTML built in lib/.
    #
    # An icon is decorative by default: screen readers and the Markdown twins skip it
    # (aria-hidden). An icon that says something no text next to it says gets a label,
    # which makes it an image with an accessible name. The Markdown twin writes such an
    # icon as "(label)".
    module Icon
      def self.html(name, label: nil, class: nil)
        classes = ['fa', "fa-#{name}", binding.local_variable_get(:class)].compact.join(' ')

        if label
          label = CGI.escapeHTML(label)
          %(<i class="#{classes}" role="img" aria-label="#{label}" title="#{label}"></i>)
        else
          %(<i class="#{classes}" aria-hidden="true"></i>)
        end
      end
    end
  end
end
