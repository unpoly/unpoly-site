# The drawer behind the burger stands in for the header's sections and for the sidebar
# below $bp-sidebar. It names the same sections as the header, goes one level deep
# (Learn's chapters, API's modules), lists the older versions last and carries no
# search: the header's search is there at every width.
describe 'the drawer', type: :feature, js: true, driver: :selenium_phone do

  def open_drawer
    find('.guide--head a[href="/menu/narrow"]').click
    expect(page).to have_css('up-drawer .menu .menu--nodes')
  end

  # The drawer's labels in order: section labels, and the entries below Learn and API.
  def drawer_entries
    page.evaluate_script(<<~JS)
      [...document.querySelectorAll('up-drawer .menu--nodes > .node')].map((node) => ({
        group: node.matches('.-group'),
        title: node.querySelector('.node--title').textContent.trim(),
        href: node.querySelector('a')?.getAttribute('href'),
      }))
    JS
  end

  before do
    visit '/up.render'
    open_drawer
  end

  it 'names the sections in the same words and order as the header' do
    header = %w[Learn API Demo Changes Support GitHub]
    titles = drawer_entries.map { |entry| entry['title'] }

    expect(titles & header).to eq(header)
  end

  it 'lists every Learn chapter and every API module, each linking to its first page' do
    toc = Unpoly::Guide.current.toc
    entries = drawer_entries
    learn = entries.index { |entry| entry['title'] == 'Learn' }
    api = entries.index { |entry| entry['title'] == 'API' }
    demo = entries.index { |entry| entry['title'] == 'Demo' }

    expect(entries[learn]['href']).to eq('/learn')
    expect(entries[api]['href']).to eq('/api')
    expect(entries[(learn + 1)...api].map { |entry| entry['title'] }).to eq(toc.learn.topics.map(&:menu_title))
    expect(entries[(api + 1)...demo].map { |entry| entry['href'] }).to eq(toc.api.topics.filter_map(&:menu_path))
  end

  it 'goes no deeper than chapters and modules' do
    within('up-drawer') do
      expect(page).to have_no_css('a[href="/up.render"]', visible: :all)
      expect(page).to have_no_css('a[href="/following-links"]', visible: :all)
      expect(page).to have_no_css('.node .node', visible: :all)
    end
  end

  it 'ends with the older versions' do
    entries = drawer_entries

    expect(entries.last(3).map { |entry| entry['title'] }).to eq(['Older versions', 'Unpoly 2.x', 'Unpoly 1.x'])
    expect(entries.last(2).map { |entry| entry['href'] }).to eq(['https://v2.unpoly.com', 'https://v1.unpoly.com'])
  end

  it 'leaves Installation and the search to the places they belong' do
    within('up-drawer') do
      expect(page).to have_no_text('Installation')
      expect(page).to have_no_css('input, button.search-trigger, .search-pill')
    end
  end

  describe 'marking where the reader is' do

    def current_in_drawer
      page.evaluate_script("[...document.querySelectorAll('up-drawer .node--self.up-current')].map((link) => link.textContent.trim())")
    end

    def open_drawer_on(path)
      visit path
      open_drawer
    end

    it 'marks API and the module on a module page' do
      open_drawer_on '/up.link'

      expect(current_in_drawer).to eq(['API', 'up.link'])
    end

    it 'marks Learn and the chapter on a page further down that chapter' do
      open_drawer_on '/targeting-fragments'

      expect(current_in_drawer).to eq(['Learn', 'Advanced rendering'])
    end

    it 'marks Support on the support page' do
      open_drawer_on '/support'

      expect(current_in_drawer).to eq(['Support'])
    end

  end

end
