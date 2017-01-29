up.macro 'a', { batch: true, priority: 0 }, ($links) ->
  currentHost = location.host
  for link in $links
    $link = $(link)
    linkHost = link.host
    if currentHost == linkHost
      unless up.link.isFollowable(link) || $link.is('[up-close]')
        makeContentLink(link)
    else
      link.target = '_blank'

makeContentLink = (link) ->
  $link = $(link)
  target = $link.attr('content-link') || '.page_content'
  attrs =
    'up-target': target
    'up-preload': ''
    'up-transition': 'cross-fade'
    'up-duration': '300'
  unless $link.is('.action') # it feels wrong for a button
    attrs['up-instant'] = ''
  $link.attr(attrs)

up.macro '[content-link]', { priority: 10 }, makeContentLink
