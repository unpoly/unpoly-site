module Unpoly
  module Guide
    # Site partials that a guide page embeds in its Markdown, so one source serves the
    # landing page (which renders the partial directly) and the guides.
    #
    # A guide asks for one with an empty element, plain HTML in the Markdown like every
    # other one-off construct:
    #
    #     <div embed="fragment-updates-diagram"></div>
    #
    # Kramdown passes that element through untouched; after rendering, Embeds.splice
    # replaces it with the partial. An unknown name fails the render, so a misspelled
    # embed never ships as an empty element.
    class Embeds
      class Unknown < Error; end

      PARTIALS = {
        'fragment-updates-diagram' => 'fragment_updates_diagram',
      }.freeze

      PATTERN = %r{<div embed="([^"]*)">\s*</div>}

      # Replaces every embed in the HTML with what the block renders for its partial.
      def self.splice(html, source: nil)
        html.gsub(PATTERN) do
          name = Regexp.last_match(1)
          partial = PARTIALS[name] or
            raise Unknown, "Unknown embed #{name.inspect}#{" (in #{source})" if source} (known: #{PARTIALS.keys.join(', ')})"
          yield(partial)
        end
      end
    end
  end
end
