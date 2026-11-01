require 'nokogiri'

# What search engines learn about a page beyond its text: whether to list it
# (indexable? in config.rb).
describe 'search engines', type: :feature do

  def head_of(path)
    visit path
    Nokogiri::HTML(page.html).at('head')
  end

  def robots_of(path)
    head_of(path).at('meta[name=robots]')&.[]('content')
  end

  describe 'the menus' do
    it 'asks search engines to follow their links, but not to list them' do
      %w[/learn/menu /api/menu /changes/menu /menu/narrow /version_choice].each do |path|
        expect(robots_of(path)).to eq('noindex, follow'), "#{path} should be noindex, follow"
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

end
