up.compiler '.expandable', ($expandable) ->

  expand = -> $expandable.addClass('is_expanded')

  $content = $expandable.find('.expandable__content')
  $limiter = $expandable.find('.expandable__limiter')
  $expandButton = $expandable.find('.expandable__expand');

  contentHeight = $content.height()
  limiterHeight = $limiter.height()

  if contentHeight < limiterHeight + 50
    expand()
  else
    $expandButton.on('click', expand)
