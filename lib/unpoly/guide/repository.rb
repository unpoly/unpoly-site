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
        up.browser
        up.log
      ].freeze

      def initialize(input_path)
        @path = input_path
        extend(MonitorMixin)
        reload
      end

      attr_reader :path

      def reload
        # puts "Reloading Repository!"
        synchronize do
          log "reload()"
          @interfaces = []
          @feature_index = nil
          @changelog = nil
          @promoted_interfaces = nil
          parse()
          self
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
              interface_for_name!(interface_name)
            end
          end
        end
      end

      def feature_index
        synchronize do
          @feature_index
        end
      end

      def all_features
        feature_index.all
      end

      def all_feature_guide_ids
        # We have multiple selectors called [up-close]
        feature_index.guide_ids
      end

      def feature_for_guide_id(guide_id)
        features_for_guide_id(guide_id).first
      end

      # Since we (e.g.) have multiple selectors called [up-close],
      # we display all of them on the same guide page.
      def features_for_guide_id(guide_id)
        feature_index.find_guide_id(guide_id)
      end

      def guide_id_exists?(guide_id)
        feature_index.guide_id_exists?(guide_id) || interface_with_guide_id_exists?(guide_id)
      end

      def version
        synchronize do
          require File.join(path, 'lib/unpoly/rails/version')
          Unpoly::Rails::VERSION
        end
      end

      def short_version
        # version.sub(/-.+$/, '')
        version.scan(/^\d+\.\d+/)[0]
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
          @interfaces
        end
      end

      def merge_interface(new_interface)
        synchronize do
          if (existing_interface = interface_for_name(new_interface.name))
            existing_interface.merge!(new_interface)
            return existing_interface
          else
            @interfaces << new_interface
            return new_interface
          end
        end
      end

      def interface_for_name(name)
        interfaces.detect { |interface| interface.name == name }
      end

      def interface_for_name!(name)
        interface_for_name(name) or raise UnknownInterface, "No such interface: #{name}"
      end

      def feature_for_name(name)
        features.detect { |feature| feature.name == name }
      end

      def feature_for_name!(name)
        feature_for_name(name) or raise UnknownFeature, "No such feature: #{name}"
      end

      def find_by_name(name)
        interface_for_name(name) || feature_for_name(name)
      end

      def find_by_name!(name)
        interface_for_name(name) || feature_for_name(name) or raise Unknown, "No such interface or feature: #{name}"
      end

      # def interface_for_guide_id(guide_id)
      #   interfaces.detect { |interface| interface.guide_id == guide_id } or raise UnknownInterface, "No such Interface: #{guide_id}"
      # end

      def interface_with_guide_id_exists?(guide_id)
        !!interfaces.detect { |interface| interface.guide_id == guide_id }
      end

      def inspect
        "#<#{self.class.name} interface_names=#{interfaces.collect(&:name)}>"
      end

      def features
        interfaces.flat_map(&:features)
      end

      private

      def parse
        log "parse()"
        parser = Parser.new(self)
        paths = source_paths
        log("Source paths", paths)
        paths.each do |source_path|
          parser.parse(source_path)
        end
        @feature_index = Feature::Index.new(features)
      end

      def source_paths
        source_paths_for_root(File.join(path, "lib")) + source_paths_for_root('spec/fixtures')
      end

      def source_paths_for_root(root)
        File.directory?(root) or raise "Input path not found: #{root}"
        pattern = File.join(root, "**/*{.coffee,.coffee.erb,.js,.js.erb}")
        log("Input pattern", pattern)
        Dir[pattern]
      end

    end
  end
end
