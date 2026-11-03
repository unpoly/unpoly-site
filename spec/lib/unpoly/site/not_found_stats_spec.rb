require 'tmpdir'
require 'lib/unpoly/site/not_found_stats'

describe Unpoly::Site::NotFoundStats do

  around do |example|
    Dir.mktmpdir do |dir|
      @dir = dir
      example.run
    end
  end

  let(:build) { File.join(@dir, 'build') }
  let(:migrate) { File.join(@dir, 'unpoly-migrate') }
  let(:logs) { File.join(@dir, 'logs') }

  def write(path, content)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, content)
  end

  def page(path, html = '')
    write(File.join(build, path, 'index.html'), html)
  end

  # A synthetic line in the combined format.
  def line(path, status: 404, method: 'GET', client: '192.0.2.1', day: '02/Nov/2026', agent: 'curl/8.5.0')
    %(#{client} - - [#{day}:10:00:00 +0100] "#{method} #{path} HTTP/1.1" #{status} 100 "-" "#{agent}"\n)
  end

  def stats(*lines, **options)
    write(File.join(logs, 'server1/access.log'), lines.join)
    described_class.new(build: build, migrate: migrate, **options).read(logs)
  end

  def row(stats, path)
    stats.rows.find { |row| row.path == path }.to_h.slice(:kind, :target, :note)
  end

  before do
    page('')
    page('api')
    page('api/up.render')
    write(File.join(build, 'api/up.render.md'), '')
    page('api/up.layer')
    page('api/up:layer:opened')
    page('api/up.util.isNumber')
    page('api/up.network.config')
    # Both have a param [up-target], but more pages link to up-follow.
    page('api/up-follow', '<a href="/api/up-follow#up-target"></a> <a href="/api/up-submit#up-target"></a> <a href="/learn/caching#action"></a>')
    page('api/up-submit', '<a href="/api/up-follow">')
    page('learn/caching')
    page('learn/loading-state')
    page('learn/tooltips')
    write(File.join(build, 'images/favicon-690c22d3.png'), '')
    write(File.join(build, '.htaccess'), <<~HTACCESS)
      RedirectPermanent /community /support
      RedirectMatch permanent ^/examples(/.*)?$ /learn
      RedirectPermanent /up.proxy /api/up.network
    HTACCESS
    page('support')
    write(File.join(migrate, 'modal.js'), <<~JS)
      up.migrate.deprecated('up.modal.visit(url)', 'up.layer.open({ url, mode: "modal" })')
      up.migrate.deprecated('up.modal.close()', 'up.layer.dismiss()')
      up.migrate.renamedEvent('up:modal:opened', 'up:layer:opened')
      up.migrate.renamedNamespace('proxy', 'network')
      up.migrate.renamedProperty(config, 'cacheSize', 'cacheLimit', { label: 'up.network.config' })
      up.migrate.deprecated('up.util.times()', 'a `for` loop')
    JS
  end

  it 'drops every request of a client that probed for an attack target once' do
    result = stats(
      line('/wp-login.php', client: '192.0.2.66'),
      line('/missing', client: '192.0.2.66'),
      line('/settings%2F.env', client: '192.0.2.67'),
      line('/missing'),
      line('/.well-known/security.txt'), # Not a probe
    )
    expect(result.rows.map { |row| [row.path, row.requests, row.clients] }).to contain_exactly(
      ['/missing', 1, 1],
      ['/.well-known/security.txt', 1, 1],
    )
    expect(result.report).to include('5 GET 404s. Dropped 2 scanners (of 3 clients) with 3 requests, 3 of them GET 404s.')
  end

  it 'counts only GET 404s, by path without query, most clients first' do
    result = stats(
      line('/one'), line('/one'), line('/one'),
      line('/two', client: '192.0.2.2'), line('/two?page=2', client: '192.0.2.3'),
      line('/three', method: 'HEAD'),
      line('/four', status: 200),
    )
    expect(result.rows.map { |row| [row.path, row.requests, row.clients] }).to eq([['/two', 2, 2], ['/one', 3, 1]])
  end

  it 'only counts days within --from and --to' do
    result = stats(line('/old', day: '31/Oct/2026'), line('/new', day: '01/Nov/2026'), from: Date.new(2026, 11, 1))
    expect(result.rows.map(&:path)).to eq(['/new'])
  end

  it 'counts a path as fixed when the build serves it, or .htaccess redirects it by now' do
    result = stats(*%w[/api/up.render /up.render /up.render.md /community/thread /examples/modal /up.proxy /up.proxy.config].map { |path| line(path) })
    expect(row(result, '/api/up.render')).to eq(kind: :fixed, target: '/api/up.render', note: nil)
    expect(row(result, '/up.render')).to eq(kind: :fixed, target: '/api/up.render', note: nil)
    expect(row(result, '/up.render.md')).to eq(kind: :fixed, target: '/api/up.render.md', note: nil)
    expect(row(result, '/community/thread')).to eq(kind: :fixed, target: '/support/thread', note: nil)
    expect(row(result, '/examples/modal')).to eq(kind: :fixed, target: '/learn', note: nil)
    expect(row(result, '/up.proxy')).to eq(kind: :fixed, target: '/api/up.network', note: nil)
    # Like Apache, a redirect from /up.proxy only covers the paths below it.
    expect(row(result, '/up.proxy.config')[:kind]).not_to eq(:fixed)
  end

  it 'finds a page without junk from the text around a link, .html, case, or a wrong prefix' do
    paths = ['/api/up.render.md).', '/api/up.util.isNumber()', '/up.render)13:', '/[up-follow]', '/up-follow%60',
      '/caching/index.html', '/API/UP.RENDER', '/api/caching', '/learn/up.render']
    result = stats(*paths.map { |path| line(path) })
    expect(paths.map { |path| row(result, URI.decode_uri_component(path)).values_at(:kind, :target) }).to eq([
      [:cleanup, '/api/up.render.md'],
      [:cleanup, '/api/up.util.isNumber'],
      [:cleanup, '/api/up.render'],
      [:cleanup, '/api/up-follow'],
      [:cleanup, '/api/up-follow'],
      [:cleanup, '/learn/caching'],
      [:cleanup, '/api/up.render'],
      [:cleanup, '/learn/caching'],
      [:cleanup, '/api/up.render'],
    ])
  end

  it 'finds an attribute as an anchor on the page with the most links among those we link to with it' do
    result = stats(line('/up-target'), line('/api/up-target'), line('/action'))
    expect(row(result, '/up-target')).to eq(kind: :anchor, target: '/api/up-follow#up-target', note: nil)
    expect(row(result, '/api/up-target')).to eq(kind: :anchor, target: '/api/up-follow#up-target', note: nil)
    expect(row(result, '/action')[:kind]).to eq(:unmatched) # Not an API name, so a guess at an app's URL
  end

  it 'finds an asset under an old fingerprint' do
    result = stats(line('/images/favicon-2d52fc7a.png'))
    expect(row(result, '/images/favicon-2d52fc7a.png')).to eq(kind: :fingerprint, target: '/images/favicon-690c22d3.png', note: nil)
  end

  it 'finds the successor of an old API name in unpoly-migrate' do
    result = stats(*%w[/up:modal:opened /up.modal /up.network.config.cacheSize /up.modal.close /up.util.times].map { |path| line(path) })
    expect(row(result, '/up:modal:opened')).to eq(kind: :api_name, target: '/api/up:layer:opened', note: 'successor up:layer:opened')
    # A namespace without a rename goes where most of its members went.
    expect(row(result, '/up.modal')).to eq(kind: :api_name, target: '/api/up.layer', note: 'successor up.layer')
    expect(row(result, '/up.network.config.cacheSize')).to eq(kind: :api_name, target: nil, note: 'successor up.network.config.cacheLimit has no page')
    expect(row(result, '/up.modal.close')).to eq(kind: :api_name, target: nil, note: 'successor up.layer.dismiss has no page')
    expect(row(result, '/up.util.times')).to eq(kind: :api_name, target: nil, note: nil) # The successor is prose
  end

  it 'guesses a Learn page for an old API name without a successor' do
    result = stats(line('/up.tooltip'), line('/up.util.trim'))
    expect(row(result, '/up.tooltip')).to eq(kind: :api_name, target: '/learn/tooltips', note: 'guess, score 1.00')
    expect(row(result, '/up.util.trim')).to eq(kind: :api_name, target: nil, note: nil)
  end

  it 'suggests a page whose name shares more than half of the words' do
    result = stats(line('/loading-states'), line('/loading-indicators'))
    expect(row(result, '/loading-states')).to eq(kind: :similar, target: '/learn/loading-state', note: '1.00')
    expect(row(result, '/loading-indicators')[:kind]).to eq(:unmatched) # Only half of the words
  end

  it 'reports each kind with its most requested paths, and drafts redirects for API names and anchors' do
    report = stats(
      line('/favicon.ico'), line('/favicon.ico', client: '192.0.2.2'), line('/foo'),
      line('/up-target'), line('/up:modal:opened'), line('/up:modal:opened).'),
    ).report(top: 1)
    expect(report).to include(<<~TEXT.chomp)
      Unmatched (2 paths, 3 requests)
      Clients Requests  Path → Target (note) [top user agent]
            2        2  /favicon.ico  [curl]
              … and 1 more
    TEXT
    expect(report).to end_with(<<~TEXT.chomp)
      Draft redirects for API names and anchors, from paths without junk
      RedirectPermanent /up-target /api/up-follow#up-target
      RedirectPermanent /up:modal:opened /api/up:layer:opened
    TEXT
  end

end
