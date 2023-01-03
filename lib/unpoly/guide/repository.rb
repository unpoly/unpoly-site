require 'monitor'

module Unpoly
  module Guide
    class Repository
      include Logger

      PROMOTED_INTERFACE_NAMES = %w[
        up.link
        up.syntax
        up.form
        up.layer
        up.fragment
        up.radio
        up.motion
        up.feedback
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

        guide_id = code

        # # Turn `up.module.config.foo = bar` to just `up.module.config.foo`
        # if guide_id =~ /^(.+?)\s*=(.+?)$/
        #   guide_id = $1
        # end

        guide_id = guide_id.sub('#', '.prototype.')

        # guide_id = guide_id.sub(/^([A-Za-z.]{3,})\([`)]*\)$/, '\1')
        # guide_id = guide_id.sub(/^([A-Za-z.]{3,})\(([A-Za-z]+(,\s*)?)*\)$/, '\1()')

        hash = nil
        if guide_id =~ /^(up\.[.\w]+?\.config)\.([.\w]+?)$/
          guide_id = $1
          hash = "config.#{$2}"
        end

        guide_id = Util.slugify(guide_id)
        if guide_id_exists?(guide_id)
          path = "/#{guide_id}"
          full_path = [path, hash].compact.join('#')
          full_url = "https://unpoly.com#{path}"

          {
            path: path,
            hash: hash,
            full_path: full_path,
            full_url: full_url
          }
        end
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
        paths.each do |source_path|
          parser.parse(source_path)
        end
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
