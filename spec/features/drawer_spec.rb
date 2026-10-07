# The drawer behind the burger stands in for the header's sections and for the sidebar
# below $bp-sidebar. Its rows are the header's sections in the header's words, then the
# older versions. Learn, API and Older versions open one level, like the sidebar's
# nodes; nothing goes deeper. It carries no search: the header's is there at every width.
describe 'the drawer', type: :feature, js: true, driver: :selenium_phone do

  ROWS = ['Learn', 'API', 'Demo', 'Changes', 'Support', 'GitHub', 'Older versions'].freeze

  def open_drawer
    find('.guide--head a[href="/menu/narrow"]').click
    expect(page).to have_css('up-drawer .menu .menu--nodes')
    wait_for_drawer_to_settle
  end

  def open_drawer_on(path)
    visit path
    open_drawer
  end

  # The top-level rows, and what each one opens.
  def rows
    page.evaluate_script(<<~JS)
      [...document.querySelectorAll('up-drawer .menu--nodes > .node')].map((node) => ({
        title: node.querySelector(':scope > .node--self .node--title').textContent.trim(),
        href: node.querySelector(':scope > .node--self').getAttribute('href'),
        expanded: node.matches('.-expanded'),
        children: [...node.querySelectorAll(':scope > .node')].map((child) => ({
          title: child.querySelector('.node--title').textContent.trim(),
          href: child.querySelector('.node--self').getAttribute('href'),
          grandchildren: child.querySelectorAll('.node').length,
        })),
      }))
    JS
  end

  def row(title)
    rows.find { |row| row['title'] == title }
  end

  def expand(title)
    within('up-drawer') do
      find('.menu--nodes > .node', text: title, match: :first).find(':scope > .node--toggle, :scope > button.node--self', match: :first).click
    end
  end

  def current_in_drawer
    page.evaluate_script("[...document.querySelectorAll('up-drawer .node--self.up-current')].map((link) => link.textContent.trim())")
  end

  it 'has the header’s sections as its rows, in the same words and order, and the older versions last' do
    open_drawer_on '/support'

    expect(rows.map { |row| row['title'] }).to eq(ROWS)
  end

  it 'keeps GitHub as a row of words, though the header shows only its icon' do
    open_drawer_on '/support'

    expect(page).to have_css('up-drawer .node--self[href="https://github.com/unpoly/unpoly"]', text: 'GitHub')
  end

  it 'leads from the Learn and API rows to their hubs' do
    open_drawer_on '/support'

    expect(row('Learn')['href']).to eq('/learn')
    expect(row('API')['href']).to eq('/api')
  end

  it 'opens Learn to every chapter, Getting started included' do
    open_drawer_on '/support'
    expand('Learn')

    toc = Unpoly::Guide.current.toc
    expect(row('Learn')['children'].map { |child| child['title'] }).to eq(toc.learn.topics.map(&:menu_title))
    expect(page).to have_css('up-drawer a', text: 'Getting started')
  end

  it 'opens API to its modules and Formats, each one plain row' do
    open_drawer_on '/support'
    expand('API')

    toc = Unpoly::Guide.current.toc
    children = row('API')['children']

    expect(children.map { |child| child['href'] }).to eq(toc.api.topics.map(&:menu_path))
    expect(children.last).to include('title' => 'Formats', 'href' => '/formats')
    expect(children.map { |child| child['grandchildren'] }.uniq).to eq([0])
    expect(page).to have_no_css('up-drawer .menu--caption', visible: :all)
  end

  it 'opens Older versions when its label is tapped' do
    open_drawer_on '/support'

    within('up-drawer') { find('.menu--nodes > .node > button.node--self', text: /older versions/i).click }

    expect(row('Older versions')['expanded']).to be(true)
    expect(page).to have_css('up-drawer a[href="https://v2.unpoly.com"]')
  end

  describe 'from the keyboard' do

    def focused
      page.evaluate_script("(function() { let e = document.activeElement; return [e.tagName, e.getAttribute('aria-label') || e.textContent.trim(), e.getAttribute('href'), e.getAttribute('aria-expanded')] })()")
    end

    # Presses Tab until the predicate holds for the focused element, or gives up.
    def tab_to(limit: 40)
      limit.times do
        page.send_keys(:tab)
        return focused if yield(focused)
      end
      raise 'Tab never reached the element'
    end

    it 'reaches and opens Older versions, and the versions below it' do
      open_drawer_on '/support'

      tab_to { |tag, label| tag == 'BUTTON' && label =~ /older versions/i }
      page.send_keys(:enter)

      expect(row('Older versions')['expanded']).to be(true)
      expect(focused.last).to eq('true')
      expect(tab_to { |_, _, href| href }[2]).to eq('https://v2.unpoly.com')
    end

    it 'opens Learn and reaches its first chapter' do
      open_drawer_on '/support'

      tab_to { |tag, label| tag == 'BUTTON' && label == 'Expand Learn' }
      page.send_keys(:space)

      expect(row('Learn')['expanded']).to be(true)
      expect(focused.last).to eq('true')
      expect(tab_to { |_, _, href| href && href != '/learn' }[2]).to eq('/start/overview')
    end

  end

  it 'opens Older versions to the earlier majors' do
    open_drawer_on '/support'
    expand('Older versions')

    expect(row('Older versions')['children'].map { |child| [child['title'], child['href']] }).to eq(
      [['Unpoly 2.x', 'https://v2.unpoly.com'], ['Unpoly 1.x', 'https://v1.unpoly.com']]
    )
  end

  it 'leaves Installation and the search to the places they belong' do
    open_drawer_on '/support'

    within('up-drawer') do
      expect(page).to have_no_text('Installation')
      expect(page).to have_no_css('input, .search-pill')
    end
  end

  it 'uses the whole drawer, not the sidebar’s width' do
    open_drawer_on '/support'

    widths = page.evaluate_script(<<~JS)
      [document.querySelector('up-drawer .menu').getBoundingClientRect().width,
       document.querySelector('up-drawer-content').getBoundingClientRect().width]
    JS
    expect(widths.first).to be >= widths.last - 1
  end

  describe 'marking where the reader is' do

    it 'opens API and marks the module on a module page' do
      open_drawer_on '/up.link'

      expect(current_in_drawer).to eq(['API', 'up.link'])
      expect(row('API')['expanded']).to be(true)
      expect(row('Learn')['expanded']).to be(false)
    end

    it 'opens Learn and marks the chapter on a page further down that chapter' do
      open_drawer_on '/targeting-fragments'

      expect(current_in_drawer).to eq(['Learn', 'Advanced rendering'])
      expect(row('Learn')['expanded']).to be(true)
      expect(row('API')['expanded']).to be(false)
    end

    it 'opens Learn and marks the chapter on its overview' do
      open_drawer_on '/links'

      expect(current_in_drawer).to eq(['Learn', 'Links'])
      expect(row('Learn')['expanded']).to be(true)
    end

    it 'opens API and marks Formats on a format page' do
      open_drawer_on '/relaxed-json'

      expect(current_in_drawer).to eq(['API', 'Formats'])
      expect(row('API')['expanded']).to be(true)
    end

    it 'marks Support on the support page and opens nothing' do
      open_drawer_on '/support'

      expect(current_in_drawer).to eq(['Support'])
      expect(rows.select { |row| row['expanded'] }).to eq([])
    end

  end

end
