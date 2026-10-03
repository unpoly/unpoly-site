# Keyboard paths: focus rings in the header and on the landing, hover states, the search
# shortcut, and opening menu nodes (sidebar at 1280, drawer at 800) without a mouse.
Shoot.suite 'keyboard', widths: [1280, 800], description: 'tab order, focus rings, / shortcut, menu toggles' do |b|
  focused = -> { b.js("const a = document.activeElement, cs = getComputedStyle(a); return [a.tagName, a.className, (a.getAttribute('aria-label') || a.textContent || '').trim().slice(0, 24), a.getAttribute('aria-expanded'), cs.outlineStyle, cs.outlineWidth]") }
  tab_until = lambda do |limit = 60, &test|
    limit.times do
      b.driver.action.send_keys(:tab).perform
      sleep 0.05
      return focused.() if test.(focused.())
    end
    puts '  (never reached)'
    nil
  end

  if b.width >= 1024
    b.visit('/')
    8.times do |i|
      b.driver.action.send_keys(:tab).perform; sleep 0.2
      p focused.()
      b.shot("keyboard-tab#{i + 1}") if [0, 1, 2, 4].include?(i)
    end
    b.driver.action.move_to(b.driver.find_element(css: '.top-nav--section')).perform; sleep 0.3; b.shot('keyboard-hover-nav')
    b.js("document.querySelector('.landing--card').scrollIntoView({ block: 'center' })"); sleep 0.3
    b.driver.action.move_to(b.driver.find_element(css: '.landing--card')).perform; sleep 0.3; b.shot('keyboard-hover-card')
    b.js('window.scrollTo(0, 0)'); b.driver.find_element(css: 'body').send_keys('/'); sleep 0.6; b.shot('keyboard-slash')
    b.driver.action.send_keys(:escape).perform; sleep 0.4
    p b.js("return [document.querySelector('.search-popup').hidden, document.activeElement.className]")

    # The sidebar: a node's toggle is a button of its own.
    b.visit('/up.render')
    p tab_until.() { |state| state[1].to_s.include?('node--toggle') }
    b.shot('keyboard-sidebar-toggle-focused')
    b.driver.action.send_keys(:enter).perform; sleep 0.4
    p focused.()
    b.shot('keyboard-sidebar-toggle-opened')
  else
    # The drawer: Older versions is reachable and opens from the keyboard.
    b.visit('/support')
    b.click('.guide--head a[href="/menu/narrow"]')
    p tab_until.() { |state| state[0] == 'BUTTON' && state[2] =~ /older versions/i }
    b.shot('keyboard-drawer-older-versions-focused')
    b.driver.action.send_keys(:enter).perform; sleep 0.4
    p focused.()
    b.shot('keyboard-drawer-older-versions-opened')
    b.visit('/support')
    b.click('.guide--head a[href="/menu/narrow"]')
    p tab_until.() { |state| state[2] == 'Expand Learn' }
    b.driver.action.send_keys(:space).perform; sleep 0.4
    b.shot('keyboard-drawer-learn-opened')
  end
end
