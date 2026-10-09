# Below $bp-sidebar the drawer lists only chapters, so a chapter overview lists every
# page of its chapter. Above it, the sidebar does that job and the index is hidden.
# Module pages need no index: they list every feature under "Features".
describe 'the children index', type: :feature, js: true do

  def index_links
    all('.children-index a.children-index--link').map { |link| URI.parse(link[:href]).path }
  end

  describe 'on a phone', driver: :selenium_phone do
    it 'lists every page of a chapter on its overview' do
      visit '/links'

      chapter = Unpoly::Guide.current.toc.learn.topics.find { |topic| topic.menu_path == '/links' }
      expect(index_links).to eq(chapter.menu_children.map(&:menu_path))
    end

    it 'is titled by a heading that the page contents leave out' do
      visit '/loading-state'

      expect(page).to have_css('.children-index h2[data-toc-ignore]', text: 'In this chapter')
      expect(page).to have_css('.toc')
      within('.toc') { expect(page).to have_no_text('In this chapter') }
    end

    it 'is left out of the search index' do
      visit '/links'

      expect(page).to have_css('.children-index[data-pagefind-ignore]')
    end

    it 'is not on a page further down a chapter' do
      visit '/following-links'

      expect(page).to have_no_css('.children-index', visible: :all)
    end

    it 'is not on a module page, which lists all its features already' do
      visit '/up.link'

      expect(page).to have_no_css('.children-index', visible: :all)
      expect(page).to have_css('#features')
    end
  end

  it 'is hidden where the sidebar is shown' do
    visit '/links'

    expect(page).to have_css('.children-index', visible: :hidden)
  end

end
