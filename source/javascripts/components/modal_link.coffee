makeModalLink = (link) ->
  $link = $(link)
  target = $link.attr('modal-link') || '.modal_content'
  attrs =
    'up-modal': target
    'up-preload': ''
  unless $link.is('.action') # it feels wrong for a button
    attrs['up-instant'] = ''
  $link.attr(attrs)

up.macro '[modal-link]', { priority: 10 }, makeModalLink
