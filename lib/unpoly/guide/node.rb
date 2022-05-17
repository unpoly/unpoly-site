module Unpoly
  module Guide
    module Node
      include Referencer

      attr_accessor :kind
      attr_accessor :name
      attr_accessor :guide_markdown
      attr_accessor :text_source

      def long_kind
        kind.capitalize
      end

      def guide_id
        Util.slugify(name)
      end

      def guide_path
        "/#{guide_id}"
      end

      def summary_markdown
        Util.first_markdown_paragraph(@guide_markdown)
      end

      def inspect
        "#<#{self.class.name} @name=#{name}>"
      end

      def <=>(other)
        sort_name <=> other.sort_name
      end

      def sort_name
        sort_name = name
        sort_name = sort_name.downcase
        # sort_name = sort_name.sub(/^.+\bup\b/, 'up')
        sort_name = sort_name.gsub(/[^A-Za-z0-9\-]/, '-')
        sort_name = sort_name.sub(/-{2,}/, '-')
        sort_name = sort_name.sub(/^-+/, '')
        sort_name = sort_name.sub(/-+$/, '')
        if name.starts_with?('up.$')
          sort_name << 'z' # sort up.$compiler behing up.compiler
        end
        sort_name
      end

    end
  end
end
