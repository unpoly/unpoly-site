describe Unpoly::Guide::Icon do

  it 'hides a decorative icon from screen readers and the Markdown twins' do
    expect(described_class.html('search', class: 'search-pill--icon')).to eq('<i class="fa fa-search search-pill--icon" aria-hidden="true"></i>')
  end

  it 'names an icon with a label, as an image' do
    expect(described_class.html('flask', label: 'Experimental')).to eq('<i class="fa fa-flask" role="img" aria-label="Experimental" title="Experimental"></i>')
  end

  it 'escapes the label' do
    expect(described_class.html('x', label: '"<b>"')).to include('aria-label="&quot;&lt;b&gt;&quot;"')
  end

end
