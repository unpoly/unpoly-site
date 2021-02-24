module Unpoly
  module Guide
    module Referencer

      def reference_names
        @reference_names ||= []
      end

      def reference_names=(names)
        @reference_names = names
      end

      def references
        reference_names.map do |name|
          Guide.current.find_by_name!(name)
        end
      end

      def references?
        @reference_names.present?
      end

    end
  end
end
