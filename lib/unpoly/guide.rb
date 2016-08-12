require_relative 'guide/util'
require_relative 'guide/logger'
require_relative 'guide/slugalizer'
require_relative 'guide/feature'
require_relative 'guide/feature/index'
require_relative 'guide/klass'
require_relative 'guide/param'
require_relative 'guide/parser'
require_relative 'guide/repository'
require_relative 'guide/response'

module Unpoly
  module Guide

    UNPOLY_PATH = 'vendor/unpoly-local'

    def self.current
      @current ||= Repository.new(UNPOLY_PATH)
    end

  end
end
