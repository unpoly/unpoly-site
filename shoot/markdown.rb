# What the Markdown station changed on screen: the feature cards on module pages, the
# types of parameters, and the MD button next to Edit (or alone where there is no Edit).
Shoot.suite 'markdown', widths: [1280, 390], description: 'cards, types and the MD button' do |b|
  b.visit('/up.link'); b.shot('markdown-01-module-top')
  b.visit('/up.link'); b.scroll_to('#essential-features'); b.shot('markdown-02-essentials')
  b.visit('/up.link'); b.scroll_to('#all-features'); b.shot('markdown-03-all-features')
  b.visit('/up.render'); b.scroll_to('h2#parameters'); b.shot('markdown-04-params-types')
  b.visit('/up.layer.config'); b.scroll_to('h2#value'); b.shot('markdown-05-config-types')
  b.visit('/up-follow'); b.shot('markdown-06-selector-top')
  b.visit('/start/links'); b.shot('markdown-07-learn-page')
  b.visit('/learn'); b.shot('markdown-08-learn-hub')
  b.visit('/api'); b.shot('markdown-09-api-hub')
  b.visit('/changes'); b.shot('markdown-10-changes')
  b.visit('/changes/3.11.0'); b.shot('markdown-11-release')
  b.visit('/support'); b.shot('markdown-12-support')
  b.visit('/formats'); b.shot('markdown-13-topic-index')
end

# The empty search dialog's tip about the agent skill.
Shoot.suite 'markdown-search', widths: [1280, 390], description: 'the search dialog tip' do |b|
  b.visit('/up.render'); b.click('.guide--head .search-pill'); sleep 0.5; b.shot('markdown-14-search-tip')
end
