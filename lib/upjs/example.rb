require 'active_support/core_ext/enumerable'

module Upjs
  class Example
    include Memoizer

    class Asset

      def initialize(example, relative_path)
        @example = example
        @relative_path = relative_path
      end

      attr_reader :example

      def path
        "/#{@relative_path}"
      end

      def name
        File.basename(@relative_path)
      end

      def text
        File.read(@relative_path)
      end

      def base
        "/#{File.dirname(@relative_path)}/"
      end

    end

    def initialize(folder)
      @folder = folder
    end

    def name
      File.basename(@folder)
    end

    def stylesheets
      assets_with_extension('css')
    end

    def javascripts
      assets_with_extension('js')
    end

    def pages
      assets_with_extension('html')
    end

    def index_path
      "#{@folder}/index.html"
    end

    def demo_path
      pages.first.path
    end

    def explanation
      config['explanation']
    end

    def title
      config['title']
    end

    def reload
      unmemoize :config
    end

    def highlight(string, klass: 'example__highlight')
      string = string.dup
      highlighted_phrases.each do |phrase|
        string.gsub! phrase, %(<span class="#{klass}">#{phrase}</span>)
      end
      string
    end

    private

    def assets_with_extension(extension)
      assets = Dir["#{@folder}/*.#{extension}"].map { |path|
        Asset.new(self, path)
      }
      order_assets(assets)
    end

    def order_assets(assets)
      remaining_assets = assets.dup
      ordered_assets = order.map { |filename|
        asset = remaining_assets.detect { |asset|
          asset.name == filename
        }
        if asset
          remaining_assets.delete(asset)
          asset
        end
      }.compact
      ordered_assets + remaining_assets.sort_by(&:name)
    end

    memoize def config
      path = "#{@folder}/example.yml"
      if File.exists?(path)
        YAML.load_file(path)
      else
        {}
      end
    end

    def highlighted_phrases
      config['highlight'] || []
    end

    def order
      config['order'] || []
    end

    def self.load
      @by_name ||= Dir["examples/*"].collect { |example_dir|
        new(example_dir)
      }.index_by(&:name)
    end

    def self.find(name)
      load
      @by_name[name] or raise "Unknown example: #{name}"
    end

    def self.all
      load
      @by_name.values
    end

  end
end