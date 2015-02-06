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
        parse
        self
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
