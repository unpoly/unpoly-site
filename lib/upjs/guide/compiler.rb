# TODO: Get rid of this class now that we output HTML using Middleman
module Upjs
  module Guide

    class Compiler
      include Logger

      def input_folder
        File.join(File.dirname(__FILE__), '../lib/assets/javascripts')
      end

      def output_folder
        File.join(File.dirname(__FILE__), '../doc/guide')
      end

      def run
        repository = Repository.new(input_folder)
        log("Got repository", repository)
        repository.klasses.each do |klass|
          output_path = File.join(output_folder, klass.guide_filename('.md'))
          log("Writing to output path", output_path)
          File.open(output_path, "w") do |file|
            file.write klass.guide_markdown
            klass.js_functions.each do |js_function|
              file.write "\n"
              file.write "JS Function: #{js_function.name}"
              file.write "\n"
            end
            klass.ujs_functions.each do |ujs_function|
              file.write "\n"
              file.write "UJS Function: #{ujs_function.name}"
              file.write "\n"
            end
          end
        end
      end

    end
  end
end
