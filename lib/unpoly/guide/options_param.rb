module Unpoly
  module Guide
    class OptionsParam

      def initialize(properties)
        @properties = properties
      end

      def name
        first_property.name_without_option_prefix
      end

      def optional?
        properties.all?(&:optional?)
      end

      def feature
        first_property.feature
      end

      private

      def first_property
        @properties.first
      end

    end
  end
end
