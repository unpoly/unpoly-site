module Unpoly
  module Guide

    class Error < StandardError; end

    class Unknown < Error; end
    class UnknownInterface < Unknown; end
    class UnknownFeature < Unknown; end

  end
end
