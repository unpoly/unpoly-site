makeModalLink = (link) ->
  $link = $(link)
  target = $link.attr('modal-link') || '.modal_content'
  attrs =
    'up-modal': target
    'up-instant': ''
    'up-preload': ''
  $link.attr(attrs)

up.macro '[modal-link]', { priority: 10 }, makeModalLink
