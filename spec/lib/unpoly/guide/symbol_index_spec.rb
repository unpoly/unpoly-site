describe Unpoly::Guide::SymbolIndex do

  let(:repository) { Unpoly::Guide.current }
  let(:index) { repository.symbol_index }
  let(:symbols) { index.symbols }

  def entry(name)
    symbols.detect { |symbol| symbol[0] == name }
  end

  it 'lists a selector with its path and an HTML badge' do
    expect(entry('[up-follow]')).to eq(['[up-follow]', '/up-follow', 'HTML'])
  end

  it 'gives a function its signature to display, since the name alone is not the whole story' do
    name, path, kind, title = entry('up.render')

    expect(path).to eq('/up.render')
    expect(kind).to eq('JS')
    expect(title).to start_with('up.render(')
  end

  it 'badges an event as EVENT rather than JS' do
    expect(entry('up:link:follow')[2]).to eq('EVENT')
  end

  it 'badges a configuration object as CONFIG' do
    expect(entry('up.form.config')[2]).to eq('CONFIG')
  end

  it 'lists modules, whose page title never contains their name' do
    name, path, kind, title = entry('up.link')

    expect(path).to eq('/up.link')
    expect(kind).to eq('API')
    expect(title).to be_present
    expect(title).not_to include('up.link')
  end

  it 'does not list guide pages, which Pagefind finds by their prose' do
    paths = symbols.map { |symbol| symbol[1] }

    expect(paths).not_to include('/loading-state')
  end

  it "lists a selector's attributes, pointing at their anchor and naming their owner" do
    name, path, kind, _title, owner = entry('[up-watch-delay]')

    expect(path).to end_with('#up-watch-delay')
    expect(kind).to eq('HTML')
    expect(owner).to match(/\A\[up-\w/)
  end

  it 'does not list the options of a function, which would bury the features themselves' do
    owners = symbols.filter_map { |symbol| symbol[4] }.reject { |owner| owner == 0 }

    expect(owners).to be_present
    expect(owners).to all(satisfy { |owner| owner.start_with?('[') || owner.include?('config') })
  end

  it 'does not repeat a selector as an attribute of itself' do
    watch = symbols.select { |symbol| symbol[0] == '[up-watch]' }

    expect(watch.size).to eq(1)
    expect(watch.first[1]).to eq('/up-watch')
  end

  it 'marks deprecated symbols so they can be ranked last' do
    deprecated = repository.features.detect { |feature| feature.guide_page? && feature.deprecated? }

    expect(entry(deprecated.name).last).to eq(1)
  end

  it 'omits trailing empty fields, so a plain symbol costs three of them' do
    expect(symbols.map(&:size).min).to eq(3)
    expect(symbols).to all(satisfy { |symbol| symbol.size <= 6 })
  end

  it 'renders as JSON with a version, so the popup can refuse a format it does not know' do
    parsed = JSON.parse(index.to_json)

    expect(parsed['version']).to eq(described_class::VERSION)
    expect(parsed['symbols'].size).to eq(symbols.size)
  end

end
