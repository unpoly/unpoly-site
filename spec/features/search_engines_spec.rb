require 'nokogiri'

# What search engines learn about a page beyond its text: whether to list it, and the one
# URL to list it under (indexable? and canonical_url in config.rb).
describe 'search engines', type: :feature do

  def head_of(path)
    visit path
    Nokogiri::HTML(page.html).at('head')
  end

  def robots_of(path)
    head_of(path).at('meta[name=robots]')&.[]('content')
  end

  def canonical_of(path)
    links = head_of(path).css('link[rel=canonical]')
    expect(links.size).to be <= 1, "#{path} has #{links.size} canonical links"
    links.first&.[]('href')
  end

  let(:release_path) { "/changes/#{Unpoly::Site.current.releases.first.version}" }

  describe 'the menus' do
    it 'asks search engines to follow their links, but not to list them' do
      %w[/learn/menu /api/menu /changes/menu /menu/narrow /version_choice].each do |path|
        expect(robots_of(path)).to eq('noindex, follow'), "#{path} should be noindex, follow"
        expect(canonical_of(path)).to be_nil, "#{path} should have no canonical link"
      end
    end
  end

  it 'lets search engines list a documentation page' do
    expect(robots_of('/api/up-defer')).to be_nil
    expect(robots_of('/learn/lazy-loading')).to be_nil
  end

  it 'keeps the parser fixtures out of search engines' do
    expect(robots_of('/api/test.module.function')).to eq('noindex, follow')
    expect(robots_of('/learn/test.page')).to eq('noindex, follow')
  end

  describe 'the canonical link' do
    it 'names the production URL without a trailing slash' do
      expect(canonical_of('/api/up-defer')).to eq('https://unpoly.com/api/up-defer')
      expect(canonical_of('/api/up-defer/')).to eq('https://unpoly.com/api/up-defer')
      expect(canonical_of('/learn/lazy-loading')).to eq('https://unpoly.com/learn/lazy-loading')
      expect(canonical_of('/api/up:link:follow')).to eq('https://unpoly.com/api/up:link:follow')
      expect(canonical_of(release_path)).to eq("https://unpoly.com#{release_path}")
    end

    it 'names the hubs and the landing page' do
      expect(canonical_of('/')).to eq('https://unpoly.com/')
      expect(canonical_of('/learn')).to eq('https://unpoly.com/learn')
      expect(canonical_of('/api')).to eq('https://unpoly.com/api')
    end
  end

end
