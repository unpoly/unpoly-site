require 'active_support/all'
require 'shellwords'
require 'memoized'
require 'byebug'
require_relative 'site/util'
require_relative 'site/icon'
require_relative 'site/errors'
require_relative 'site/logger'
require_relative 'site/text_source'
require_relative 'site/doc_comment'
require_relative 'site/commonmark'
require_relative 'site/heading'
require_relative 'site/page_ref'
require_relative 'site/wikilink'
require_relative 'site/dynamic_tokens'
require_relative 'site/documentable'
require_relative 'site/mimic'
require_relative 'site/feature'
require_relative 'site/interface'
require_relative 'site/param'
require_relative 'site/param_section'
require_relative 'site/partial'
require_relative 'site/parser'
require_relative 'site/changelog'
require_relative 'site/toc'
require_relative 'site/repository'
require_relative 'site/markdown_renderer'
require_relative 'site/toc_inserter'
require_relative 'site/intro_inserter'
require_relative 'site/embeds'
require_relative 'site/response'
require_relative 'site/pagefind'
require_relative 'site/url_check'
require_relative 'site/html_to_markdown'
require_relative 'site/markdown_links'
require_relative 'site/markdown_twins'
require_relative 'site/agent_index'
require_relative 'site/skill'
require_relative 'site/skill_package'

module Unpoly
  module Site

    UNPOLY_PATH = 'vendor/unpoly-local'

    # The two halves of the documentation, each under its own path prefix. Their hubs
    # live at these paths, their documents below them (/learn/caching, /api/up.render).
    LEARN_PATH = '/learn'
    API_PATH = '/api'

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
