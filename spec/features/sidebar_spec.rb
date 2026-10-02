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

  def wait_for_menu(source)
    deadline = Time.now + Capybara.default_max_wait_time
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

end
