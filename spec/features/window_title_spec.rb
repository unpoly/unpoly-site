# The <title> is what a search engine shows as a result's headline, so it says what the
# page is: an API symbol names its kind, a documentation page its area. See window_title
# in config.rb. The site search does not read it (search_spec.rb).
describe 'window title', type: :feature do

  def title_of(path)
    visit path
    page.title
  end

  it 'names the kind of an API feature' do
    expect(title_of('/api/up-defer')).to eq('[up-defer] (HTML attribute) - Unpoly API')
    expect(title_of('/api/up.render')).to eq('up.render() (JavaScript function) - Unpoly API')
  end

  it 'names a namespace a JavaScript namespace' do
    expect(title_of('/api/up.link')).to eq('up.link (JavaScript namespace) - Unpoly API')
  end

  it 'names a class a JavaScript class' do
    expect(title_of('/api/up.RenderJob')).to eq('up.RenderJob (JavaScript class) - Unpoly API')
  end

  it 'names the area of a guide page in the API area, but no kind' do
    expect(title_of('/api/url-patterns')).to match(/\A[^()]+ - Unpoly API\z/)
    expect(title_of('/api/formats')).to eq('Formats - Unpoly API')
  end

  it 'names the area of a Learn page' do
    expect(title_of('/learn/lazy-loading')).to eq('Lazy loading content - Learn Unpoly')
  end

  it 'names the area of a Getting started page' do
    expect(title_of('/learn/start/links')).to match(/\A[^()]+ - Learn Unpoly\z/)
  end

  it 'gives the hubs their own titles, without a suffix' do
    expect(title_of('/learn')).to eq('Learn Unpoly')
    expect(title_of('/api')).to eq('Unpoly API reference')
  end

  it 'names only the site on pages outside the documentation' do
    expect(title_of('/changes')).to eq('Changes - Unpoly')
    expect(title_of('/privacy')).to eq('Privacy policy - Unpoly')
  end

  it 'tells what Unpoly is on the landing page' do
    expect(title_of('/')).to eq('Unpoly - Build a complete frontend in HTML')
  end

end
