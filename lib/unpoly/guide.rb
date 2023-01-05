require 'active_support/all'
require 'memoized'
require 'byebug'
require_relative 'guide/util'
require_relative 'guide/errors'
require_relative 'guide/logger'
require_relative 'guide/text_source'
require_relative 'guide/doc_comment'
require_relative 'guide/referencer'
require_relative 'guide/documentable'
require_relative 'guide/feature'
require_relative 'guide/interface'
require_relative 'guide/param'
require_relative 'guide/partial'
require_relative 'guide/parser'
require_relative 'guide/changelog'
require_relative 'guide/repository'
require_relative 'guide/markdown_renderer'
require_relative 'guide/response'
require_relative 'guide/algolia'

module Unpoly
  module Guide

    UNPOLY_PATH = 'vendor/unpoly-local'

    def self.current
      @current ||= Repository.new(UNPOLY_PATH)
    end

  end
end
