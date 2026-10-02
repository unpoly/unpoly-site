# Doc pages with tricky content: parameter tables, long titles, wide tables and code.
Shoot.suite 'docs', widths: [1280], description: 'tricky documentation pages' do |b|
  b.visit('/up.render'); b.scroll_to('.feature--params, h2#parameters, [id*=param]'); b.shot('docs-01-render-params')
  b.visit('/up.extract'); b.shot('docs-02-deprecated')
  b.visit('/up.RenderJob.prototype.then'); b.shot('docs-03-long-title')
  b.visit('/install'); b.scroll_to('table'); b.shot('docs-04-install-table')
  b.visit('/'); b.try_click('a', text: 'install in ten minutes') and (b.scroll_to('table'); b.shot('docs-05-install-table-via-landing'))
  b.visit('/up.fragment'); b.shot('docs-06-module')
  b.visit('/changes/3.11.0'); b.shot('docs-07-release')
  b.visit('/up-follow'); b.shot('docs-08-selector')
  b.visit('/up.render'); b.scroll_to('pre'); b.shot('docs-09-code')
  b.visit('/'); b.try_click('a', text: 'Learn more') and (b.scroll_to('pre'); b.shot('docs-10-code-via-landing'))
  b.visit('/up:fragment:destroyed'); b.shot('docs-11-event')
  b.visit('/up.layer.config'); b.shot('docs-12-config')
end
