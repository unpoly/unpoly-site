# Below $bp-sidebar the drawer lists only chapters and modules, so a chapter overview
# and a module page list everything below them. Above it, the sidebar does that job and
# the index is hidden.
describe 'the children index', type: :feature, js: true do

  def index_links
    all('.children-index a').map { |link| URI.parse(link[:href]).path }
  end

  describe 'on a phone', driver: :selenium_phone do
    it 'lists every page of a chapter on its overview' do
      visit '/links'

      chapter = Unpoly::Guide.current.toc.learn.topics.find { |topic| topic.menu_path == '/links' }
      expect(index_links).to eq(chapter.menu_children.map(&:menu_path))
    end

    it 'lists every feature of a module on its page, in its groups' do
      visit '/up.link'

      expect(page).to have_css('.children-index--group', text: /html/i)
      expect(index_links).to include('/up-follow', '/up.follow', '/up:link:follow')
    end

    it 'is left out of the search index' do
      visit '/links'

      expect(page).to have_css('.children-index[data-pagefind-ignore]')
    end

    it 'is not on a page further down a chapter' do
      visit '/following-links'

      expect(page).to have_no_css('.children-index', visible: :all)
    end
  end

  it 'is hidden where the sidebar is shown' do
    visit '/links'

    expect(page).to have_css('.children-index', visible: :hidden)
  end

end
