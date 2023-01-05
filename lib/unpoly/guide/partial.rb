module Unpoly
  module Guide
    class Partial
      include Documentable

      def initialize(name = nil)
        @name = name
      end

      def guide_page?
        false
      end

    end
  end
end
