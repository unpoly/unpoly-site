# The Apache rules unpoly.com is served with (source/.htaccess.erb). Apache sits behind
# a proxy that ends TLS, so it sees plain http: a redirect to a bare path comes out as
# an http:// Location.
describe 'the .htaccess', type: :feature do

  def htaccess
    visit '/.htaccess'
    page.body
  end

  def rewrite_rules
    htaccess.lines.map(&:strip).grep(/\ARewriteRule /)
  end

  it 'names the https scheme in every redirect it rewrites' do
    redirects = rewrite_rules.select { |rule| rule =~ /\[[^\]]*\bR\b/ || rule =~ /\[[^\]]*R=/ }

    expect(redirects).not_to be_empty
    redirects.each do |rule|
      target = rule.split(/\s+/)[2]
      expect(target).to start_with('https://'), "#{rule} redirects without a scheme"
    end
  end

  it 'sends other hosts to unpoly.com before it maps paths to their index.html' do
    host = rewrite_rules.index { |rule| rule.include?('https://unpoly.com/') }
    index = rewrite_rules.index { |rule| rule.include?('/index.html [L]') }

    expect(host).to be < index
  end

  it 'redirects www.unpoly.com permanently, and v3.unpoly.com only until it serves the v3 docs again' do
    lines = htaccess.lines.map(&:strip)
    rule_for = ->(host) { lines[lines.index("RewriteCond %{HTTP_HOST} ^#{host}\\.unpoly\\.com$") + 1] }

    expect(rule_for.('www')).to eq('RewriteRule ^(.*)$ https://unpoly.com/$1 [R=301,L]')
    expect(rule_for.('v3')).to eq('RewriteRule ^(.*)$ https://unpoly.com/$1 [R=307,L]')
  end

  describe 'Markdown for agents' do
    # The condition a request's Accept header must meet to get a page's .md twin.
    # Apache's PCRE and Ruby agree on everything this pattern uses.
    def markdown_accept_pattern
      conditions = htaccess.lines.map(&:strip).grep(/\ARewriteCond %\{HTTP:Accept\}/)
      expect(conditions.size).to eq(2)
      expect(conditions.uniq.size).to eq(1)
      Regexp.new(conditions.first.split(/\s+/)[2], Regexp::IGNORECASE)
    end

    it 'negotiates Markdown only when it is the first media type, and not refused with q=0' do
      pattern = markdown_accept_pattern
      {
        'text/markdown, text/html, */*' => true,                      # Claude Code
        'text/markdown,text/html;q=0.9,*/*;q=0.8' => true,            # Cursor
        'text/markdown;q=1.0, text/html;q=0.9' => true,               # OpenCode
        'text/markdown' => true,
        'TEXT/MARKDOWN; charset=utf-8' => true,
        'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8' => false, # browsers, Codex
        '*/*' => false,                                                # curl, Gemini CLI
        'text/html, text/markdown' => false,
        'text/markdown;q=0' => false,
        'text/markdown; q=0.0, text/html' => false,
        'text/markdown; charset=utf-8; q=0, text/html' => false,
        'text/markdown;q=0.5, text/html' => true,
        'text/markdownish' => false,
      }.each do |accept, negotiates|
        expect(pattern.match?(accept)).to eq(negotiates), "Accept: #{accept} should #{'not ' unless negotiates}negotiate"
      end
    end

    it 'negotiates before it maps paths to their index.html, and after the trailing-slash redirect' do
      rules = rewrite_rules
      twin = rules.index { |rule| rule.include?('/$1.md [L]') }
      slash = rules.index { |rule| rule.include?('https://%{HTTP_HOST}/$1 [R=301,L]') && rule.include?('(.+?)/$') }
      index = rules.index { |rule| rule.include?('/index.html [L]') }

      expect(twin).to be > slash
      expect(twin).to be < index
    end

    it 'redirects a .md URL without a file to its page' do
      expect(rewrite_rules).to include('RewriteRule ^(.+)\.md$ https://%{HTTP_HOST}/$1 [R=301,L]')
    end

    it 'serves .md as Markdown and varies on Accept' do
      expect(htaccess).to include('AddType "text/markdown; charset=utf-8" .md')
      # Both variants of a page's URL, so caches keep them apart.
      expect(htaccess).to include('Header merge Vary Accept "expr=%{CONTENT_TYPE} =~ m#^text/(html|markdown)#"')
    end

    # Markdown that an agent got at a page's own URL comes back through the rules as an
    # internal redirect. The REDIRECT_STATUS condition skips it: that URL is the page's.
    it 'names the page as the canonical URL of a twin requested at its .md URL, and /llms.txt for /index.md' do
      lines = htaccess.lines.map(&:strip)
      rules = lines.each_index.select { |i| lines[i].include?('E=MARKDOWN_CANONICAL:') }.map { |i| lines[i - 1..i] }

      expect(rules).to eq([
        ['RewriteCond %{ENV:REDIRECT_STATUS} ^$', 'RewriteRule ^(.+)\.md$ - [E=MARKDOWN_CANONICAL:/$1]'],
        ['RewriteCond %{ENV:REDIRECT_STATUS} ^$', 'RewriteRule ^index\.md$ - [E=MARKDOWN_CANONICAL:/llms.txt]'],
      ])
      expect(htaccess).to include('Header set Link "<https://unpoly.com%{MARKDOWN_CANONICAL}e>; rel=\\"canonical\\"" env=MARKDOWN_CANONICAL')
      expect(htaccess).not_to include('X-Robots-Tag')
    end
  end

  it 'sends the retired runnable examples to Learn, as the site serves none of them' do
    expect(htaccess).to include('RedirectMatch permanent ^/examples(/.*)?$ /learn')

    request = Rack::MockRequest.new(Capybara.app)
    expect(request.get('/examples/modal').status).to eq(404)
  end

  describe 'short paths' do
    # The rules are tried against a real Apache in the URL move runbook. Here we only
    # pin their order, which no build would notice going wrong.
    it 'redirects /foo to /learn/foo before /api/foo, for pages and their Markdown twins' do
      rules = rewrite_rules
      learn = rules.index('RewriteRule ^(.+?)/?$ https://%{HTTP_HOST}/learn/$1 [R=301,L]')
      api = rules.index('RewriteRule ^(.+?)/?$ https://%{HTTP_HOST}/api/$1 [R=301,L]')
      learn_md = rules.index('RewriteRule ^(.+)\.md$ https://%{HTTP_HOST}/learn/$1.md [R=301,L]')
      api_md = rules.index('RewriteRule ^(.+)\.md$ https://%{HTTP_HOST}/api/$1.md [R=301,L]')

      expect([learn, api, learn_md, api_md]).to all(be_a(Integer))
      expect(learn).to be < api
      expect(learn_md).to be < api_md
    end

    it 'redirects them before a .md URL without a file falls back to its page, and before mapping paths to their index.html' do
      rules = rewrite_rules
      last_short = rules.index('RewriteRule ^(.+)\.md$ https://%{HTTP_HOST}/api/$1.md [R=301,L]')
      fallback = rules.index('RewriteRule ^(.+)\.md$ https://%{HTTP_HOST}/$1 [R=301,L]')
      index = rules.index { |rule| rule.include?('/index.html [L]') }

      expect(last_short).to be < fallback
      expect(last_short).to be < index
    end

    it 'tests for a page by its index.html, and lets a page at the root win' do
      conditions = htaccess.lines.map(&:strip).grep(/\ARewriteCond %\{DOCUMENT_ROOT\}\/(learn|api)\//)
      expect(conditions).to include('RewriteCond %{DOCUMENT_ROOT}/learn/$1/index.html -f', 'RewriteCond %{DOCUMENT_ROOT}/api/$1/index.html -f')
      expect(htaccess.scan('RewriteCond %{DOCUMENT_ROOT}/$1/index.html !-f').size).to eq(2)
      expect(htaccess.scan('RewriteCond %{DOCUMENT_ROOT}/$1.md !-f').size).to eq(2)
    end
  end

end
