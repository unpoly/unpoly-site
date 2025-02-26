module Unpoly
  module Guide
    class ParamSection

      def initialize(title, params)
        @title = title
        @params = params
      end

      attr_reader :title, :params

      def guide_anchor(prefix)
        title_slug = Util.slugify(title.downcase)
        [prefix, title_slug].join('-')
      end

    end
  end
end
