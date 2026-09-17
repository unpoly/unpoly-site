describe Unpoly::Guide::PageRef do

  let(:repository) { Unpoly::Guide.current }

  def parse(spec)
    described_class.parse(spec, repository: repository)
  end

  describe 'resolving' do

    it 'resolves a page slug to its path and title' do
      ref = parse('polling')

      expect(ref.path).to eq('/polling')
      expect(ref.title).to eq(repository.find_by_guide_id('polling').title)
    end

    it 'resolves an anchor to a heading of that page' do
      ref = parse('network-issues#slow-server-responses')

      expect(ref.path).to eq('/network-issues#slow-server-responses')
      expect(ref.heading.text).to eq('Slow server responses')
    end

    it 'resolves a feature page, so an anchor can point into a reference' do
      expect(parse('up.render').path).to eq('/up.render')
    end

    it 'rejects an unknown slug' do
      expect { parse('a-page-we-never-wrote') }.to raise_error(described_class::Unresolvable, /unknown page/)
    end

    it 'rejects an anchor that no heading produces' do
      expect { parse('polling#no-such-heading') }.to raise_error(described_class::Unresolvable, /unknown anchor/)
    end

    it 'names the source file so the error can be fixed' do
      expect { described_class.parse('nope', repository: repository, source: 'src/unpoly/link.js:12') }
        .to raise_error(described_class::Unresolvable, %r{src/unpoly/link\.js:12})
    end

  end

  describe 'derived labels' do

    it 'labels an unanchored reference with the page title' do
      ref = parse('polling')

      expect(ref.learn_ref_label).to eq(ref.title)
      expect(ref.wikilink_label).to eq(ref.title)
    end

    it 'labels an anchored reference with the page and the heading' do
      ref = parse('network-issues#slow-server-responses')

      expect(ref.learn_ref_label).to eq("#{ref.title} › Slow server responses")
      expect(ref.wikilink_label).to eq("#{ref.title}: Slow server responses")
    end

  end

  describe Unpoly::Guide::LearnRef do

    it 'uses the derived label' do
      learn_ref = described_class.new(Unpoly::Guide::PageRef.parse('polling', repository: Unpoly::Guide.current))

      expect(learn_ref.label).to eq(learn_ref.page_ref.learn_ref_label)
    end

    it 'prefers a label written by hand' do
      learn_ref = described_class.new(Unpoly::Guide::PageRef.parse('polling', repository: Unpoly::Guide.current), 'Keeping a fragment fresh')

      expect(learn_ref.label).to eq('Keeping a fragment fresh')
    end

  end

end
