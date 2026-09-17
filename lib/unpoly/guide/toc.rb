require 'yaml'

module Unpoly
  module Guide
    # The site structure, parsed from `src/unpoly/pages/toc.yml` in the Unpoly repo.
    #
    # The manifest owns relations only: which pages form a topic, in which order, and
    # which interfaces the API reference lists. Everything a single document knows about
    # itself (title, slug, menu title, visibility) comes from its directives.
    #
    # Both topic types answer the same questions (#title, #children, #start_page), so
    # templates never ask which type they are looking at.
    class Toc
      class Invalid < Error; end

      PATH = 'src/unpoly/pages/toc.yml'

      AREA_KEYS = %w[title reading topics].freeze
      READINGS = %w[linear lookup].freeze

      def self.load(repository)
        path = File.join(repository.path, PATH)
        File.file?(path) or raise Invalid, "Missing table of contents: #{path}"
        new(YAML.safe_load(File.read(path)), repository, path)
      end

      def initialize(data, repository, path = PATH)
        @repository = repository
        @path = path
        @areas = build_areas(data)
        validate!
      end

      attr_reader :areas, :repository, :path

      def learn
        area('learn')
      end

      def api
        area('api')
      end

      def area(key)
        areas.detect { |area| area.key == key }
      end

      # The area a documentable belongs to, or nil when it is not part of the manifest
      # (e.g. a feature of a module, which is reached through its module).
      def area_of(documentable)
        areas.detect { |area| area.includes?(documentable) }
      end

      def topic_of(documentable)
        areas.lazy.filter_map { |area| area.topic_of(documentable) }.first
      end

      # The area a document is presented in. Everything the manifest does not list
      # explicitly (a module's features, a class, a class's methods) is reference material.
      def area_for(documentable)
        area_of(documentable) || api
      end

      # All pages of all linear areas, in reading order.
      def reading_order
        areas.select(&:linear?).flat_map(&:pages)
      end

      def previous_page(page)
        neighbors(page).first
      end

      def next_page(page)
        neighbors(page).last
      end

      private

      def neighbors(page)
        order = reading_order
        index = order.index(page) or return [nil, nil]
        [(index > 0 ? order[index - 1] : nil), order[index + 1]]
      end

      def build_areas(data)
        data.is_a?(Hash) or raise Invalid, "#{path}: expected a mapping of areas at the top level"
        unexpected = data.keys - %w[learn api]
        unexpected.empty? or raise Invalid, "#{path}: unknown area(s) #{unexpected.join(', ')}"
        %w[learn api].map do |key|
          data[key] or raise Invalid, "#{path}: missing area '#{key}'"
          Area.new(key, data[key], self)
        end
      end

      # Everything that is wrong is reported at once, so a stale manifest takes one
      # run to fix rather than one run per mistake.
      def validate!
        problems = page_problems + module_problems + page_location_problems
        return if problems.empty?

        raise Invalid, ([path] + problems).join("\n  ")
      end

      def page_problems
        compare(
          listed: areas.flat_map(&:page_slugs),
          documented: repository.documented_page_slugs,
          noun: 'page(s)',
          missing_hint: 'not listed',
          unknown_hint: 'without an @page directive'
        )
      end

      def module_problems
        compare(
          listed: api.module_names,
          documented: repository.documented_module_names,
          noun: 'module(s)',
          missing_hint: "not listed in 'api'",
          unknown_hint: 'without a published @module'
        )
      end

      # A page's file path must mirror its slug (@page start/forms is written in
      # pages/start/forms.md), so a page is always found where its URL says.
      def page_location_problems
        repository.documented_pages.filter_map do |page|
          expected = "src/unpoly/pages/#{page.guide_id}.md"
          unless page.text_source&.path.to_s.end_with?(expected)
            "page '#{page.guide_id}' must live in #{expected} (found #{page.text_source&.path})"
          end
        end
      end

      def compare(listed:, documented:, noun:, missing_hint:, unknown_hint:)
        problems = []
        duplicates = listed.tally.select { |_entry, count| count > 1 }.keys
        problems << "#{noun} listed more than once: #{duplicates.join(', ')}" if duplicates.any?

        missing = documented - listed
        problems << "#{noun} #{missing_hint}: #{missing.join(', ')}" if missing.any?

        unknown = listed - documented
        problems << "#{noun} #{unknown_hint}: #{unknown.join(', ')}" if unknown.any?
        problems
      end

      # One of the site's two halves.
      class Area
        def initialize(key, data, toc)
          @key = key
          @toc = toc
          data.is_a?(Hash) or raise Invalid, "#{toc.path}: area '#{key}' must be a mapping"
          Toc.check_keys!(data, AREA_KEYS, AREA_KEYS, "#{toc.path}: area '#{key}'")

          @title = data['title']
          @reading = data['reading']
          READINGS.include?(@reading) or
            raise Invalid, "#{toc.path}: area '#{key}' has unknown reading '#{@reading}' (expected #{READINGS.join(' or ')})"

          topics = data['topics']
          topics.is_a?(Array) or raise Invalid, "#{toc.path}: area '#{key}' must list its topics"
          @topics = topics.map { |topic| Topic.build(topic, self) }
        end

        attr_reader :key, :title, :reading, :topics, :toc

        delegate :repository, to: :toc

        def linear?
          reading == 'linear'
        end

        def path
          "/#{key}"
        end

        # Pages in this area, in manifest order.
        def pages
          topics.flat_map(&:pages)
        end

        def page_slugs
          topics.flat_map(&:page_slugs)
        end

        def module_names
          topics.filter_map { |topic| topic.module_name if topic.respond_to?(:module_name) }
        end

        def includes?(documentable)
          !!topic_of(documentable)
        end

        def topic_of(documentable)
          topics.detect { |topic| topic.includes?(documentable) }
        end

        def menu_path
          "#{path}/menu"
        end
      end

      # A topic in the navigation tree. Subclasses differ in where their children come
      # from, not in what callers may ask them.
      class Topic
        TYPES = {}

        def self.build(data, area)
          data.is_a?(Hash) or raise Invalid, "#{area.toc.path}: each topic must be a mapping"
          type = data['type'] or raise Invalid, "#{area.toc.path}: topic is missing a 'type' key"
          klass = TYPES[type] or
            raise Invalid, "#{area.toc.path}: unknown topic type '#{type}' (expected #{TYPES.keys.join(' or ')})"
          klass.new(data, area)
        end

        def initialize(data, area)
          @area = area
          @data = data
        end

        attr_reader :area

        delegate :repository, :toc, to: :area

        def pages
          []
        end

        def page_slugs
          []
        end

        def includes?(documentable)
          start_page == documentable || children.include?(documentable)
        end

        # What the templates render.
        def menu_title
          title
        end

        def menu_path
          start_page&.guide_path
        end

        def menu_children
          children
        end

        def menu_modifiers
          []
        end

        def menu_tags
          []
        end

        def menu_experimental?
          false
        end

        def summary_markdown
          start_page&.summary_markdown
        end
      end

      # A hand-curated list of guide pages, e.g. a Learn chapter.
      class PageGroup < Topic
        KEYS = %w[type title pages start].freeze
        REQUIRED_KEYS = %w[type title pages].freeze

        TYPES['page-group'] = self

        def initialize(data, area)
          super
          Toc.check_keys!(data, KEYS, REQUIRED_KEYS, "#{area.toc.path}: page group '#{data['title']}'")
          @title = data['title']
          @page_slugs = Array(data['pages'])
          @page_slugs.present? or raise Invalid, "#{area.toc.path}: page group '#{title}' lists no pages"
          @start = data.fetch('start', @page_slugs.first)
          @start == 'none' || @page_slugs.include?(@start) or
            raise Invalid, "#{area.toc.path}: page group '#{title}' starts at '#{@start}', which is not one of its pages"
        end

        attr_reader :title, :page_slugs

        def pages
          page_slugs.map { |slug| repository.find_page!(slug) }
        end

        def start_page
          return nil if @start == 'none'
          repository.find_page!(@start)
        end

        # The start page is reached by clicking the topic itself, so it is not repeated
        # below it.
        def children
          pages - [start_page].compact
        end

      end

      # A module of the Unpoly source, with its features grouped by kind.
      class ModuleTopic < Topic
        KEYS = %w[type module].freeze

        TYPES['module'] = self

        # Features of a module, grouped for the reference tree. Order matters.
        FEATURE_GROUPS = [
          ['HTML',       [:selector]],
          ['Events',     [:event]],
          ['JavaScript', [:function, :property, :class, :constructor]],
          ['HTTP',       [:header, :cookie]],
        ].freeze

        def initialize(data, area)
          super
          Toc.check_keys!(data, KEYS, KEYS, "#{area.toc.path}: module topic")
          @module_name = data['module']
        end

        attr_reader :module_name

        def interface
          repository.find_module!(module_name)
        end

        # The sidebar and the /api hub identify a module by its JavaScript name
        # (`up.link`), not its prose title ("Linking and following"). The prose title
        # stays the headline of the module's own page.
        def title
          interface.name
        end

        def start_page
          interface
        end

        def children
          FEATURE_GROUPS.filter_map do |title, kinds|
            members = interface.menu_children.select { |feature| feature.kind?(*kinds) }.sort
            Group.new(title, members) if members.present?
          end
        end

        def includes?(documentable)
          documentable == interface || interface.menu_children.include?(documentable)
        end

        def summary_markdown
          interface.summary_markdown
        end

        def menu_modifiers
          super + ['interface']
        end
      end

      # A label in the navigation tree that groups siblings but has no page of its own.
      class Group
        def initialize(title, children)
          @title = title
          @children = children
        end

        attr_reader :title, :children

        alias menu_title title
        alias menu_children children

        def menu_path
          nil
        end

        def menu_modifiers
          ['group']
        end

        def menu_tags
          []
        end

        def menu_experimental?
          false
        end
      end

      def self.check_keys!(data, allowed, required, context)
        unknown = data.keys - allowed
        unknown.empty? or raise Invalid, "#{context}: unknown key(s) #{unknown.join(', ')}"
        missing = required - data.keys
        missing.empty? or raise Invalid, "#{context}: missing key(s) #{missing.join(', ')}"
      end
    end
  end
end
