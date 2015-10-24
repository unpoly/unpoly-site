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

      def all_functions
        klasses.collect(&:functions).flatten
      end

      def all_function_guide_ids
        # We have multiple functions called [up-close]
        all_functions.collect(&:guide_id).uniq
      end

      def functions_for_guide_id(guide_id)
        all_functions.select { |function|
          function.guide_id == guide_id
        }
      end

      def version
        require File.join(@input_path, 'lib/upjs/rails/version')
        Upjs::Rails::VERSION
      end

      attr_reader :klasses

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
      end

    end
  end
end
