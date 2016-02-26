module Unpoly
  module Guide
    class Util
      class << self

        def slugify(string)
          guide_id = string.dup
          # Colons (used in up:events) are valid URL segments, as used e.g. by
          # Wikipedia: https://en.wikipedia.org/wiki/Template:Welcome
          guide_id.gsub!(/[^A-Za-z0-9\:\-\.]/, '-')
          guide_id.gsub!(/^\-{2,}/, '-')
          guide_id.gsub!(/^\-/, '')
          guide_id.gsub!(/\-$/, '')
          guide_id
        end

      end
    end
  end
end
