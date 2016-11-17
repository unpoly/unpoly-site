module Unpoly
  module Guide
    class Slugalizer

      def self.slugalize(string)
        string = string.dup
        string.gsub!(/[^a-zA-Z0-9\-\_\.]/, '-')
        string.gsub!(/\-{2,}/, '-')
        string.gsub!(/^\-+/, '')
        string.gsub!(/\-+$/, '')
        string
      end

    end
  end
end
