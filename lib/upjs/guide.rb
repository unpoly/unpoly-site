require_relative 'guide/util'
require_relative 'guide/logger'
require_relative 'guide/feature'
require_relative 'guide/klass'
require_relative 'guide/param'
require_relative 'guide/parser'
require_relative 'guide/repository'
require_relative 'guide/response'

module Upjs
  module Guide

    UPJS_PATH = 'vendor/upjs-local'

    def self.current
      @current ||= Repository.new(UPJS_PATH)
    end

  end
end
