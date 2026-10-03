# The phone frame: drawer navigation, search from the header, long pages.
Shoot.suite 'phone', widths: [390], description: 'drawer, phone search, scrolled pages' do |b|
  burger = -> { b.click('.guide--head a[href="/menu/narrow"]') }
  b.visit('/'); burger.(); b.shot('phone-01-landing-drawer')
  b.try_click('up-drawer .node--self', text: 'Support') and b.shot('phone-02-landing-drawer-support')
  b.visit('/'); burger.(); b.try_click('up-drawer .node--toggle'); b.shot('phone-03-drawer-expanded')
  b.visit('/'); b.click('a.action', text: 'Learn Unpoly'); b.shot('phone-04-landing-cta-learn')
  b.visit('/'); b.try_click('a', text: 'Learn more') and b.shot('phone-05-landing-card')
  b.visit('/up.render'); b.click('.guide--head a.logo'); b.shot('phone-06-api-to-landing')
  b.visit('/up.render'); burger.(); b.shot('phone-07-api-drawer')
  b.try_click('up-drawer .node--self', text: 'Changes') and b.shot('phone-08-api-drawer-changes')
  # The search is in the header at every width, so it can never open behind the drawer.
  b.visit('/')
  if b.try_click('.guide--head .search-pill')
    b.js("let i = document.querySelector('.search-dialog--input'); i.value = 'render'; i.dispatchEvent(new Event('input'))")
    sleep 2.5
    b.shot('phone-09-search-dialog')
    begin
      b.driver.find_elements(css: '.search-dialog--hit').find(&:displayed?)&.click
      b.settle(1)
      b.shot('phone-10-search-result')
    rescue Selenium::WebDriver::Error::ElementClickInterceptedError
      puts '  (the search hit is covered by another element and cannot be clicked)'
      b.js('up.layer.dismiss()') rescue nil
    end
  end
  b.visit('/up.render'); burger.(); b.js("document.querySelector('up-drawer .menu--nodes > .node:last-child').scrollIntoView()"); sleep 0.3; b.shot('phone-12-drawer-end')
  # The disclosure rows opened by hand: Learn, then API down to Formats.
  expand = ->(href) { b.click(%(up-drawer .menu--nodes > .node:has(> a[href="#{href}"]) > .node--toggle)) }
  b.visit('/support'); burger.(); b.shot('phone-13-drawer-closed')
  expand.('/learn'); b.shot('phone-14-drawer-learn-open')
  expand.('/api'); b.js("document.querySelector('up-drawer a[href=\"/formats\"]').scrollIntoView({ block: 'center' })"); sleep 0.3; b.shot('phone-15-drawer-api-open')
  b.visit('/support'); burger.(); b.click('up-drawer .menu--nodes > .node > button.node--self'); b.shot('phone-16-drawer-older-versions-open')
  b.visit('/up.render'); b.js('window.scrollTo(0, 3000)'); sleep 0.5; b.shot('phone-11-apifeat-scrolled')
end
