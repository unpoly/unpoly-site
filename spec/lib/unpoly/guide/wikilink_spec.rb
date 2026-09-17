describe Unpoly::Guide::Wikilink do

  let(:repository) { Unpoly::Guide.current }

  def expand(markdown)
    described_class.expand(markdown, repository: repository)
  end

  describe '.expand' do

    it 'expands a slug to a link labelled with the page title' do
      title = repository.find_by_guide_id('polling').title

      expect(expand('See [[polling]].')).to eq("See [#{title}](/polling).")
    end

    it 'expands an anchored slug to a link that names the heading' do
      title = repository.find_by_guide_id('network-issues').title

      expect(expand('See [[network-issues#slow-server-responses]].'))
        .to eq("See [#{title}: Slow server responses](/network-issues#slow-server-responses).")
    end

    it 'leaves prose without wikilinks alone' do
      expect(expand('Nothing to see here.')).to eq('Nothing to see here.')
    end

    it 'does not expand inside an inline code span' do
      expect(expand('Write `[[polling]]` to link a page.')).to eq('Write `[[polling]]` to link a page.')
    end

    it 'does not expand inside a fenced code block' do
      markdown = "Before.\n\n```js\nlet pairs = [[1, 2]]\nlet slug = '[[polling]]'\n```\n\nAfter.\n"

      expect(expand(markdown)).to eq(markdown)
    end

    it 'does not mistake a dynamic token for a wikilink' do
      expect(expand('Built for version [[=version]].')).to eq('Built for version [[=version]].')
    end

    it 'fails the build on an unknown slug' do
      expect { expand('See [[a-page-we-never-wrote]].') }
        .to raise_error(Unpoly::Guide::PageRef::Unresolvable, /unknown page/)
    end

  end

  describe '.specs' do

    it 'collects the wikilinks of a text' do
      expect(described_class.specs('See [[polling]] and [[caching#expiration]].'))
        .to eq(['polling', 'caching#expiration'])
    end

    it 'ignores wikilink syntax inside code' do
      expect(described_class.specs('Write `[[polling]]` to link a page.')).to be_empty
    end

  end

end
