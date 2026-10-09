describe 'search', type: :feature, js: true do

  # Pagefind indexes the *built* site, and these specs run against the preview server,
  # which writes no files. So the index is stubbed: what is under test is what the dialog
  # does with results, not Pagefind's ability to find them (spec/build has that).
  #
  # `results` is the list every query gets, or a hash of lists by query. The stub counts
  # its searches, and `held: true` keeps every answer back until the spec calls
  # release_pagefind.
  def stub_pagefind(results = [], held: false)
    page.execute_script(<<~JS)
      window.pagefindSearches = 0
      window.pagefindWaiting = []
      window.pagefindHeld = #{held}
      window.pagefind = {
        options: async () => {},
        search: (query) => {
          window.pagefindSearches++
          let table = #{results.to_json}
          let list = Array.isArray(table) ? table : (table[query] || [])
          let answer = { results: list.map((data) => ({ data: async () => data })) }
          if (!window.pagefindHeld) return Promise.resolve(answer)
          return new Promise((resolve) => window.pagefindWaiting.push(() => resolve(answer)))
        }
      }
    JS
  end

  # The dialog waits 5 seconds for a slow index before it says search is unavailable.
  # Specs about that path lower the wait instead of sitting through it. SEARCH is the
  # search's config (search_core.js), a global binding of the page's script.
  def shorten_pagefind_timeout(ms = 300)
    page.execute_script("SEARCH.pagefindTimeoutMs = #{ms}")
  end

  def release_pagefind
    page.execute_script('window.pagefindHeld = false; window.pagefindWaiting.forEach((resolve) => resolve()); window.pagefindWaiting = []')
  end

  def fulltext_page(url:, title:, badge:, sections: [], excerpt: nil, deprecated: false, hub: nil, overview: false)
    {
      url: url,
      excerpt: excerpt,
      meta: { title: title, badge: badge, deprecated: (deprecated ? 'true' : nil) }.compact,
      filters: { hub: (hub && [hub]), overview: (overview ? ['true'] : nil) }.compact,
      sub_results: sections.map do |section|
        { url: "#{url}##{section[:anchor]}", title: section[:title], excerpt: section[:excerpt] }
      end
    }
  end

  # Selenium types through a keyboard layout — on this machine "/" arrives as Shift+"&" —
  # so the key is dispatched by name instead. Everything the shortcut does afterwards
  # (the guard, opening, focusing) is the real thing.
  def press_slash(on: 'document.body')
    page.execute_script("#{on}.dispatchEvent(new KeyboardEvent('keydown', { key: '/', bubbles: true }))")
  end

  def open_search
    find('.search-pill', visible: :all).click
    expect(page).to have_css('up-modal.search-dialog .search-dialog--input:focus')
  end

  def fill_in_search(query)
    find('.search-dialog--input').set(query)
  end

  def search_for(query)
    open_search
    fill_in_search(query)
  end

  # The rows of the list, in order, without the sections beneath them.
  def rows
    page.evaluate_script(<<~JS)
      [...document.querySelectorAll('.search-dialog--hit:not(.-section)')].map((hit) => ({
        href: hit.getAttribute('href'),
        title: hit.querySelector('.search-dialog--title').textContent.trim(),
        badge: hit.querySelector('.search-dialog--badge')?.textContent.trim(),
        hub: hit.querySelector('.search-dialog--hub')?.textContent.trim(),
      }))
    JS
  end

  def search_open?
    page.evaluate_script("!!document.querySelector('up-modal.search-dialog')")
  end

  describe 'the dialog' do

    it 'opens from the header’s search as a modal overlay' do
      visit '/loading-state'
      stub_pagefind

      open_search

      expect(page.evaluate_script('up.layer.count')).to eq(2)
      expect(page.evaluate_script('up.layer.current.mode')).to eq('modal')
    end

    it 'opens with the / key, which the trigger advertises' do
      visit '/loading-state'
      stub_pagefind

      press_slash

      expect(page).to have_css('up-modal.search-dialog .search-dialog--input:focus')
    end

    it 'leaves / alone while the reader is typing in a field' do
      visit '/loading-state'
      stub_pagefind

      # Firefox's quick-find lives on this key and so does every text field, so the
      # shortcut only counts when nobody is writing.
      page.execute_script(<<~JS)
        const field = document.createElement('input')
        field.id = 'a-field'
        document.body.append(field)
        field.focus()
      JS
      press_slash(on: 'document.getElementById("a-field")')

      expect(search_open?).to be(false)
    end

    it 'closes with one Escape, even from the field, and gives focus back to what opened it' do
      visit '/loading-state'
      stub_pagefind
      open_search

      find('.search-dialog--input').send_keys(:escape)

      expect(page).to have_no_css('up-modal.search-dialog')
      expect(page).to have_css('.search-pill:focus', visible: :all)
    end

    it 'closes when the backdrop is clicked' do
      visit '/loading-state'
      stub_pagefind
      open_search

      # Clicked near the window's left edge, outside the dialog's box.
      page.driver.browser.action.move_to_location(5, 300).click.perform

      expect(page).to have_no_css('up-modal.search-dialog')
    end

    it 'keeps the sidebar, the column and the contents rail in place when it hides the page’s scrollbar', driver: :selenium_scrollbars do
      visit '/loading-state'
      expect(page.evaluate_script('window.innerWidth - document.documentElement.clientWidth')).to be > 0
      stub_pagefind
      frame = "['.guide--left', '.guide--content', '.guide--right .toc'].map((s) => { let r = document.querySelector(s).getBoundingClientRect(); return [r.left, r.width] }).flat()"
      before = page.evaluate_script(frame)

      open_search

      page.evaluate_script(frame).zip(before).each { |now, was| expect(now).to be_within(1).of(was) }
    end

    it 'restyles only its own modal' do
      visit '/support'
      find('a[href="/support/discussions"]').click
      expect(page).to have_css('up-modal:not(.search-dialog) up-modal-box')

      padding = page.evaluate_script("getComputedStyle(document.querySelector('up-modal up-modal-box')).paddingTop")
      expect(padding).not_to eq('0px')
    end

    it 'brings the last query back when reopened, selected, and runs it again' do
      visit '/loading-state'
      stub_pagefind([fulltext_page(url: '/overlays', title: 'Overlays', badge: 'Learn')])
      search_for('overlays')
      expect(page).to have_css('.search-dialog--hit')
      searches = page.evaluate_script('window.pagefindSearches')

      find('.search-dialog--input').send_keys(:escape)
      expect(page).to have_no_css('up-modal.search-dialog')
      open_search

      expect(find('.search-dialog--input').value).to eq('overlays')
      expect(page.evaluate_script("(function(i) { return [i.selectionStart, i.selectionEnd] })(document.querySelector('.search-dialog--input'))")).to eq([0, 8])
      expect(page).to have_css('.search-dialog--hit', text: 'Overlays')
      expect(page.evaluate_script('window.pagefindSearches')).to be > searches
    end

  end

  describe 'the list' do

    it 'lists the pages in the order they come in, once each, with the sections that matched' do
      visit '/loading-state'
      stub_pagefind([
        fulltext_page(url: '/up-follow/', title: '[up-follow]', badge: 'HTML',
          sections: [{ anchor: 'example', title: 'Example', excerpt: 'Follows a <mark>link</mark>.' }]),
        fulltext_page(url: '/overlays/', title: 'Overlays', badge: 'Learn'),
        fulltext_page(url: '/up-follow', title: '[up-follow]', badge: 'HTML'),
      ])
      search_for('follow')
      expect(page).to have_css('.search-dialog--hit', text: 'Overlays')

      expect(rows.map { |row| row['href'] }).to eq(['/up-follow', '/overlays'])
      expect(rows.first).to include('title' => '[up-follow]', 'badge' => 'HTML')
      expect(page).to have_css('.search-dialog--hit.-section', text: 'Example')
    end

    it 'shows twelve pages at most' do
      visit '/loading-state'
      stub_pagefind((1..15).map { |n| fulltext_page(url: "/other-#{n}", title: "Other #{n}", badge: 'Learn') })
      search_for('other')
      expect(page).to have_css('.search-dialog--hit', text: 'Other 1')

      expect(rows.size).to eq(12)
    end

    it 'swaps to new results only once the full text has answered' do
      visit '/loading-state'
      stub_pagefind({
        'follow' => [fulltext_page(url: '/up-follow', title: '[up-follow]', badge: 'HTML')],
        'render' => [fulltext_page(url: '/up.render', title: 'up.render([target], [options])', badge: 'JS')],
      })
      search_for('follow')
      expect(page).to have_css('.search-dialog--hit', text: '[up-follow]')

      page.execute_script('window.pagefindHeld = true')
      fill_in_search('render')
      sleep 0.6 # longer than the debounce, much shorter than the full-text timeout

      expect(page).to have_css('.search-dialog--hit', text: '[up-follow]')
      expect(page).to have_no_css('.search-dialog--hit', text: 'up.render(')

      release_pagefind

      expect(page).to have_css('.search-dialog--hit', text: 'up.render(')
      expect(page).to have_no_css('.search-dialog--hit', text: '[up-follow]')
    end

    it 'says that search is unavailable when the full text does not answer in time' do
      visit '/loading-state'
      stub_pagefind([fulltext_page(url: '/caching', title: 'Caching', badge: 'Learn')], held: true)
      shorten_pagefind_timeout
      search_for('caching')

      expect(page).to have_css('.search-dialog--empty', text: 'Search is unavailable right now.')
      expect(page).to have_no_css('.search-dialog--hit')
    end

    it 'replaces that message when the full text answers late' do
      visit '/loading-state'
      stub_pagefind([fulltext_page(url: '/caching', title: 'Caching', badge: 'Learn')], held: true)
      shorten_pagefind_timeout
      search_for('caching')
      expect(page).to have_css('.search-dialog--empty', text: 'Search is unavailable right now.')

      release_pagefind

      expect(page).to have_css('.search-dialog--hit', text: 'Caching')
      expect(page).to have_no_css('.search-dialog--empty')
    end

    it 'says that search is unavailable when the full text fails' do
      visit '/loading-state'
      page.execute_script("window.pagefind = { options: async () => {}, search: async () => { throw new Error('broken index') } }")
      search_for('caching')

      expect(page).to have_css('.search-dialog--empty', text: 'Search is unavailable right now.')
    end

    it 'strikes a page that is deprecated and moves it below the others' do
      deprecated = Unpoly::Guide.current.features.detect { |f| f.guide_page? && f.deprecated? && !f.guide_path.include?('#') }
      visit '/loading-state'
      stub_pagefind([
        fulltext_page(url: "#{deprecated.guide_path}/", title: deprecated.signature, badge: deprecated.short_kind, deprecated: true),
        fulltext_page(url: '/caching', title: 'Caching', badge: 'Learn'),
      ])
      search_for('qqzzxq')
      expect(page).to have_css('.search-dialog--hit', text: 'Caching')

      expect(rows.map { |row| row['href'] }).to eq(['/caching', deprecated.guide_path])
      expect(find(".search-dialog--hit[href='#{deprecated.guide_path}']")[:class]).to include('-deprecated')
    end

  end

  describe 'rows' do

    it 'marks what was typed in the title' do
      visit '/loading-state'
      stub_pagefind([fulltext_page(url: '/up.follow', title: 'up.follow(link, [options])', badge: 'JS')])
      search_for('up.follow')

      hit = find('.search-dialog--hit[href="/up.follow"]')
      expect(hit.find('.search-dialog--title')).to have_text('up.follow(link, [options])')
      expect(hit).to have_css('.search-dialog--title mark', text: 'up.follow')
    end

    it 'badges a row with the kind the index stores' do
      visit '/loading-state'
      stub_pagefind([fulltext_page(url: '/up:link:follow', title: 'up:link:follow', badge: 'EVENT')])
      search_for('up:link:follow')

      expect(find('.search-dialog--hit', match: :first)).to have_css('.search-dialog--badge', text: 'EVENT')
    end

    it 'sets every badge in a gutter of its own, so all titles start at one edge' do
      visit '/loading-state'
      stub_pagefind([
        fulltext_page(url: '/up-follow', title: '[up-follow]', badge: 'HTML'),
        fulltext_page(url: '/overlays', title: 'Overlays', badge: 'Learn'),
      ])
      search_for('follow')
      expect(page).to have_css('.search-dialog--hit', text: 'Overlays')

      lefts = page.evaluate_script("[...document.querySelectorAll('.search-dialog--hit:not(.-section) .search-dialog--title')].map((title) => Math.round(title.getBoundingClientRect().left))")
      expect(lefts.size).to be >= 2
      expect(lefts.uniq.size).to eq(1)
      expect(page).to have_css('.search-dialog--hit .search-dialog--gutter .search-dialog--badge', minimum: 2)
    end

    it 'tells API and Learn hits apart by color, and separates hits by a hairline and a gap' do
      visit '/loading-state'
      stub_pagefind([
        fulltext_page(url: '/up-follow', title: '[up-follow]', badge: 'HTML'),
        fulltext_page(url: '/overlays', title: 'Overlays', badge: 'Learn'),
      ])
      search_for('follow')
      expect(page).to have_css('.search-dialog--hit.-learn', text: 'Overlays')

      colors = page.evaluate_script(<<~JS)
        (function() {
          let color = (selector, property) => getComputedStyle(document.querySelector(selector))[property]
          let probe = (value) => { let div = document.createElement('div'); div.style.color = value; document.body.append(div); let c = getComputedStyle(div).color; div.remove(); return c }
          return {
            apiBadge: color('.search-dialog--hit.-api .search-dialog--badge', 'color'),
            apiBorder: color('.search-dialog--hit.-api .search-dialog--badge', 'borderTopColor'),
            apiBackground: color('.search-dialog--hit.-api .search-dialog--badge', 'backgroundColor'),
            learnBadge: color('.search-dialog--hit.-learn .search-dialog--badge', 'color'),
            red: probe('hsl(0, 86%, 54%)'),
            blue: probe('hsl(201, 67%, 43%)'),
            separator: getComputedStyle(document.querySelectorAll('.search-dialog--hit:not(.-section)')[1]).borderTopStyle,
            gap: getComputedStyle(document.querySelectorAll('.search-dialog--hit:not(.-section)')[1]).marginTop,
          }
        })()
      JS

      expect(colors['apiBadge']).to eq(colors['red'])
      expect(colors['apiBorder']).to eq(colors['red'])
      expect(colors['apiBackground']).to eq('rgba(0, 0, 0, 0)')
      expect(colors['learnBadge']).to eq(colors['blue'])
      expect(colors['separator']).to eq('solid')
      expect(colors['gap']).to eq('2px')
    end

    it 'names the hub a page belongs to beneath its title, and an overview by its title only' do
      visit '/loading-state'
      stub_pagefind([
        fulltext_page(url: '/start/links', title: 'Link to a fragment', badge: 'Learn', hub: 'Getting started'),
        fulltext_page(url: '/links', title: 'Links', badge: 'Learn', overview: true),
        fulltext_page(url: '/up.follow', title: 'up.follow(link, [options])', badge: 'JS', hub: 'up.link'),
      ])
      search_for('link to')
      expect(page).to have_css('.search-dialog--hit', text: 'up.follow')

      expect(rows.map { |row| row.values_at('title', 'hub') }).to eq([
        ['Link to a fragment', 'Getting started'],
        ['Links (overview)', nil],
        ['up.follow(link, [options])', 'up.link'],
      ])
    end

    it 'sets the hub small and gray beneath the title, also on a phone', driver: :selenium_phone do
      visit '/loading-state'
      stub_pagefind([fulltext_page(url: '/following-links', title: 'Following links', badge: 'Learn', hub: 'Links', excerpt: 'How to follow a <mark>link</mark>')])
      page.execute_script('openSearch()')
      fill_in_search('follow')
      expect(page).to have_css('.search-dialog--hub', text: 'Links')

      layout = page.evaluate_script(<<~JS)
        (function() {
          let box = (selector) => document.querySelector(selector).getBoundingClientRect()
          let style = (selector) => getComputedStyle(document.querySelector(selector))
          return {
            titleBottom: box('.search-dialog--title').bottom,
            titleLeft: box('.search-dialog--title').left,
            hubTop: box('.search-dialog--hub').top,
            hubLeft: box('.search-dialog--hub').left,
            hubBottom: box('.search-dialog--hub').bottom,
            excerptTop: box('.search-dialog--excerpt').top,
            hubSize: parseFloat(style('.search-dialog--hub').fontSize),
            excerptSize: parseFloat(style('.search-dialog--excerpt').fontSize),
            hubColor: style('.search-dialog--hub').color,
            titleColor: style('.search-dialog--title').color,
            overflow: document.documentElement.scrollWidth - document.documentElement.clientWidth,
          }
        })()
      JS

      expect(layout['hubTop']).to be >= layout['titleBottom'] - 1
      expect(layout['excerptTop']).to be >= layout['hubBottom'] - 1
      expect(layout['hubLeft']).to eq(layout['titleLeft'])
      expect(layout['hubSize']).to be <= layout['excerptSize']
      expect(layout['hubColor']).not_to eq(layout['titleColor'])
      expect(layout['overflow']).to eq(0)
    end

    it 'gives a Learn title a little weight next to the code rows' do
      visit '/loading-state'
      stub_pagefind([fulltext_page(url: '/overlays', title: 'Overlays', badge: 'Learn')])
      search_for('overlays')

      expect(page).to have_css('.search-dialog--hit.-learn .search-dialog--title', text: 'Overlays')
      weight = page.evaluate_script("getComputedStyle(document.querySelector('.search-dialog--hit.-learn .search-dialog--title')).fontWeight")
      expect(weight).to eq('500')
    end

  end

  describe 'for screen readers' do

    it 'is a modal dialog the framework traps focus in, with the field focused' do
      visit '/loading-state'
      stub_pagefind
      open_search

      expect(page).to have_css('up-modal.search-dialog up-modal-box[role="dialog"][aria-modal="true"][aria-label="Search the documentation"]')
      expect(page).to have_css('.search-dialog--input:focus')

      # Tab cycles inside the dialog, never back to the page behind it.
      5.times { page.send_keys(:tab) }
      expect(page.evaluate_script("!!document.activeElement.closest('up-modal.search-dialog')")).to be(true)
    end

    it 'points the field at the selected option and keeps everything but options out of the listbox' do
      visit '/loading-state'
      stub_pagefind([
        fulltext_page(url: '/up-follow', title: '[up-follow]', badge: 'HTML',
          sections: [{ anchor: 'example', title: 'Example', excerpt: 'Follows a link.' }]),
        fulltext_page(url: '/overlays', title: 'Overlays', badge: 'Learn'),
      ])
      search_for('follow')
      expect(page).to have_css('.search-dialog--hit.-selected')

      input = find('.search-dialog--input')
      expect(input['aria-activedescendant']).to eq(find('.search-dialog--hit.-selected')[:id])
      page.send_keys(:down)
      expect(input['aria-activedescendant']).to eq(find('.search-dialog--hit.-selected')[:id])

      expect(page.evaluate_script("[...document.querySelector('[role=listbox]').children].every((child) => child.getAttribute('role') === 'option')")).to be(true)
      # A section names its page for screen readers, which don't see it above.
      expect(find('.search-dialog--hit.-section').text(:all)).to start_with('[up-follow] — Example')
    end

    it 'announces how many results a search found, and when it found none' do
      visit '/loading-state'
      stub_pagefind({ 'overlays' => [fulltext_page(url: '/overlays', title: 'Overlays', badge: 'Learn')] })
      search_for('overlays')

      expect(page).to have_css('.search-dialog--status[role="status"][aria-live="polite"]', text: "1 result for 'overlays'", visible: :all)

      fill_in_search('zzzznothing')
      expect(page).to have_css('.search-dialog--status', text: 'No results', visible: :all)
      expect(page).to have_css('.search-dialog--empty', text: 'No results for zzzznothing')
      expect(page).to have_no_css('[role=listbox] .search-dialog--empty')
    end

  end

  describe 'the trigger' do

    it 'says that it opens a dialog, and that / opens it too' do
      visit '/loading-state'

      pill = find('.search-pill', visible: :all)
      expect(pill['aria-haspopup']).to eq('dialog')
      expect(pill['aria-keyshortcuts']).to eq('/')
      expect(pill['aria-label']).to eq('Search docs — opens the search dialog')
      expect(pill['title']).to eq('Press / to search')
    end

  end

  describe 'keyboard navigation' do

    it 'moves the selection with the arrow keys and opens it with Enter, closing the dialog' do
      visit '/loading-state'
      stub_pagefind([
        fulltext_page(url: '/up-follow', title: '[up-follow]', badge: 'HTML'),
        fulltext_page(url: '/overlays', title: 'Overlays', badge: 'Learn'),
      ])
      search_for('follow')
      expect(page).to have_css('.search-dialog--hit.-selected[href="/up-follow"]')

      page.send_keys(:down)
      expect(page).to have_css('.search-dialog--hit.-selected[href="/overlays"]')
      page.send_keys(:enter)

      expect(page).to have_current_path('/overlays')
      expect(page).to have_no_css('up-modal.search-dialog')
    end

  end

  describe 'empty state' do

    it 'says which query found nothing' do
      visit '/loading-state'
      stub_pagefind
      search_for('zzzznothingmatchesthis')

      expect(page).to have_css('.search-dialog--empty', text: 'No results for zzzznothingmatchesthis')
    end

    it 'points to the agent skill until the reader types' do
      visit '/loading-state'
      stub_pagefind
      open_search

      expect(page).to have_css('.search-dialog--tip', text: /\Atip your coding agent can search these docs locally with the Unpoly agent skill\z/i)
      expect(page).to have_css('.search-dialog--tip a[href="/skill"][up-layer="root"]')
      expect(page).to have_no_css('[role=listbox] .search-dialog--tip')

      fill_in_search('u')
      expect(page).to have_no_css('.search-dialog--tip')
      fill_in_search('')
      expect(page).to have_no_css('.search-dialog--tip')
    end

    it 'shows nothing at all before the query is long enough' do
      visit '/loading-state'
      stub_pagefind
      search_for('u')

      expect(page).to have_no_css('.search-dialog--hit')
      expect(page).to have_no_css('.search-dialog--empty')
    end

  end

  describe 'on a phone', driver: :selenium_phone do

    it 'keeps the trigger in the header' do
      visit '/loading-state'
      stub_pagefind

      open_search

      expect(page).to have_css('.search-dialog--input:focus')
    end

    it 'opens over the drawer, and a picked hit closes both' do
      visit '/'
      stub_pagefind([fulltext_page(url: '/up-follow', title: '[up-follow]', badge: 'HTML')])
      find('.guide--head a[href="/menu/narrow"]').click
      expect(page).to have_css('up-drawer .menu--nodes')

      press_slash
      expect(page).to have_css('up-modal.search-dialog .search-dialog--input')
      fill_in_search('up-follow')
      expect(page).to have_css('.search-dialog--hit')

      # Nothing (the drawer least of all) may cover the hit the reader taps.
      covered = page.evaluate_script(<<~JS)
        (function() {
          let hit = document.querySelector('.search-dialog--hit')
          let r = hit.getBoundingClientRect()
          let top = document.elementFromPoint(r.left + r.width / 2, r.top + r.height / 2)
          return !hit.contains(top)
        })()
      JS
      expect(covered).to be(false)
      expect(page.evaluate_script('up.layer.count')).to eq(3)

      find('.search-dialog--hit', match: :first).click

      expect(page).to have_current_path('/up-follow')
      expect(page.evaluate_script('up.layer.count')).to eq(1)
    end

  end

  # Not `js: true`: this group runs in the driver that executes no JavaScript at all,
  # which is the only honest way to test what a reader without it gets.
  describe 'without JavaScript', js: false do

    it 'leaves the trigger a working link to the reference' do
      visit '/loading-state'

      pill = find('.search-pill', visible: :all)

      expect(pill.tag_name).to eq('a')
      expect(pill[:href]).to end_with('/api')
    end

  end

end
