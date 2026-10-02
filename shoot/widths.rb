# The in-between widths around the two structural breakpoints.
Shoot.suite 'widths', widths: [800, 1100, 1600], description: 'a Learn page and the landing between breakpoints' do |b|
  b.visit('/targeting-fragments'); b.shot('widths-learnpage')
  b.visit('/api'); b.shot('widths-apihub')
  b.visit('/'); b.shot('widths-landing')
end
