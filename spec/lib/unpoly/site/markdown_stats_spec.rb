require 'tmpdir'
require 'zlib'
require 'lib/unpoly/site/markdown_stats'

describe Unpoly::Site::MarkdownStats do

  around do |example|
    Dir.mktmpdir do |dir|
      @dir = dir
      example.run
    end
  end

  let(:build) { File.join(@dir, 'build') }
  let(:logs) { File.join(@dir, 'logs') }

  let(:chrome) { 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36' }
  let(:claude) { 'Mozilla/5.0 AppleWebKit/537.36 (KHTML, like Gecko; compatible; ClaudeBot/1.0; +claudebot@anthropic.com)' }

  def write(path, content)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, content)
  end

  # A synthetic line in the combined format.
  def line(path, size, status: 200, method: 'GET', day: '02/Nov/2026', agent: chrome)
    %(192.0.2.1 - - [#{day}:10:00:00 +0100] "#{method} #{path} HTTP/1.1" #{status} #{size} "-" "#{agent}"\n)
  end

  def stats(*lines, **options)
    write(File.join(logs, 'server1/access.log'), lines.join)
    described_class.new(build: build, **options).read(logs)
  end

  before do
    write(File.join(build, 'index.html'), 'h' * 1000)
    write(File.join(build, 'index.md'), 'm' * 100)
    write(File.join(build, 'api/up.render/index.html'), 'h' * 2000)
    write(File.join(build, 'api/up.render.md'), 'm' * 200)
    write(File.join(build, 'api/up:request/index.html'), 'h' * 3000)
    write(File.join(build, 'api/up:request.md'), 'm' * 300)
    write(File.join(build, 'imprint/index.html'), 'h' * 400)
    write(File.join(build, 'assets/app.js'), 'js')
  end

  it 'counts requests for a page as HTML, unless their size is that of its Markdown twin' do
    result = stats(
      line('/api/up.render', 2000), # Raw HTML
      line('/api/up.render', Zlib.gzip(File.read(File.join(build, 'api/up.render/index.html'))).bytesize),
      line('/api/up.render', 200, agent: claude),
    )
    expect(result.totals).to eq(html: 2, explicit: 0, negotiated: 1)
  end

  it 'counts a size a few bytes off the twin as Markdown, as after a typo fix' do
    result = stats(
      line('/api/up.render', 210, agent: claude),
      line('/api/up.render', 240, agent: claude), # Too far off
    )
    expect(result.totals).to eq(html: 1, explicit: 0, negotiated: 1)
  end

  it 'counts a size near both the twin and the gzipped HTML as HTML' do
    html = Random.new(1).bytes(300) # Random bytes don't compress, so gzipped it stays near 300
    gzipped = Zlib.gzip(html).bytesize
    write(File.join(build, 'api/up.close/index.html'), html)
    write(File.join(build, 'api/up.close.md'), 'm' * (gzipped + 10))
    result = stats(line('/api/up.close', gzipped + 5))
    expect(result.totals).to eq(html: 1, explicit: 0, negotiated: 0)
  end

  it 'counts .md URLs as Markdown, and learns their sizes for negotiated requests' do
    result = stats(
      line('/api/up.render', 180, agent: claude), # An older twin, before a site edit
      line('/api/up.render.md', 180),
      line('/index.md', 100),
      line('/', 100, agent: claude),
    )
    expect(result.totals).to eq(html: 0, explicit: 2, negotiated: 2)
  end

  it 'counts a page with and without trailing slash, query string or percent-encoding as the same page' do
    result = stats(
      line('/api/up.render/', 200),
      line('/api/up.render?foo=bar', 200),
      line('/api/up%3Arequest', 300),
      line('/imprint/', 400), # No twin
    )
    expect(result.totals).to eq(html: 1, explicit: 0, negotiated: 3)
  end

  it 'skips lines that are not a successful GET for a page' do
    result = stats(
      line('/api/up.render', 0, status: 304),
      line('/api/up.render', 0, method: 'HEAD'),
      line('/assets/app.js', 2),
      line('/foo', 100),
      line('/api/up.render/../../../etc/passwd', 100),
      line('/api/%zz', 100),
      "garbage\n",
    )
    expect(result.totals.values.sum).to eq(0)
    expect(result.skipped).to eq(not_a_GET_200: 2, not_a_page: 4, unparsable: 1)
  end

  it 'only counts days within --from and --to' do
    result = stats(
      line('/', 1000, day: '31/Oct/2026'),
      line('/', 1000, day: '01/Nov/2026'),
      line('/', 1000, day: '02/Nov/2026'),
      line('/', 1000, day: '03/Nov/2026'),
      from: Date.new(2026, 11, 1), to: Date.new(2026, 11, 2),
    )
    expect(result.totals[:html]).to eq(2)
    expect(result.skipped).to eq(outside_dates: 2)
  end

  it 'reads gzipped logs from all subfolders' do
    write(File.join(logs, 'server1/access.log'), line('/', 1000))
    Zlib::GzipWriter.open(File.join(logs, 'server1/access.log.2.gz')) { |gz| gz.write(line('/', 1000)) }
    write(File.join(logs, 'server2/access.log.1'), line('/', 1000))
    write(File.join(logs, 'server2/error.log'), 'not an access log')

    result = described_class.new(build: build).read(logs)
    expect(result.totals[:html]).to eq(3)
  end

  it 'groups by user agent without version' do
    result = stats(
      line('/', 1000),
      line('/', 1000, agent: 'Mozilla/5.0 (X11; Linux x86_64) Chrome/131.0.0.0 Safari/537.36'),
      line('/', 100, agent: claude),
      line('/index.md', 100, agent: claude),
      line('/', 1000, agent: 'Mozilla/5.0 (Windows NT 10.0) Chrome/130.0.0.0 Safari/537.36 Edg/130.0.0.0'),
      line('/', 1000, agent: 'Mozilla/5.0 AppleWebKit/537.36 (KHTML, like Gecko; compatible; GPTBot/1.2; +https://openai.com/gptbot)'),
      line('/', 1000, agent: 'Mozilla/5.0 (Macintosh) Version/17.4 Safari/605.1.15 (Applebot/0.1; +http://www.apple.com/go/applebot)'),
      line('/', 1000, agent: 'curl/8.5.0'),
    )
    expect(result.by_agent).to eq(
      'Chrome' => { html: 2, explicit: 0, negotiated: 0 },
      'ClaudeBot' => { html: 0, explicit: 1, negotiated: 1 },
      'Applebot' => { html: 1, explicit: 0, negotiated: 0 },
      'Edge' => { html: 1, explicit: 0, negotiated: 0 },
      'GPTBot' => { html: 1, explicit: 0, negotiated: 0 },
      'curl' => { html: 1, explicit: 0, negotiated: 0 },
    )
  end

  it 'parses user agents with escaped quotes' do
    result = stats(%(192.0.2.1 - - [02/Nov/2026:10:00:00 +0100] "GET / HTTP/1.1" 200 1000 "https://example.com/\\"" "curl/8.5.0"\n))
    expect(result.by_agent.keys).to eq(['curl'])
  end

  it 'reports counts, percentages and skipped lines' do
    report = stats(line('/', 1000), line('/', 1000), line('/index.md', 100), line('/', 100), line('/foo', 1)).report(by_agent: true)
    expect(report).to include('HTML                          2   50.0%')
    expect(report).to include('Markdown via .md URL          1   25.0%')
    expect(report).to include('Markdown via Accept           1   25.0%')
    expect(report).to include('Skipped 1 lines: 1 not a page')
    expect(report).to match(/^Chrome +2 +1 +1$/)
  end

end
