# The search dialog: picking hits from each page family, the row layout, the ranked
# list, the empty state, reopening, and search over the drawer.
Shoot.suite 'search', widths: [1280, 390], description: 'search dialog: hits, rows, dedup, reopen, drawer' do |b|
  open_search = lambda do
    b.click('.guide--head .search-pill')
    sleep 0.3
  end

  type = lambda do |query|
    input = b.driver.find_element(css: '.search-dialog--input')
    b.js('arguments[0].value = ""', input)
    input.send_keys(query)
    sleep 2.5
  end

  # Prints the rows of the list: page or section, badge, title.
  list = lambda do
    puts b.js(<<~JS)
      return [...document.querySelectorAll('.search-dialog--hit')].slice(0, 14).map((hit) =>
        '  ' + (hit.matches('.-section') ? '    § ' : 'page ') +
        (hit.querySelector('.search-dialog--badge')?.textContent.trim() || '').padEnd(7) +
        (hit.matches('.-deprecated') ? '[deprecated] ' : '') +
        (hit.querySelector('.search-dialog--title, .search-dialog--section')?.textContent.trim() || '') + '  → ' + hit.getAttribute('href')
      ).join('\\n')
    JS
  end

  # Picks the first visible hit matching hit_css, and wearing the badge if one is given.
  pick = lambda do |query, hit_css, name, badge: nil|
    open_search.()
    type.(query)
    b.shot("#{name}-dialog")
    hits = b.driver.find_elements(css: hit_css).select(&:displayed?)
    hits = hits.select { |hit| hit.find_elements(css: '.search-dialog--badge').any? { |e| e.text.strip.casecmp?(badge) } } if badge
    raise "No #{badge} hit for #{query}" if hits.empty?
    hits.first.click
    b.settle(1.0)
    b.shot(name)
  end

  # Hits picked from every page family.
  b.visit('/'); pick.('render', '.search-dialog--hit', 'search-01-landing-to-hit')
  b.visit('/'); pick.('targeting fragments', '.search-dialog--hit.-page', 'search-02-landing-to-learnpage', badge: 'Learn')
  b.visit('/up.render'); pick.('targeting fragments', '.search-dialog--hit.-page', 'search-03-api-to-learnpage', badge: 'Learn')
  b.visit('/targeting-fragments'); pick.('up-follow', '.search-dialog--hit', 'search-04-learn-to-api')
  b.visit('/learn'); pick.('overlay', '.search-dialog--hit.-section', 'search-05-learnhub-to-section')
  b.visit('/support'); pick.('render', '.search-dialog--hit', 'search-06-support-to-hit')

  # The dialog over each frame family.
  { 'landing' => '/', 'learnpage' => '/targeting-fragments', 'apifeat' => '/up.render', 'apihub' => '/api', 'article' => '/support' }.each do |family, path|
    b.visit(path); open_search.(); type.('follow')
    b.shot("search-10-over-#{family}")
    b.js('up.layer.dismiss()') rescue nil
  end

  # The row layout and the ranked list: a mixed query, names typed exactly, a module,
  # a param name.
  b.visit('/up.render'); open_search.()
  type.('follow'); puts '  [follow]'; list.(); b.shot('search-11-mixed-follow')
  type.('up.follow'); puts '  [up.follow]'; list.(); b.shot('search-12-dedup-up-follow')
  type.('up.link'); puts '  [up.link]'; list.(); b.shot('search-13-module-up-link')
  type.('up-watch-delay'); puts '  [up-watch-delay]'; list.(); b.shot('search-14-param')
  type.('render'); puts '  [render]'; list.(); b.shot('search-19-render')
  type.('watch'); puts '  [watch]'; list.(); b.shot('search-20-watch')
  type.('zzzznothingmatchesthis'); b.shot('search-15-empty')

  # Reopening brings the query back, selected, and runs it again.
  type.('overlays')
  b.driver.action.send_keys(:escape).perform; sleep 0.5
  open_search.(); sleep 2
  p b.js("let i = document.querySelector('.search-dialog--input'); return [i.value, i.selectionStart, i.selectionEnd, document.querySelectorAll('.search-dialog--hit').length]")
  b.shot('search-16-reopened')
  b.js('up.layer.dismiss()') rescue nil

  if b.width < 1024
    # The search opens over the drawer, and a hit picked there closes both.
    b.visit('/')
    b.click('.guide--head a[href="/menu/narrow"]')
    b.js("document.body.dispatchEvent(new KeyboardEvent('keydown', { key: '/', bubbles: true }))"); sleep 0.5
    type.('up-follow')
    p b.js('return up.layer.count')
    b.shot('search-17-over-drawer')
    b.driver.find_elements(css: '.search-dialog--hit').find(&:displayed?)&.click
    b.settle(1)
    b.shot('search-18-picked-over-drawer')
  else
    b.visit('/'); b.try_click('.version-nav') and b.shot('search-07-landing-version-popup')
    b.js('up.layer.dismiss()') rescue nil
  end
end
