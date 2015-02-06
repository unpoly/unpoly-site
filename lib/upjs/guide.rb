require_relative 'guide/logger'
require_relative 'guide/function'
require_relative 'guide/klass'
require_relative 'guide/param'
require_relative 'guide/parser'
require_relative 'guide/repository'
require_relative 'guide/response'

module Upjs
  module Guide

    def self.current
      @current ||= Repository.new('../upjs/lib/assets/javascripts')
    end

  end
end
