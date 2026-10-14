describe Unpoly::Site::Wikilink do

  let(:repository) { Unpoly::Site.current }

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
        .to raise_error(Unpoly::Site::PageRef::Unresolvable, /unknown page/)
    end

    describe 'a [[more: slug]] paragraph' do

      it 'expands to a learn-ref box labelled with the page title' do
        title = repository.find_by_guide_id('polling').title

        markdown = expand("Text.\n\n[[more: polling]]\n\nMore text.")
        nav = Nokogiri::HTML.fragment(markdown).at_css('nav.learn-refs.-more[aria-label="Read more"][data-pagefind-ignore]')

        expect(markdown).to start_with("Text.\n\n\n<nav ").and end_with("</nav>\n\n\nMore text.")
        expect(nav.css('a.learn-ref').size).to eq(1)
        expect(nav.at_css('a.learn-ref')['href']).to eq('/polling')
        expect(nav.css('a.learn-ref > *').map { |child| child[:class] })
          .to eq(['icon -book learn-ref--icon', 'learn-ref--prefix', 'learn-ref--destination'])
        expect(nav.at_css('.learn-ref--icon')['aria-hidden']).to eq('true')
        expect(nav.at_css('.learn-ref--destination').text).to eq(title)
        expect(nav.text.squish).to eq("More: #{title}")
      end

      it 'names the heading of an anchored slug' do
        title = repository.find_by_guide_id('network-issues').title

        link = Nokogiri::HTML.fragment(expand('[[more: network-issues#slow-server-responses]]')).at_css('.learn-ref')

        expect(link['href']).to eq('/network-issues#slow-server-responses')
        expect(link.text.squish).to eq("More: #{title}: Slow server responses")
      end

      it 'fails the build on an unknown slug' do
        expect { expand('[[more: a-page-we-never-wrote]]') }
          .to raise_error(Unpoly::Site::PageRef::Unresolvable, /unknown page/)
      end

      it 'fails the build when it is not a paragraph of its own' do
        expect { expand('See [[more: polling]] for details.') }
          .to raise_error(Unpoly::Site::Wikilink::Malformed, /paragraph of its own/)
      end

      it 'is not expanded inside code' do
        expect(expand("```md\n[[more: polling]]\n```\n")).to eq("```md\n[[more: polling]]\n```\n")
      end

    end

  end

  describe '.specs' do

    it 'collects the wikilinks of a text' do
      expect(described_class.specs('See [[polling]] and [[caching#expiration]].'))
        .to eq(['polling', 'caching#expiration'])
    end

    it 'collects the slugs of [[more: slug]] paragraphs' do
      expect(described_class.specs("[[more: polling]]\n\nSee [[caching]]."))
        .to eq(['polling', 'caching'])
    end

    it 'ignores wikilink syntax inside code' do
      expect(described_class.specs('Write `[[polling]]` to link a page.')).to be_empty
    end

  end

end
