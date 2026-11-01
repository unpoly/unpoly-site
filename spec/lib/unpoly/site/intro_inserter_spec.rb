describe Unpoly::Site::IntroInserter do

  def insert(html)
    Nokogiri::HTML5.fragment(described_class.insert(html, '<div class="intro">Intro</div>'))
  end

  it 'places the block after the lead paragraphs, before the first heading' do
    doc = insert('<p>Lead.</p><p>More lead.</p><h2 id="a">A</h2><p>Text.</p>')

    expect(doc.element_children.map(&:name)).to eq(%w[p p div h2 p])
  end

  # An admonition's title used to be an <h4>, which put the block inside the box.
  it 'places the block before an admonition, not inside it' do
    doc = insert(%(<p>Lead.</p><blockquote class="admonition -tip" role="note"><p class="admonition--title">Tip</p><p>Text.</p></blockquote><h2 id="a">A</h2>))

    expect(doc.element_children.map(&:name)).to eq(%w[p div blockquote h2])
    expect(doc.at_css('blockquote .intro')).to be_nil
  end

  it 'appends the block to a document without a heading' do
    doc = insert('<p>Lead.</p>')

    expect(doc.element_children.map(&:name)).to eq(%w[p div])
  end

end
