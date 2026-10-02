# The phone frame: drawer navigation, search from the drawer, long pages.
Shoot.suite 'phone', widths: [390], description: 'drawer, phone search, scrolled pages' do |b|
  burger = -> { b.click('.top-nav--section.-hamburger') }
  b.visit('/'); burger.(); b.shot('phone-01-landing-drawer')
  b.try_click('up-drawer .node--self', text: 'Support') and b.shot('phone-02-landing-drawer-support')
  b.visit('/'); burger.(); b.try_click('up-drawer .node--collapser'); b.shot('phone-03-drawer-expanded')
  b.visit('/'); b.click('a.action', text: 'Learn Unpoly'); b.shot('phone-04-landing-cta-learn')
  b.visit('/'); b.try_click('a', text: 'Learn more') and b.shot('phone-05-landing-card')
  b.visit('/up.render'); b.click('.guide--logo a'); b.shot('phone-06-api-to-landing')
  b.visit('/up.render'); burger.(); b.shot('phone-07-api-drawer')
  b.try_click('up-drawer .node--self', text: 'Install') and b.shot('phone-08-api-drawer-install')
  b.visit('/'); burger.()
  if b.try_click('.search-trigger')
    b.js("let i = document.querySelector('.search-popup--input'); i.value = 'render'; i.dispatchEvent(new Event('input'))")
    sleep 2.5
    b.shot('phone-09-search-popup')
    begin
      b.driver.find_elements(css: '.search-popup--hit').find(&:displayed?)&.click
      b.settle(1)
      b.shot('phone-10-search-result')
    rescue Selenium::WebDriver::Error::ElementClickInterceptedError
      puts '  (the search hit is covered by another element and cannot be clicked)'
      b.js('up.layer.dismiss()') rescue nil
    end
  end
  b.visit('/up.render'); b.js('window.scrollTo(0, 3000)'); sleep 0.5; b.shot('phone-11-apifeat-scrolled')
end
