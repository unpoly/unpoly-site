# The sidebar menu is loaded once per section and then kept while the reader stays in
# that section, so it keeps its expansion and scroll position and costs no request.
# Crossing into another section swaps it for that section's menu.
describe 'the sidebar menu', type: :feature, js: true do

  def menu_source
    page.evaluate_script(<<~JS)
      (function() {
        let menu = document.querySelector('.guide--menu .menu--nodes')?.closest('.menu')
        return menu && new URL(up.fragment.source(menu), location.href).pathname
      })()
    JS
  end

  # The API menu is a ~375 KB fragment that the development server takes ~4 seconds
  # to render on a busy machine (measured 2026-10-06), and some examples hold its
  # request back on top, so its wait is longer than Capybara's.
  def wait_for_menu(source)
    deadline = Time.now + 3 * Capybara.default_max_wait_time
    sleep 0.1 until menu_source == source || Time.now > deadline
    expect(menu_source).to eq(source)
  end

  # Tags the loaded menu element and counts requests for menus from here on.
  def watch_menu
    page.execute_script(<<~JS)
      document.querySelector('.guide--menu .menu').specMark = 'kept'
      window.menuRequests = 0
      up.on('up:request:load', (event) => { if (/\\/menu$/.test(event.request.url)) window.menuRequests++ })
    JS
  end

  def menu_kept?
    page.evaluate_script("document.querySelector('.guide--menu .menu').specMark") == 'kept'
  end

  def menu_requests
    page.evaluate_script('window.menuRequests')
  end

  def menu_scroll_top
    page.evaluate_script("document.querySelector('.guide--menu').scrollTop")
  end

  def follow_link_to(path)
    page.execute_script(<<~JS, path)
      let link = document.createElement('a')
      link.href = arguments[0]
      link.id = 'sidebar-spec-link'
      link.textContent = 'Go'
      document.querySelector('.guide--content').prepend(link)
    JS
    find('#sidebar-spec-link').click
    expect(page).to have_current_path(path)
  end

  it 'loads the menu of the page’s section after the page itself' do
    visit '/targeting-fragments'

    wait_for_menu('/learn/menu')
  end

  it 'keeps the loaded menu and its scroll position while the reader stays in the section' do
    visit '/up.render'
    wait_for_menu('/api/menu')
    page.execute_script("document.querySelector('.guide--menu').scrollTop += 40")
    scroll_top = menu_scroll_top
    watch_menu

    within('.guide--menu') { click_link 'up.navigate()' }

    expect(page).to have_current_path('/up.navigate')
    expect(page).to have_css('h1', text: 'up.navigate')
    expect(menu_kept?).to be(true)
    expect(menu_requests).to eq(0)
    expect(menu_scroll_top).to eq(scroll_top)
  end

  # Holds back every menu request, so that the reader's next click lands while it is in
  # flight. Applies to the documents loaded within the block.
  def holding_back_menu_requests
    script = page.driver.browser.execute_cdp('Page.addScriptToEvaluateOnNewDocument', source: <<~JS)
      const open = XMLHttpRequest.prototype.open
      const send = XMLHttpRequest.prototype.send
      XMLHttpRequest.prototype.open = function(method, url, ...rest) {
        this.specURL = url
        return open.call(this, method, url, ...rest)
      }
      XMLHttpRequest.prototype.send = function(...args) {
        if (/\\/menu$/.test(this.specURL)) setTimeout(() => send.apply(this, args), 1500)
        else send.apply(this, args)
      }
    JS
    yield
  ensure
    page.driver.browser.execute_cdp('Page.removeScriptToEvaluateOnNewDocument', identifier: script['identifier'])
  end

  def expect_menu_loading
    expect(page).to have_css('.guide--menu-placeholder.up-loading', visible: :all)
  end

  it 'still loads the menu when the reader moves on within the section before it has loaded' do
    holding_back_menu_requests do
      visit '/up.render'
      expect_menu_loading

      follow_link_to('/api')

      wait_for_menu('/api/menu')
    end
  end

  it 'still loads the menu when a double click renders a page twice' do
    # Both clicks are answered by the same response, so the page renders twice. The
    # second render aborts the menu request that the first render started.
    visit '/targeting-fragments'
    wait_for_menu('/learn/menu')

    page.execute_script(<<~JS)
      let link = document.createElement('a')
      link.href = '/api'
      document.querySelector('.guide--content').prepend(link)
      up.follow(link)
      up.follow(link)
    JS

    expect(page).to have_current_path('/api')
    wait_for_menu('/api/menu')
  end

  it 'loads the menu on the next page of the section after a load failed' do
    page.driver.browser.execute_cdp('Network.enable')
    page.driver.browser.execute_cdp('Network.setBlockedURLs', urls: ['*/api/menu'])
    begin
      visit '/up.render'
      expect(page).to have_css('.guide--menu-placeholder:not(.up-loading)', visible: :all)
      expect(menu_source).to be_nil
    ensure
      page.driver.browser.execute_cdp('Network.setBlockedURLs', urls: [])
    end

    follow_link_to('/api')

    wait_for_menu('/api/menu')
  end

  it 'swaps in the other section’s menu when the reader crosses into it' do
    visit '/targeting-fragments'
    wait_for_menu('/learn/menu')

    follow_link_to('/up.render')

    wait_for_menu('/api/menu')
    expect(page).to have_css('.guide--menu .up-current', text: 'up.render()')
  end

  it 'follows the location in a kept menu: it marks the new page and expands only its chapter' do
    visit '/targeting-fragments'
    wait_for_menu('/learn/menu')
    watch_menu

    follow_link_to('/following-links')

    within('.guide--menu') do
      expect(page).to have_css('.up-current', text: 'Following links')
      expect(page).to have_css('.node.-expanded', text: 'Links')
      expect(page).to have_no_css('.node.-expanded', text: 'Advanced rendering')
    end
    expect(menu_kept?).to be(true)
    expect(menu_requests).to eq(0)
  end

  it 'follows history in a kept menu' do
    visit '/targeting-fragments'
    wait_for_menu('/learn/menu')
    follow_link_to('/following-links')
    expect(page).to have_css('.guide--menu .up-current', text: 'Following links')

    page.go_back

    expect(page).to have_current_path('/targeting-fragments')
    expect(page).to have_css('.guide--menu .up-current', text: 'Targeting fragments')
    expect(page).to have_css('.guide--menu .node.-expanded', text: 'Advanced rendering')
  end

  it 'opens a node from the keyboard, through a real button that says whether it is open' do
    visit '/up.render'
    wait_for_menu('/api/menu')

    toggle = find('.guide--menu button.node--toggle[aria-label="Expand up.form"]')
    expect(toggle[:'aria-expanded']).to eq('false')

    toggle.send_keys(:enter)

    expect(page).to have_css('.guide--menu button.node--toggle[aria-label="Expand up.form"][aria-expanded="true"]')
    within('.guide--menu') { expect(page).to have_link('up.submit()') }
  end

  describe 'clicking a node’s icon' do

    # Every point of a visible icon must hit the node's toggle, never the link under it.
    ICON_COVERAGE_JS = <<~JS
      (function(scope) {
        let misses = []
        for (let toggle of document.querySelectorAll(scope + ' .node--toggle')) {
          let icon = toggle.parentElement.querySelector(':scope > .node--self > .node--collapser')
          let r = icon.getBoundingClientRect()
          if (!r.width) continue
          let points = [[r.left + 0.5, r.top + 0.5], [r.right - 0.5, r.top + 0.5], [r.left + 0.5, r.bottom - 0.5], [r.right - 0.5, r.bottom - 0.5]]
          for (let [x, y] of points) {
            if (!toggle.contains(document.elementFromPoint(x, y))) misses.push(toggle.getAttribute('aria-label'))
          }
        }
        return misses
      })
    JS

    def icon_misses(scope)
      page.evaluate_script("#{ICON_COVERAGE_JS}(#{scope.to_json})")
    end

    # A real mouse click just inside the icon's lower left corner.
    def click_icon_corner(icon)
      size = icon.native.size
      page.driver.browser.action.move_to(icon.native, -(size.width / 2) + 1, (size.height / 2) - 1).click.perform
    end

    it 'opens the node and stays on the page, even at the icon’s lower edge' do
      visit '/targeting-fragments'
      wait_for_menu('/learn/menu')

      expect(icon_misses('.guide--menu')).to eq([])

      click_icon_corner(find('.guide--menu a.node--self[href="/links"] .node--collapser'))

      expect(page).to have_css('.guide--menu button.node--toggle[aria-label="Expand Links"][aria-expanded="true"]')
      expect(page).to have_current_path('/targeting-fragments')
    end

    it 'opens a drawer row and keeps the drawer, even at the icon’s lower edge', driver: :selenium_phone do
      visit '/support'
      find('.guide--head a[href="/menu/narrow"]').click
      expect(page).to have_css('up-drawer .menu--nodes')
      # The drawer slides in; measure once it has arrived.
      Timeout.timeout(Capybara.default_max_wait_time) do
        sleep 0.05 until page.evaluate_script("document.querySelector('up-drawer-box').getBoundingClientRect().right <= window.innerWidth + 0.5")
      end

      expect(icon_misses('up-drawer')).to eq([])

      click_icon_corner(find('up-drawer a.node--self[href="/learn"] .node--collapser'))

      expect(page).to have_css('up-drawer button.node--toggle[aria-label="Expand Learn"][aria-expanded="true"]')
      expect(page).to have_current_path('/support')
    end

  end

  it 'does not try to scroll the hidden sidebar on a phone', driver: :selenium_phone do
    errors = page.driver.browser.execute_cdp('Page.addScriptToEvaluateOnNewDocument', source: <<~JS)
      window.specErrors = []
      window.addEventListener('error', (event) => window.specErrors.push(String(event.message)))
      window.addEventListener('unhandledrejection', (event) => window.specErrors.push(String(event.reason)))
    JS
    begin
      visit '/targeting-fragments'
      expect(page).to have_css('.guide--menu .menu--nodes', visible: :all)
      sleep 0.5 # the current node is revealed in a later task

      expect(page.evaluate_script('window.specErrors')).to eq([])
    ensure
      page.driver.browser.execute_cdp('Page.removeScriptToEvaluateOnNewDocument', identifier: errors['identifier'])
    end
  end


  describe 'a long label' do
    # Labels used to be cut off with an ellipsis; "Clicking non-interactive elements"
    # was cut at most window widths. They wrap now, tighter within a label than between
    # two rows, and the icon stays beside the first line.
    it 'wraps instead of being cut off, with its icon centred on the first line' do
      visit '/targeting-fragments'
      find('.guide--menu .node', text: 'Advanced rendering', match: :first)
      page.execute_script("document.querySelectorAll('.guide--menu .node').forEach((node) => node.classList.add('-expanded'))")

      label = page.evaluate_script(<<~JS)
        (function() {
          let rows = [...document.querySelectorAll('.guide--menu .node--self')]
          let row = rows.find((row) => row.textContent.trim() === 'Clicking non-interactive elements')
          let title = row.querySelector('.node--title')
          let range = document.createRange()
          range.selectNodeContents(title)
          let lines = [...new Set([...range.getClientRects()].map((rect) => Math.round(rect.top)))]
          let first = range.getClientRects()[0]
          let icon = row.querySelector('.node--collapser').getBoundingClientRect()
          let single = rows.find((row) => row.textContent.trim() === 'Target derivation')
          return {
            cut: title.scrollWidth > title.clientWidth,
            lines: lines.length,
            lineGap: lines[1] - lines[0],
            rowHeight: parseFloat(getComputedStyle(row).lineHeight),
            iconOffset: (icon.top + icon.height / 2) - (first.top + first.height / 2),
            singleRow: single.getBoundingClientRect().height,
          }
        })()
      JS

      expect(label['cut']).to be(false)
      expect(label['lines']).to eq(2)
      expect(label['lineGap']).to be < label['rowHeight']
      expect(label['iconOffset'].abs).to be <= 1
      # A one-line row is as tall as rows always were.
      expect(label['singleRow']).to be_within(0.5).of(label['rowHeight'])
    end
  end


  # Measured at several widths, since which labels wrap where depends on the width.
  { selenium_small_desktop: 1100, selenium: 1280, selenium_above_rail: 1350 }.each do |driver, window|
  it "never leaves a closing bracket, or a bare \"up\", alone on a line of a wrapped label at #{window}px", driver: driver do
    visit '/up.render'
    expect(page).to have_css('.guide--menu .menu--nodes')
    page.execute_script("document.querySelectorAll('.guide--menu .node').forEach((node) => node.classList.add('-expanded'))")

    labels = page.evaluate_script(<<~'JS')
      (function() {
        let titles = [...document.querySelectorAll('.guide--menu .node--title')].filter((title) => title.getClientRects().length)
        let lonely = []
        let bare = []
        let wrapped = 0
        for (let title of titles) {
          // Each line's text, from the position of every character.
          let lines = new Map()
          let walker = document.createTreeWalker(title, NodeFilter.SHOW_TEXT)
          for (let node; (node = walker.nextNode());) {
            for (let i = 0; i < node.length; i++) {
              let range = document.createRange()
              range.setStart(node, i)
              range.setEnd(node, i + 1)
              let rect = range.getClientRects()[0]
              if (!rect) continue
              let top = Math.round(rect.top)
              lines.set(top, (lines.get(top) || '') + node.data[i])
            }
          }
          if (lines.size > 1) wrapped++
          let texts = [...lines.values()].map((line) => line.trim())
          if (texts.some((line) => /^[)\]]/.test(line))) lonely.push(title.textContent.trim())
          if (lines.size > 1 && texts[0] === 'up') bare.push(title.textContent.trim())
        }
        return { wrapped, lonely, bare, emptyBreaks: document.querySelector('.guide--menu').innerHTML.includes('(<wbr>)') }
      })()
    JS

    expect(labels['wrapped']).to be > 0
    expect(labels['lonely']).to eq([])
    expect(labels['bare']).to eq([])
    expect(labels['emptyBreaks']).to be(false)
  end
  end

  it 'separates top-level nodes with a dotted line, only between two of them' do
    visit '/up.render'
    expect(page).to have_css('.guide--menu .menu--nodes')
    page.execute_script("document.querySelectorAll('.guide--menu .node').forEach((node) => node.classList.add('-expanded'))")

    lines = page.evaluate_script(<<~JS)
      (function() {
        let dotted = (node) => getComputedStyle(node).borderBottomStyle === 'dotted'
        let groups = [...document.querySelectorAll('.guide--menu .menu--nodes')].map((group) => {
          let nodes = [...group.querySelectorAll(':scope > .node')]
          return [nodes.length, nodes.filter(dotted).length, dotted(nodes[nodes.length - 1])]
        })
        let deeper = [...document.querySelectorAll('.guide--menu .node .node')].filter(dotted).length
        let first = document.querySelector('.guide--menu .menu--nodes > .node')
        let style = getComputedStyle(first)
        return { groups, deeper, style: [style.marginBottom, style.paddingBottom, style.borderBottomWidth, style.borderBottomColor] }
      })()
    JS

    lines['groups'].each do |count, dotted, last|
      expect(dotted).to eq(count - 1)
      expect(last).to be(false)
    end
    expect(lines['deeper']).to eq(0)
    expect(lines['style']).to eq(['5px', '5px', '1px', 'rgb(201, 197, 200)']) # $gray-400
  end

  it 'keeps a group label one short line on its rule' do
    visit '/up.render'
    expect(page).to have_css('.guide--menu .menu--nodes')

    height = page.evaluate_script("[...document.querySelectorAll('.guide--menu .node.-group > .node--self')].find((label) => label.getClientRects().length).getBoundingClientRect().height")

    expect(height).to eq(20)
  end


  # A chapter's overview is reached through the chapter's own row, but the menu also
  # lists it as the chapter's first row, so the reader sees where they are on it.
  describe 'the overview row of a chapter' do
    def current_rows
      page.evaluate_script("[...document.querySelectorAll('.guide--menu .node > .node > a.node--self.up-current')].map((link) => link.textContent.trim())")
    end

    it 'leads every chapter of Learn, named by the overview’s menu title' do
      visit '/links'
      expect(page).to have_css('.guide--menu .menu--nodes')

      Unpoly::Guide.current.toc.learn.topics.each do |topic|
        overview = topic.menu_overview or next
        first = page.evaluate_script(<<~JS, topic.menu_path)
          (function(path) {
            let chapter = [...document.querySelectorAll('.guide--menu .menu--nodes > .node')].find((node) => node.querySelector(':scope > a.node--self').getAttribute('href') === path)
            let link = chapter.querySelector(':scope > .node > a.node--self')
            return [link.getAttribute('href'), link.textContent.trim()]
          })(arguments[0])
        JS

        expect(first).to eq([overview.guide_path, overview.menu_title])
      end
    end

    it 'is the current row on the overview, also after navigating within the chapter and back' do
      visit '/links'
      expect(page).to have_css('.guide--menu .menu--nodes')
      expect(current_rows).to eq(['Overview'])

      find('.guide--menu a[href="/following-links"]').click
      expect(page).to have_current_path('/following-links')
      expect(page).to have_css('.guide--menu .node > .node > a.up-current', text: 'Following links')
      expect(current_rows).to eq(['Following links'])

      find('.guide--menu .node > .node > a.node--self', text: 'Overview').click
      expect(page).to have_current_path('/links')
      expect(page).to have_css('.guide--menu .node > .node > a.up-current', text: 'Overview')
      expect(current_rows).to eq(['Overview'])
    end
  end

end
