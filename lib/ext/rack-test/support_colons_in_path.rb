##
# Middleman writes pages using Rack::Test.
# Unfortunately Rack::Test cannot work with relative paths
# that contain a colon, and the guide uses colons for
# event docs (/up:modal:opened).
#
# This monkey-patch absolutizes relative URLs before
# they are passed on to Rack::Test.
#

require 'rack/test'

module Rack
  module Test
    class Session

      private

      def env_for_with_colons(path, env)
        path = absolutize(path)
        env_for_without_colons(path, env)
      end

      alias_method_chain :env_for, :colons

      def process_request_with_colons(uri, env)
        uri = absolutize(uri)
        process_request_without_colons(uri, env)
      end

      alias_method_chain :process_request, :colons

      private

      def absolutize(path)
        unless path.include?(':/') || path[0] == '/'
          path = "/#{path}"
        end
        path
      end

    end
  end
end
