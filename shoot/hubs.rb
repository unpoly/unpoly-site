# The two area hubs, /learn (a path into the course plus an index of every chapter)
# and /api (a dense catalog of modules), top of page and the whole page.
Shoot.suite 'hubs', widths: [390, 1280, 1920], description: 'learn and api hubs' do |b|
  [['/learn', 'learn'], ['/api', 'api']].each do |path, name|
    b.visit(path)
    b.shot("hub-#{name}")
    b.shot("hub-#{name}-full", full: true)
  end
end
