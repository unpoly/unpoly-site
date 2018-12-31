makeModalLink = (link) ->
  target = link.getAttribute('modal-link') || '.modal_content'
  attrs =
    'up-modal': target
    'up-preload': ''
  unless link.matches('.action') # it feels wrong for a button
    attrs['up-instant'] = ''
  up.element.setAttrs(link, attrs)

up.macro '[modal-link]', { priority: 10 }, makeModalLink
