require 'json'

module Unpoly
  module Guide
    # The symbol sidecar the search popup matches names against.
    #
    # Pagefind indexes prose. It is very good at "how do I keep a form's state" and
    # useless at "up-watch-delay", because a symbol is a name, not a sentence: readers
    # type it exactly, expect the exact thing back, and expect it first. So the popup
    # matches a generated list of names before it looks at any full-text hit.
    #
    # What is in here is what a reader types as a name:
    #
    # - every documented feature (selectors, events, functions, properties, headers)
    # - modules and classes, because `up.link` is a name someone types, while the page
    #   behind it is titled "Linking to fragments" and full-text search cannot find it
    # - the params that the menu already treats as nodes of their own: a selector's
    #   attributes and a config object's keys
    #
    # Guide pages are deliberately absent. They have prose, Pagefind finds them well,
    # and listing them here would put the same page in the popup twice.
    class SymbolIndex
      # The wire format is positional to keep the payload small. Trailing empty fields
      # are dropped, so a selector costs three entries and a function costs four.
      #
      #   [name, path, kind, title, owner, deprecated]
      #
      # name       what the reader types
      # path       where the symbol lives (with an anchor, for a param)
      # kind       the badge: JS, HTML, CSS, EVENT, CONFIG, HEADER, COOKIE
      # title      the display form, when it differs from the name (a feature's signature,
      #            a module's page title)
      # owner      the feature a param belongs to, e.g. "[up-watch]"
      # deprecated 1 when the symbol is deprecated, so it can be ranked last
      VERSION = 1

      def initialize(guide)
        @guide = guide
      end

      attr_reader :guide

      def to_json(*args)
        { 'version' => VERSION, 'symbols' => symbols }.to_json(*args)
      end

      def symbols
        (feature_entries + interface_entries + param_entries).map { |entry| trim(entry) }
      end

      private

      def feature_entries
        guide.features.select(&:guide_page?).map do |feature|
          # The full signature, as the feature's page headlines it: up.follow(link, [options]).
          title = feature.signature
          [
            feature.name,
            feature.guide_path,
            feature.short_kind,
            (title if title != feature.name),
            nil,
            (1 if feature.deprecated?),
          ]
        end
      end

      # Modules and classes only. A module's page is titled after what it is for, so its
      # name would otherwise be unfindable.
      def interface_entries
        guide.interfaces.select { |interface| interface.guide_page? && !interface.page? }.map do |interface|
          [
            interface.name,
            interface.guide_path,
            'API',
            (interface.title if interface.title != interface.name),
            nil,
            (1 if interface.deprecated?),
          ]
        end
      end

      # A param wears its owner's badge: an attribute of a selector is HTML, a key of a
      # config object is CONFIG. The owner travels along so the row can say where it
      # belongs — "up-watch-delay" means little without "[up-watch]" beside it.
      def param_entries
        guide.features.select(&:guide_page?).flat_map do |feature|
          params = feature.params.select(&:menu_node?)
          # A selector's main attribute carries the selector's own name: [up-watch] has an
          # [up-watch] attribute. Listing it repeats the feature one row below itself and
          # points at an anchor on the page that row already links to.
          params = params.reject { |param| param.menu_title == feature.title }

          params.map do |param|
            [
              param.menu_title,
              param.guide_path,
              feature.short_kind,
              nil,
              feature.title,
              (1 if param.visibility == 'deprecated' || feature.deprecated?),
            ]
          end
        end
      end

      def trim(entry)
        entry = entry.dup
        entry.pop while entry.size > 3 && entry.last.nil?
        entry.map { |value| value.nil? ? 0 : value }
      end

    end
  end
end
