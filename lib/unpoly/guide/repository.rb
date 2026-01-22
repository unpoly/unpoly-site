require 'monitor'

module Unpoly
  module Guide
    class Repository
      include Logger

      PROMOTED_INTERFACE_NAMES = %w[
        up.link
        up.script
        up.form
        up.layer
        up.fragment
        up.radio
        up.motion
        up.status
        up.network
        up.event
        up.protocol
        up.element
        up.viewport
        up.history
        up.util
        up.framework
        up.log
      ].freeze

      BUILTIN_TYPE_URLS = {
        # 'string' => 'https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/String',
        # 'undefined' => 'https://developer.mozilla.org/en-US/docs/Glossary/undefined',
        # 'null' => 'https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/null',
        # 'number' => 'https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Number',
        # 'boolean' => 'https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Boolean',
        'Array' => 'https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Array',
        'Object' => 'https://developer.mozilla.org/en-US/docs/Web/JavaScript/Guide/Working_with_Objects',
        'Promise' => 'https://developer.mozilla.org/en-US/docs/Web/JavaScript/Guide/Using_promises',
        'FormData' => 'https://developer.mozilla.org/en-US/docs/Web/API/FormData',
        'URL' => 'https://developer.mozilla.org/en-US/docs/Web/API/URL',
        'Event' => 'https://developer.mozilla.org/en-US/docs/Web/API/Event',
        'Error' => 'https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Error',
        'XMLHttpRequest' => 'https://developer.mozilla.org/en-US/docs/Web/API/XMLHttpRequest',
        'NodeList' => 'https://developer.mozilla.org/en-US/docs/Web/API/NodeList',
        'HTMLCollection' => 'https://developer.mozilla.org/en-US/docs/Web/API/HTMLCollection',
        'Element' => 'https://developer.mozilla.org/de/docs/Web/API/Element',
        'Node' => 'https://developer.mozilla.org/de/docs/Web/API/Node',
        'Text' => 'https://developer.mozilla.org/de/docs/Web/API/Text',
        'Comment' => 'https://developer.mozilla.org/de/docs/Web/API/Comment',
        'CDATASection' => 'https://developer.mozilla.org/de/docs/Web/API/CDATASection',
        'jQuery' => 'https://learn.jquery.com/using-jquery-core/jquery-object/',
      }.freeze


      def initialize(input_path)
        @path = input_path
        extend(MonitorMixin)
        reload
      end

      attr_reader :path

      def ensure_fresh!
        reload unless @fresh
      end

      def reload
        # puts "Reloading Repository!"
        synchronize do
          log "reload()"
          @interfaces = []
          @changelog = nil
          @promoted_interfaces = nil
          unindex
          parse
          @fresh = true
        end
      end

      def changelog
        synchronize do
          @changelog ||= Changelog.new(path)
        end
      end

      delegate :releases, :versions, :release_for_version, to: :changelog

      def github_url
        'https://github.com/unpoly/unpoly'
      end

      def promoted_interfaces
        synchronize do
          @promoted_interfaces ||= begin
            PROMOTED_INTERFACE_NAMES.map do |interface_name|
              find_by_name!(interface_name)
            end
          end
        end
      end

      def version
        synchronize do
          package_json_path = File.join(path, 'package.json')
          package_json_content = File.read(package_json_path)
          package_info = JSON.parse(package_json_content)
          package_info['version'].presence or raise Error, "Cannot parse { version } from #{package_json_path}"
        end
      end

      def stable_version
        version.sub(/-.+$/, '')
      end

      def short_version
        # version.sub(/-.+$/, '')
        version.scan(/^\d+\.\d+/)[0]
      end

      def pre_release?
        version =~ /rc|beta|pre|alpha/
      end

      def gem_version
        # RubyGems automatically convert 2.0.0-rc9 to 2.0.0.pre.rc9
        version.sub('-', '.pre.')
      end

      def git_version_tag
        "v#{version}"
      end

      def git_revision
        synchronize do
          revision = nil
          Dir.chdir path do
            revision = `git rev-parse HEAD`
          end
          revision
        end
      end

      def interfaces
        synchronize do
          @interfaces ||= []
        end
      end

      def features
        interfaces.flat_map(&:features)
      end

      def documentables
        interfaces + features
      end

      def merge_interface(new_interface)
        synchronize do
          if (existing_interface = find_by_name(new_interface.name))
            existing_interface.merge!(new_interface)
            return existing_interface
          else
            interfaces << new_interface
            unindex
            return new_interface
          end
        end
      end

      def find_by_name(name)
        documentables_by_name[name]
      end

      def find_by_name_smart(name)
        is_up_attr_without_tagname = name.start_with?('[up-')
        is_up_class_without_tagname = name.start_with?('.up-')

        find_by_name(name) || (is_up_attr_without_tagname && (find_by_name("a" + name) || find_by_name("form" + name))) || (is_up_class_without_tagname && (find_by_name("a" + name) || find_by_name("form" + name)))
      end

      def find_by_name!(name)
        find_by_name(name) or raise Unknown, "No Documentable with name '#{name}'"
      end

      def find_by_guide_id(guide_id)
        documentables_by_guide_id[guide_id]
      end

      def find_by_guide_id!(guide_id)
        find_by_guide_id(guide_id) or raise Unknown, "No Documentable with guide_id '#{guide_id}'"
      end

      def guide_id_exists?(guide_id)
        !!find_by_guide_id(guide_id)
      end

      def name_exists?(name)
        !!find_by_name(name)
      end

      def all_by_explicit_parent_name(explicit_parent_name)
        documentables_by_explicit_parent_name[explicit_parent_name] || []
      end

      def inspect
        "#<#{self.class.name} interface_names=#{interfaces.collect(&:name)}>"
      end

      def code_to_location(code)
        code = code.strip

        # For some code snippets there cannot be a guide symbol
        if code.include?("\n") || code =~ /^["']/ || code.include?(' = ') || code.starts_with?('{')
          return
        end

        name = code

        # # Turn `up.module.config.foo = bar` to just `up.module.config.foo`
        # if guide_id =~ /^(.+?)\s*=(.+?)$/
        #   guide_id = $1
        # end

        name = name.sub('#', '.prototype.')

        name = name.sub(/^([A-Za-z.$]{3,})\([^)]*\)$/, '\1')

        # guide_id = guide_id.sub(/^([A-Za-z.]{3,})\(([A-Za-z]+(,\s*)?)*\)$/, '\1()')

        hash = nil
        if name =~ /^(up\.[.\w]+?\.config)\.([.\w]+?)$/
          name = $1
          hash = "config.#{$2}"
        end

        documentable = find_by_name_smart(name)
        builtin_url = BUILTIN_TYPE_URLS[name]

        if !documentable || !documentable.guide_page?
          if builtin_url
            return {
              path: builtin_url,
              hash: hash,
              url: builtin_url,
              full_path: builtin_url,
              full_url: builtin_url,
            }
          else
            # We either don't know this code or it is internal.
            return nil
          end
        end

        if hash && !documentable.params.any? { |param| param.name == hash }
          # We cannot links to a removed property like up.network.config.expireAge.
          # Linking to an unknown hash will blow up html-proofer.
          return
        end

        {
          path:      documentable.guide_path,
          hash:      hash,
          url:       documentable.guide_url,
          full_path: documentable.guide_path(hash: hash),
          full_url:  documentable.guide_url(hash: hash),
        }
      end

      def published_js_props
        # documentables.select(&:published?).flat_map(&:published_properties)
        js_props = []
        interfaces.select(&:code?).each do |interface|
          js_props += interface.name.split('.')
          interface.features.select(&:code?).select(&:published?).each do |feature|
            if feature.property? || feature.function?
              js_props += feature.name.split('.')
              feature.params.select(&:published?).each do |param|
                param_path = param.name.split('.')
                js_props += param_path.from(1)
              end
            end
          end
        end

        js_props.select(&:present?).uniq.sort
      end

      def migrate_redirects
        htaccess_path = File.join(path, 'src', 'unpoly-migrate', '.htaccess')
        File.read(htaccess_path)
      end

      private

      def unindex
        @documentables_by_guide_id = nil
        @documentables_by_name = nil
        @documentables_by_explicit_parent_name = nil
      end

      def documentables_by_guide_id
        @documentables_by_guide_id ||= documentables.index_by(&:guide_id)
      end

      def documentables_by_name
        @documentables_by_name ||= documentables.index_by(&:index_name)
      end

      def documentables_by_explicit_parent_name
        @documentables_by_explicit_parent_name ||= documentables.group_by(&:explicit_parent_name)
      end

      def parse
        log "parse()"
        parser = Parser.new(self)
        paths = source_paths
        log("Source paths", paths)
        parser.parse_all(source_paths)
      end

      def source_paths
        source_paths_for_root(File.join(path, "src")) + source_paths_for_root('spec/fixtures/parser')
      end

      def source_paths_for_root(root)
        File.directory?(root) or raise "Input path is not a directory: #{root}"
        pattern = File.join(root, "**/*{.coffee,.coffee.erb,.js,.js.erb,.md}")
        log("Input pattern", pattern)
        Dir[pattern]
      end

    end
  end
end
