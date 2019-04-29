makeDrawerLink = (link) ->
  target = link.getAttribute('drawer-link') || '.drawer_content'
  attrs =
    'up-drawer': target
    'up-preload': ''
  unless link.matches('.action') # it feels wrong for a button
    attrs['up-instant'] = ''
  up.element.setAttrs(link, attrs)

up.macro '[drawer-link]', { priority: 10 }, makeDrawerLink
