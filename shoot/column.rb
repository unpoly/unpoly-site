# The text column across page families at widths from the rail breakpoint up: it must
# be the same on every page at one window width, grow with the window and stop at its cap.
Shoot.suite 'column', widths: [1024, 1280, 1500, 1920], description: 'text column per page at wide widths' do |b|
  [['/learn', 'learnhub'], ['/targeting-fragments', 'learnpage'], ['/up.render', 'apifeat'], ['/api', 'apihub'], ['/support', 'article']].each do |path, name|
    b.visit(path)
    b.shot("column-#{name}")
  end
end
