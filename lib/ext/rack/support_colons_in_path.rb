require 'active_support/all'

##
# Middleman writes pages using Rack::Test.
# Unfortunately Rack::Test cannot work with relative paths
# that contain a colon, and the guide uses colons for
# event docs (/up:modal:opened).
#
# This monkey-patch absolutizes relative URLs before
# they are passed on to Rack::Test.
#

require 'rack/mock'

module Rack
  class MockRequest
    class << self

      module EnvForWithColons
        def env_for(uri="", opts={})
          uri = absolutize_uri(uri)
          super(uri, opts)
        end

        private

        def absolutize_uri(uri)
          unless uri.include?(':/') || uri[0] == '/'
            uri = "/#{uri}"
          end
          uri
        end

      end

      prepend EnvForWithColons

    end
  end
end
