# Focus rings, hover states and the search shortcut on the landing.
Shoot.suite 'keyboard', widths: [1280], description: 'tab order, hover, / shortcut' do |b|
  b.visit('/')
  8.times do |i|
    b.driver.action.send_keys(:tab).perform
    sleep 0.2
    p b.js("const a = document.activeElement, cs = getComputedStyle(a); return [a.tagName, a.className, (a.textContent || '').trim().slice(0, 20), cs.outlineStyle, cs.outlineColor, cs.outlineWidth, cs.boxShadow.slice(0, 40)]")
    b.shot("keyboard-tab#{i + 1}") if [0, 1, 2, 4].include?(i)
  end
  b.driver.action.move_to(b.driver.find_element(css: '.top-nav--section')).perform; sleep 0.3; b.shot('keyboard-hover-nav')
  b.js("document.querySelector('.landing--card').scrollIntoView({ block: 'center' })"); sleep 0.3
  b.driver.action.move_to(b.driver.find_element(css: '.landing--card')).perform; sleep 0.3; b.shot('keyboard-hover-card')
  b.js('window.scrollTo(0, 0)'); b.driver.find_element(css: 'body').send_keys('/'); sleep 0.6; b.shot('keyboard-slash')
  b.driver.action.send_keys(:escape).perform; sleep 0.4
  p b.js("return [document.querySelector('.search-popup').hidden, document.activeElement.className]")
end
