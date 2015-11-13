module Upjs
  module Guide
    class Repository
      include Logger

      def initialize(input_path)
        @input_path = input_path
        reload
      end

      def reload
        @klasses = []
        @feature_index = nil
        @changelog = nil
        parse
        self
      end

      def changelog
        @changelog ||= begin
          path = File.join(@input_path, 'CHANGELOG.md')
          File.read(path)
        end
      end

      def all_features
        @feature_index.all
      end

      def all_feature_guide_ids
        # We have multiple selectors called [up-close]
        @feature_index.guide_ids
      end

      # Since we (e.g.) have multiple selectors called [up-close],
      # we display all of them on the same guide page.
      def features_for_guide_id(guide_id)
        @feature_index.find_guide_id(guide_id)
      end

      def version
        require File.join(@input_path, 'lib/upjs/rails/version')
        Upjs::Rails::VERSION
      end

      attr_reader :klasses

      attr_reader :feature_index

      def klass_for_name(name)
        klasses.detect { |klass| klass.name == name } or raise "No such Klass: #{name}"
      end

      def source_paths
        File.directory?(@input_path) or raise "Input path not found: #{@input_path}"
        log("Input pattern", File.join(@input_path, "**/*.coffee"))
        Dir[File.join(@input_path, "**/*.coffee")]
      end

      def parse
        parser = Parser.new(self)
        log("Source paths", source_paths)
        source_paths.each do |source_path|
          parser.parse(source_path)
        end
        @feature_index = Feature::Index.new(klasses.collect(&:features).flatten)
      end

    end
  end
end
