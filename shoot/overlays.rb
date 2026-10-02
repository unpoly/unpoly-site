# Print media, navigation after dismissed overlays, and sidebar-driven navigation.
Shoot.suite 'overlays', widths: [1280], description: 'print, post-overlay navigation, sidebar nav' do |b|
  b.visit('/targeting-fragments')
  b.driver.execute_cdp('Emulation.setEmulatedMedia', media: 'print'); sleep 0.5
  b.shot('overlays-01-print-learnpage')
  b.driver.execute_cdp('Emulation.setEmulatedMedia', media: '')
  b.visit('/up.render'); b.click('.version-nav'); b.js('up.layer.dismiss()'); b.settle
  b.click('.top-nav--section', text: 'Learn'); b.shot('overlays-02-nav-after-popup')
  b.visit('/up.render'); b.click('.search-pill'); b.driver.action.send_keys(:escape).perform; sleep 0.4
  b.click('.guide--head a.logo'); b.shot('overlays-03-logo-after-search-esc')
  b.visit('/learn'); b.click('.guide--menu .node--self', text: 'Links'); b.shot('overlays-04-learnhub-expand-links')
  b.click('.guide--menu .node--self', text: 'Following links'); b.shot('overlays-05-sidebar-to-learnpage')
  b.click('.guide--menu .node--self', text: 'Handling all links'); b.shot('overlays-06-sidebar-to-learnpage2')
end
