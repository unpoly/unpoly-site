describe Unpoly::Site::TOCInserter do

  # A long intro, so that the contents are worth inserting even for two headings.
  def html(*headings)
    "<p>#{'Text. ' * 400}</p>" + headings.map { |heading| "#{heading}<p>Text.</p>" }.join
  end

  def toc_links(html)
    inserter = described_class.new
    inserter.auto_insert(html)
    Nokogiri::HTML.fragment(inserter.rail_toc_html.to_s).css('a').map { |link| link['href'] }
  end

  it 'lists the top-level headings with an id' do
    expect(toc_links(html('<h2 id="a">A</h2>', '<h3 id="b">B</h3>', '<h2 id="c">C</h2>'))).to eq(['#a', '#c'])
  end

  it 'skips a heading with [data-toc-ignore]' do
    expect(toc_links(html('<h2 id="a">A</h2>', '<h2 id="b" data-toc-ignore>B</h2>', '<h2 id="c">C</h2>'))).to eq(['#a', '#c'])
  end

  it 'lists a lower heading with [data-toc-include]' do
    expect(toc_links(html('<h2 id="a">A</h2>', '<h3 id="b" data-toc-include="true">B</h3>', '<h2 id="c">C</h2>'))).to eq(['#a', '#b', '#c'])
  end

end

describe Unpoly::Site::TOCInserter, '#auto_insert' do

  # The nav's label names it; a visible "Contents" heading would only add an h4 to the
  # outline before the first h2.
  it 'lists the contents in a <ul> below a title that is no heading' do
    html = "<p>#{'Text. ' * 400}</p>" + %w[a b c].map { |id| %(<h2 id="#{id}">#{id.upcase}</h2><p>Text.</p>) }.join

    nav = Nokogiri::HTML5.fragment(described_class.new.auto_insert(html)).at_css('nav.toc[aria-label="Contents"]')

    expect(nav.css('h1, h2, h3, h4, h5, h6')).to be_empty
    expect(nav.at_css('.toc--title')[:'aria-hidden']).to eq('true')
    expect(nav.css('ul.toc--items > li.toc--item > a').map { |link| [link.text.strip, link[:href]] }).to eq([['A', '#a'], ['B', '#b'], ['C', '#c']])
  end

  it 'keeps a <wbr> a void element' do
    html = "<p>#{'Text. ' * 400}</p>" + %w[a b c].map { |id| %(<h2 id="#{id}">#{id}</h2><p>up<wbr>.foo</p>) }.join

    result = described_class.new.auto_insert(html)

    expect(result).to include('<nav class="toc"')
    expect(result).to include('up<wbr>.foo')
    expect(result).not_to include('</wbr>')
  end

end
