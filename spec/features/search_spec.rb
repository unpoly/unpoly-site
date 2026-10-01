describe 'search', type: :feature, js: true do

  # Pagefind indexes the *built* site, and these specs run against the preview server,
  # which writes no files. So the full-text half is stubbed with a fake index: what is
  # under test is what the popup does with results, not Pagefind's ability to find them.
  # The symbol sidecar is not stubbed — it is an ordinary page, so it is the real thing.
  def stub_pagefind(results = [])
    page.execute_script(<<~JS)
      window.pagefind = {
        options: async () => {},
        search: async () => ({
          results: #{results.to_json}.map((data) => ({ data: async () => data }))
        })
      }
    JS
  end

  def fulltext_page(url:, title:, badge:, sections: [])
    {
      url: url,
      meta: { title: title, badge: badge },
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
  end

  def fill_in_search(query)
    find('.search-popup--input').set(query)
  end

  def search_for(query)
    open_search
    fill_in_search(query)
  end

  describe 'opening and closing' do

    it 'opens from the header pill' do
      visit '/loading-state'
      stub_pagefind
      expect(page).to have_css('.search-popup', visible: false)

      open_search

      expect(page).to have_css('.search-popup--input:focus')
    end

    it 'opens with the / key, which the pill advertises' do
      visit '/loading-state'
      stub_pagefind

      press_slash

      expect(page).to have_css('.search-popup--input:focus')
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

      expect(page).to have_css('.search-popup', visible: false)
    end

    it 'closes with Escape and gives focus back to what opened it' do
      visit '/loading-state'
      stub_pagefind
      open_search

      page.send_keys(:escape)

      expect(page).to have_css('.search-popup', visible: false)
      expect(page).to have_css('.search-pill:focus', visible: :all)
    end

    it 'closes when the backdrop is clicked' do
      visit '/loading-state'
      stub_pagefind
      open_search

      # Clicked near its corner: the backdrop's own centre is behind the popup window.
      find('.search-popup--backdrop').click(x: 10, y: 10, offset: :top_left)

      expect(page).to have_css('.search-popup', visible: false)
    end

  end

  describe 'symbol results' do

    it 'finds a selector by name and badges it with its kind' do
      visit '/loading-state'
      stub_pagefind
      search_for('up-follow')

      hit = find('.search-popup--hit.-symbol', match: :first)
      expect(hit).to have_text('[up-follow]')
      expect(hit).to have_css('.search-popup--badge', text: 'HTML')
      expect(hit[:href]).to end_with('/up-follow')
    end

    it 'badges an event as EVENT rather than JS' do
      visit '/loading-state'
      stub_pagefind
      search_for('up:link:follow')

      expect(page).to have_css('.search-popup--hit.-symbol .search-popup--badge', text: 'EVENT')
    end

    it 'names the owner of an attribute, which means little on its own' do
      visit '/loading-state'
      stub_pagefind
      search_for('up-watch-delay')

      hit = find('.search-popup--hit.-symbol', match: :first)
      expect(hit).to have_css('.search-popup--owner', text: '[up-')
    end

    it 'ranks an exact match above the symbols that merely contain it' do
      visit '/loading-state'
      stub_pagefind
      search_for('up.render')

      expect(find('.search-popup--hit', match: :first)).to have_text('up.render')
    end

    it 'ranks deprecated symbols last and strikes them through' do
      visit '/loading-state'
      stub_pagefind
      deprecated = Unpoly::Guide.current.features.detect { |f| f.guide_page? && f.deprecated? }

      search_for(deprecated.name)

      hits = all('.search-popup--hit.-symbol')
      expect(hits.last).to have_text(deprecated.name)
      expect(hits.last[:class]).to include('-deprecated')
    end

  end

  describe 'full text results' do

    it 'lists a page with its matching sections beneath it' do
      visit '/loading-state'
      stub_pagefind([
        fulltext_page(
          url: '/overlays',
          title: 'Overlays',
          badge: 'Learn',
          sections: [{ anchor: 'layer-modes', title: 'Layer modes', excerpt: 'A <mark>modal</mark> covers the page.' }]
        )
      ])
      search_for('modal')

      expect(page).to have_css('.search-popup--hit.-page', text: 'Overlays')
      expect(page).to have_css('.search-popup--hit.-section', text: 'Layer modes')
      expect(page).to have_css('.search-popup--excerpt mark', text: 'modal')
    end

    it 'shows symbol hits above full text hits' do
      visit '/loading-state'
      stub_pagefind([fulltext_page(url: '/overlays', title: 'Overlays', badge: 'Learn')])
      search_for('up-follow')

      classes = all('.search-popup--hit').map { |hit| hit[:class] }
      expect(classes.first).to include('-symbol')
      expect(classes.last).to include('-page')
    end

    it 'gives a page the badge the index recorded for it' do
      visit '/loading-state'
      stub_pagefind([fulltext_page(url: '/overlays', title: 'Overlays', badge: 'Learn')])
      search_for('overlays')

      # The index records "Learn"; the shared .tag block renders every badge uppercase,
      # which the casing ruling allows for small labels.
      expect(page).to have_css('.search-popup--hit.-page .search-popup--badge', text: 'LEARN')
    end

  end

  describe 'keyboard navigation' do

    it 'moves the selection with the arrow keys and opens it with Enter' do
      visit '/loading-state'
      stub_pagefind
      search_for('up-follow')
      expect(page).to have_css('.search-popup--hit.-selected')

      page.send_keys(:down)
      target = URI.parse(find('.search-popup--hit.-selected')[:href]).path
      page.send_keys(:enter)

      expect(page).to have_current_path(target)
      expect(page).to have_css('.search-popup', visible: false)
    end

  end

  describe 'empty state' do

    it 'says which query found nothing' do
      visit '/loading-state'
      stub_pagefind
      search_for('zzzznothingmatchesthis')

      expect(page).to have_css('.search-popup--empty', text: 'No results for zzzznothingmatchesthis')
    end

    it 'shows nothing at all before the query is long enough' do
      visit '/loading-state'
      stub_pagefind
      search_for('u')

      expect(page).to have_no_css('.search-popup--hit')
      expect(page).to have_no_css('.search-popup--empty')
    end

  end

  describe 'the drawer, where the burger is the only way in' do

    # The burger is hidden at desktop width and its drawer needs the sidebar's menu, so
    # this follows what the burger points at — the same route frame_spec takes.
    it 'carries a trigger for the same popup' do
      visit '/menu/narrow'
      stub_pagefind

      # Visited directly, this page renders the menu twice: once as its content and once
      # in the sidebar the layout always draws.
      first('.search-trigger').click

      expect(page).to have_css('.search-popup--input:focus')
    end

    it 'hides the header pill at phone width, where the drawer takes over', driver: :selenium_phone do
      visit '/loading-state'

      expect(page).to have_no_css('.search-pill')
    end

  end

  # Not `js: true`: this group runs in the driver that executes no JavaScript at all,
  # which is the only honest way to test what a reader without it gets.
  describe 'without JavaScript', js: false do

    it 'leaves the pill a working link to the reference' do
      visit '/loading-state'

      pill = find('.search-pill', visible: :all)

      expect(pill.tag_name).to eq('a')
      expect(pill[:href]).to end_with('/api')
    end

  end

end
