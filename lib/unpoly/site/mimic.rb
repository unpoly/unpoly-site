module Unpoly
  module Site
    module Mimic

      attr_accessor :like_name

      def mimic!(other)
        raise NotImplementedError
      end

    end
  end
end
