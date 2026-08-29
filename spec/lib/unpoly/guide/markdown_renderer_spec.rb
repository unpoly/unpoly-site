describe Unpoly::Guide::MarkdownRenderer do

  # The renderer needs to know the page it renders for, so it can leave out
  # self-referential links.
  def render(markdown, **options)
    described_class.new(current_path: '/current-page', **options).to_html(markdown)
  end

  # Returns a { link text => href } hash for all links in the given HTML.
  def links_in(html)
    Nokogiri::HTML.fragment(html).css('a').to_h { |link| [link.text.strip, link['href']] }
  end

  describe 'autolinking of code' do

    it 'links a code span that names a documented feature' do
      html = render('Use `up.render()` to update a fragment.')

      expect(links_in(html)).to eq('up.render()' => '/up.render')
    end

    it 'links a code span that names a documented selector' do
      html = render('The `[up-follow]` attribute.')

      expect(links_in(html)).to eq('[up-follow]' => '/up-follow')
    end

    it 'does not link a code span that names no documented feature' do
      html = render('Call `notADocumentedFeature()` here.')

      expect(links_in(html)).to be_empty
    end

    it 'does not link code within a code block' do
      html = render("```js\nup.render()\n```")

      expect(links_in(html)).to be_empty
    end

    it 'does not link code within a heading' do
      html = render('## About `up.render()`')

      expect(links_in(html)).to be_empty
    end

    it 'does not link to the page that is currently rendered' do
      html = render('See `up.render()`.', current_path: '/up.render')

      expect(links_in(html)).to be_empty
      expect(html).to include('<code>up.render()</code>')
    end

  end

  describe 'with { strip_links: true }' do

    it 'removes links, but keeps their text' do
      html = render('A [link](/foo) in prose.', strip_links: true)

      expect(links_in(html)).to be_empty
      expect(html).to include('A link in prose.')
    end

    it 'does not autolink code' do
      html = render('Use `up.render()` here.', strip_links: true)

      expect(links_in(html)).to be_empty
    end

  end

  describe 'admonitions' do

    it 'renders a GitHub-style admonition as a styled blockquote' do
      html = render("> [!TIP]\n> Be careful here.")
      blockquote = Nokogiri::HTML.fragment(html).at_css('blockquote')

      expect(blockquote[:class]).to eq('admonition -tip')
      expect(blockquote.at_css('.admonition--title').text).to eq('Tip')
      expect(blockquote.text).to include('Be careful here.')
    end

    it 'uses an explicit admonition title' do
      html = render("> [!NOTE \"Custom title\"]\n> Some note.")
      blockquote = Nokogiri::HTML.fragment(html).at_css('blockquote')

      expect(blockquote[:class]).to eq('admonition -note')
      expect(blockquote.at_css('.admonition--title').text).to eq('Custom title')
    end

    it 'renders a plain blockquote without an admonition signature' do
      html = render('> Just a quote.')
      blockquote = Nokogiri::HTML.fragment(html).at_css('blockquote')

      expect(blockquote[:class]).to be_blank
    end

  end

  describe 'images' do

    it 'rewrites a path relative to the Unpoly sources to the folder where the site keeps API images' do
      html = render('![Alt text](images/example.png)')

      expect(Nokogiri::HTML.fragment(html).at_css('img')[:src]).to eq('/images/api/example.png')
    end

    it 'styles an image that has no explicit class' do
      html = render('![Alt text](images/example.png)')

      expect(Nokogiri::HTML.fragment(html).at_css('img')[:class]).to eq('picture has_border')
    end

    it 'leaves an absolute path alone' do
      html = render('![Alt text](/other/example.png)')

      expect(Nokogiri::HTML.fragment(html).at_css('img')[:src]).to eq('/other/example.png')
    end

  end

  describe 'heading levels' do

    it 'normalizes the topmost heading to an <h2>, so it fits below the page title' do
      html = render("# Top\n\n## Nested\n\n### Deeply nested")
      headings = Nokogiri::HTML.fragment(html).css('h1, h2, h3, h4').map(&:name)

      expect(headings).to eq(%w[h2 h3 h4])
    end

    it 'shifts heading levels with { shift_heading_level }' do
      html = render('## Heading', shift_heading_level: 1)

      expect(Nokogiri::HTML.fragment(html).at_css('h1, h2, h3, h4').name).to eq('h3')
    end

  end

end
