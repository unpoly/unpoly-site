up.macro 'a', { batch: true, priority: 0 }, (links) ->
  currentHost = location.host
  for link in links
    linkHost = link.host
    if currentHost == linkHost
      unless up.link.isFollowable(link) || link.matches('[up-close]')
        makeContentLink(link)
    else
      link.target = '_blank'

makeContentLink = (link) ->
  target = link.getAttribute('content-link') || '.page_content'
  attrs =
    'up-target': target
    'up-preload': ''
  unless link.matches('.action') # it feels wrong for a button
    attrs['up-instant'] = ''
  up.element.setAttrs(link, attrs)

up.macro '[content-link]', { priority: 10 }, makeContentLink
