module Unpoly
  module Guide
    module Logger

      def log(*args)
        puts ([self.class.name] + args).inspect
      end

    end
  end
end
