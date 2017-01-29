up.compiler '.expandable', ($expandable, data) ->

  expand = -> $expandable.addClass('is_expanded')

  $content = $expandable.find('.expandable__content')
  $limiter = $expandable.find('.expandable__limiter')
  $expandButton = $expandable.find('.expandable__expand');

  contentHeight = $content.height()
  limiterHeight = parseFloat($limiter.css('max-height'))

  if (contentHeight < limiterHeight + 50) || (data.path == '/up.protocol')
    expand()
  else
    $expandButton.on('click', expand)
