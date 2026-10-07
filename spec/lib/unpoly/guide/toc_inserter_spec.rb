describe Unpoly::Guide::TOCInserter do

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
