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

      def env_for_with_colons(uri="", opts={})
        uri = absolutize_uri(uri)
        env_for_without_colons(uri, opts)
      end

      alias_method_chain :env_for, :colons

      private

      def absolutize_uri(uri)
        unless uri.include?(':/') || uri[0] == '/'
          uri = "/#{uri}"
        end
        uri
      end

    end
  end
end
