#!/usr/bin/env ruby
# Checks the redirects of a built site against a running Apache, the way production
# serves it (source/.htaccess.erb, which includes unpoly's src/unpoly-migrate/.htaccess).
#
#   bundle exec rake docs:check_redirects BASE_URL=http://localhost:8089
#
# The site's model says what to expect, so this needs the same Unpoly checkout the
# build used (vendor/unpoly-local). Apache must serve the build as its DocumentRoot
# with AllowOverride All and mod_rewrite, mod_alias and mod_headers enabled.
#
# - Every document's old root path, as /foo, /foo/ and /foo.md, answers 301 with an
#   https Location of its final page (/learn/foo, /api/foo, plus .md), which answers 200.
# - Every hand-written redirect source answers 301 to its target, which answers 200
#   (one hop). External targets are not requested.
# - /install and /skill (permanent short URLs) redirect to their pages.
# - The hubs and other root pages answer 200, an unknown path 404.
#
# Locations name the host Apache saw (https://localhost:8089/...), so we follow a
# Location by its path on BASE_URL. Exits 1 on any problem.

require 'net/http'
require 'uri'
require 'securerandom'

SITE_ROOT = File.expand_path('..', __dir__)
Dir.chdir(SITE_ROOT)
require File.join(SITE_ROOT, 'lib/unpoly/site')

class CheckRedirects
  PERMANENT_SHORT_URLS = Unpoly::Site::UrlCheck::PERMANENT_SHORT_URLS
  ROOT_PAGES = %w[/ /learn /api /changes /changes/upgrading /support /index.md /llms.txt /learn.md /api.md].freeze

  def initialize(base_url)
    @base = URI(base_url.chomp('/'))
    @links = Unpoly::Site::LegacyLinks.new
    @url_check = Unpoly::Site::UrlCheck.new
    @problems = []
    @counts = Hash.new(0)
  end

  def run
    Net::HTTP.start(@base.host, @base.port, use_ssl: @base.scheme == 'https') do |http|
      @http = http
      check_moves
      check_short_urls
      check_renames
      check_root_pages
      check_unknown
    end
    report
  end

  private

  def check_moves
    @links.moves.sort.each do |from, to|
      expect_redirect(from, to, https: true, kind: :moved)
      expect_redirect("#{from}/", to, https: true, kind: :moved)
      expect_redirect("#{from}.md", "#{to}.md", https: true, kind: :moved)
    end
  end

  def check_short_urls
    PERMANENT_SHORT_URLS.each do |path|
      target = @links.moves[path] || @url_check.redirects[path]
      if target
        expect_redirect(path, target, kind: :short)
      else
        problem(path, 'is a permanent short URL, but neither a document nor a redirect')
      end
    end
  end

  # mod_alias builds an http:// Location behind the TLS proxy, so we don't demand https.
  def check_renames
    @url_check.redirects.sort.each do |from, to|
      expect_redirect(from, to, kind: :rename)
    end
  end

  def check_root_pages
    ROOT_PAGES.each do |path|
      status = get(path).code
      status == '200' ? @counts[:root] += 1 : problem(path, "answers #{status}, expected 200")
    end
  end

  def check_unknown
    path = "/nope-#{SecureRandom.hex(4)}"
    status = get(path).code
    status == '404' ? @counts[:unknown] += 1 : problem(path, "answers #{status}, expected 404")
  end

  def expect_redirect(from, to, kind:, https: false)
    response = get(from)
    location = response['Location']
    return problem(from, "answers #{response.code}, expected 301 to #{to}") unless response.code == '301' && location

    if to.include?('://')
      return location == to ? @counts[kind] += 1 : problem(from, "redirects to #{location}, expected #{to}")
    end

    uri = URI(location)
    path = [uri.path, uri.fragment].compact.join('#')
    return problem(from, "redirects to #{path}, expected #{to}") unless path == to
    return problem(from, "redirects to #{location}, expected an https Location") if https && uri.scheme != 'https'

    final = get(uri.path).code
    return problem(from, "redirects to #{path}, which answers #{final} (expected 200 in one hop)") unless final == '200'

    @counts[kind] += 1
  end

  def get(path)
    @http.request(Net::HTTP::Get.new(URI::DEFAULT_PARSER.escape(path, /[^A-Za-z0-9\-_.:$\/~!*'()+,;=@&]/)))
  end

  def problem(path, message)
    @problems << "#{path} #{message}"
  end

  def report
    puts "Checked redirects on #{@base}:"
    puts "  #{@counts[:moved]} old document paths (/foo, /foo/, /foo.md) redirect to their page in one hop"
    puts "  #{@counts[:short]} permanent short URLs redirect to their page"
    puts "  #{@counts[:rename]} hand-written redirects lead to their target in one hop"
    puts "  #{@counts[:root]} root pages answer 200, #{@counts[:unknown]} unknown path answers 404"
    if @problems.empty?
      puts 'All redirects OK.'
      true
    else
      puts
      puts "PROBLEMS (#{@problems.size}):"
      @problems.each { |entry| puts "  #{entry}" }
      false
    end
  end
end

if $PROGRAM_NAME == __FILE__
  base_url = ARGV[0] || ENV['BASE_URL'] or abort 'Usage: script/check_redirects.rb BASE_URL (e.g. http://localhost:8089)'
  exit(CheckRedirects.new(base_url).run ? 0 : 1)
end
