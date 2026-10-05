# Fragment navigation across page families, then history. The stale-frame defects
# (catalog L1-L5) all live here: a frame is only right if it is right after every
# way of arriving.
Shoot.suite 'paths', widths: [1280, 390], description: 'cross-family navigation and history' do |b|
  phone = b.width < 1024
  nav = ->(label) { b.click('.top-nav--section', text: label) }
  logo = -> { b.click('.guide--head a.logo') }

  if phone
    b.visit('/'); b.click('.guide--head a[href="/menu/narrow"]')
    b.try_click('up-drawer .node--self', text: 'Support') and b.shot('paths-01-landing-drawer-to-support')
  else
    b.visit('/'); nav.('Learn'); b.shot('paths-01-landing-to-learn')
    nav.('API'); b.shot('paths-02-learn-to-api')
    logo.(); b.shot('paths-03-api-to-landing')
    b.visit('/'); nav.('API'); b.shot('paths-04-landing-to-api')
  end
  b.visit('/'); b.click('a.action', text: 'Learn Unpoly'); b.shot('paths-05-landing-cta-learn')
  b.visit('/'); b.try_click('a', text: 'Learn more') and b.shot('paths-06-landing-card-learnpage')
  b.visit('/'); b.try_click('a', text: 'install in ten minutes') and b.shot('paths-07-landing-install')
  b.visit('/'); b.try_click('.guide--footer a', text: 'Imprint') and b.shot('paths-08-landing-imprint')
  if !phone
    b.visit('/'); nav.('Changes'); b.shot('paths-09-landing-changes')
    b.visit('/'); nav.('Support'); b.shot('paths-10-landing-support')
  end
  b.visit('/up.render'); logo.(); b.shot('paths-11-apifeat-to-landing')
  b.visit('/up.render'); logo.(); b.shot('paths-11b-apifeat-to-landing-full', full: true)
  b.visit('/targeting-fragments'); logo.(); b.shot('paths-12-learnpage-to-landing')
  if !phone
    b.visit('/up.render'); nav.('Learn'); b.shot('paths-13-apifeat-to-learnhub')
    b.visit('/targeting-fragments'); nav.('API'); b.shot('paths-14-learnpage-to-apihub')
    b.visit('/changes'); nav.('API'); b.shot('paths-15-changes-to-api')
    b.visit('/api'); nav.('Changes'); b.shot('paths-16-api-to-changes')
    b.visit('/support'); logo.(); b.shot('paths-17-support-to-landing')
    b.visit('/up.render'); nav.('Support'); b.shot('paths-17b-apifeat-to-support')
    b.visit('/support'); nav.('Learn'); b.shot('paths-17c-support-to-learnhub')
  end
  b.visit('/learn'); b.try_click('.guide--content a', text: 'Installation') and b.shot('paths-18-learnhub-to-install')
  b.visit('/up.render'); b.try_click('.guide--content a[href^="/targeting"]') and b.shot('paths-19-apifeat-incontent-learnlink')

  if !phone
    # A double click renders the response twice; the sidebar must still get its menu.
    b.visit('/targeting-fragments')
    api = b.driver.find_elements(css: '.top-nav--section').find { |e| e.text.strip == 'API' }
    b.driver.action.double_click(api).perform
    b.settle(2.0)
    b.shot('paths-25-learnpage-doubleclick-api')

    b.visit('/'); nav.('Learn'); nav.('API')
    b.back; b.shot('paths-20-back-to-learn')
    b.back; b.shot('paths-21-back-to-landing')
    b.forward; b.shot('paths-22-forward-to-learn')
    b.forward; b.shot('paths-23-forward-to-api')
    b.visit('/up.render'); logo.(); b.back; b.shot('paths-24-landing-back-to-api')
  end
end
