require 'active_support/all'
require 'shellwords'
require 'memoized'
require 'byebug'
require_relative 'guide/util'
require_relative 'guide/icon'
require_relative 'guide/errors'
require_relative 'guide/logger'
require_relative 'guide/text_source'
require_relative 'guide/doc_comment'
require_relative 'guide/heading'
require_relative 'guide/page_ref'
require_relative 'guide/wikilink'
require_relative 'guide/dynamic_tokens'
require_relative 'guide/documentable'
require_relative 'guide/mimic'
require_relative 'guide/feature'
require_relative 'guide/interface'
require_relative 'guide/param'
require_relative 'guide/param_section'
require_relative 'guide/partial'
require_relative 'guide/parser'
require_relative 'guide/changelog'
require_relative 'guide/toc'
require_relative 'guide/repository'
require_relative 'guide/markdown_renderer'
require_relative 'guide/toc_inserter'
require_relative 'guide/intro_inserter'
require_relative 'guide/embeds'
require_relative 'guide/response'
require_relative 'guide/pagefind'
require_relative 'guide/url_check'
require_relative 'guide/html_to_markdown'
require_relative 'guide/markdown_links'
require_relative 'guide/markdown_twins'
require_relative 'guide/agent_index'
require_relative 'guide/skill'
require_relative 'guide/skill_package'

module Unpoly
  module Guide

    UNPOLY_PATH = 'vendor/unpoly-local'

    def self.current
      @current ||= Repository.new(UNPOLY_PATH)
    end

    # The origin of the site's absolute URLs, e.g. in the Markdown twins.
    # BASE_URL=http://staging.example.com points a build somewhere else. The preview
    # server derives its origin from each request instead (`base_url` in config.rb).
    def self.base_url
      ENV['BASE_URL'].presence&.chomp('/') || 'https://unpoly.com'
    end

  end
end
