describe Unpoly::Site::LegacyLinks do

  subject(:links) do
    repository = instance_double(Unpoly::Site::Repository, path: Unpoly::Site.current.path)
    described_class.new(repository).tap do |links|
      allow(links).to receive(:moves).and_return(
        '/up.render' => '/api/up.render',
        '/caching' => '/learn/caching',
        '/install' => '/learn/install',
        '/start/links' => '/learn/start/links',
      )
    end
  end

  def legacy_links(text, file: 'page.md', code_aware: true)
    found = []
    links.rewrite(text, file: file, code_aware: code_aware) { |_form, path, moved| found << path if moved }
    found
  end

  describe '#rewrite' do
    it 'finds links to old document paths, with anchors and Markdown twins' do
      text = <<~MD
        See [up.render()](/up.render#options.target), [caching](/caching.md),
        <a href="/start/links">links</a>, https://unpoly.com/caching and [[=base_url]]/install as well.
      MD
      expect(legacy_links(text)).to contain_exactly('/up.render', '/caching.md', '/start/links', '/caching', '/install')
    end

    it 'rewrites them to their final path' do
      expect(links.rewrite('[x](/up.render#options.target)', file: 'page.md', code_aware: true) {}).to eq('[x](/api/up.render#options.target)')
    end

    it 'leaves paths alone that are no document' do
      text = '[changes](/changes/3.0.0) [support](/support) [learn](/learn) [api](/api/up.render) [img](/images/x.png) [index](/index.md)'
      expect(legacy_links(text)).to eq([])
    end

    it 'ignores examples in code, but not the URL of this site' do
      text = "```html\n<a href=\"/caching\">x</a>\n```\n`[x](/up.render)` and `https://unpoly.com/caching`"
      expect(legacy_links(text)).to eq(['/caching'])
    end

    it 'reads comments in library code, and only unpoly.com URLs outside of them' do
      text = "/*-\nSee [up.render()](/up.render).\n*/\nthrow new Error('See https://unpoly.com/caching')\nup.link.follow({ url: '/install' })\n"
      expect(legacy_links(text, file: 'x.js')).to eq(['/up.render', '/caching'])
    end
  end

  describe '#scan_site' do
    it 'finds old paths in quotes and unpoly.com URLs in templates' do
      found = []
      links.scan_site(%(<%= hyperlink 'Learn more', '/caching' %> <a href="/up.render#x"> https://unpoly.com/install '/changes')) { |path, _| found << path }
      expect(found).to contain_exactly('/caching', '/up.render', '/install')
    end
  end

end

describe Unpoly::Site::LegacyLinkCheck do

  it 'finds no link to an old document path in our sources' do
    expect(described_class.new.problems).to eq([])
  end

end
