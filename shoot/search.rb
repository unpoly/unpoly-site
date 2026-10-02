# Search results opened from each family, and the version popup.
Shoot.suite 'search', widths: [1280], description: 'search hits and version popup per family' do |b|
  # Picks the first visible hit matching hit_css, and wearing the badge if one is given.
  search = lambda do |query, hit_css, name, badge: nil|
    if b.width < 1024
      b.click('.top-nav--section.-hamburger')
      b.click('.search-trigger')
    else
      b.click('.search-pill')
    end
    b.driver.find_element(css: '.search-popup--input').send_keys(query)
    sleep 2.5
    b.shot("#{name}-popup")
    hits = b.driver.find_elements(css: hit_css).select(&:displayed?)
    hits = hits.select { |hit| hit.find_elements(css: '.search-popup--badge').any? { |e| e.text.strip.casecmp?(badge) } } if badge
    puts "  hits=#{hits.size} first=#{hits.first(3).map { |e| e.attribute('href') }.inspect}"
    raise "No #{badge} hit for #{query}" if hits.empty?
    hits.first.click
    b.settle(1.0)
    b.shot(name)
  end

  b.visit('/'); search.('render', '.search-popup--hit', 'search-01-landing-to-hit')
  b.visit('/'); search.('targeting fragments', '.search-popup--hit.-page', 'search-02-landing-to-learnpage', badge: 'Learn')
  b.visit('/up.render'); search.('targeting fragments', '.search-popup--hit.-page', 'search-03-api-to-learnpage', badge: 'Learn')
  b.visit('/targeting-fragments'); search.('up-follow', '.search-popup--hit', 'search-04-learn-to-api')
  b.visit('/learn'); search.('overlay', '.search-popup--hit.-section', 'search-05-learnhub-to-section')
  b.visit('/support'); search.('render', '.search-popup--hit', 'search-06-support-to-hit')

  b.visit('/'); b.try_click('.version-nav') and b.shot('search-07-landing-version-popup')
  b.js('up.layer.dismiss()') rescue nil
  b.settle; b.shot('search-08-landing-after-popup')
  b.visit('/up.render'); b.try_click('.version-nav') and b.shot('search-09-api-version-popup')
end
