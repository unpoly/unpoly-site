up.compiler '.expandable', (expandable, data) ->

  expand = -> expandable.classList.add('is_expanded')

  content = expandable.querySelector('.expandable__content')
  limiter = expandable.querySelector('.expandable__limiter')
  expandButton = expandable.querySelector('.expandable__expand');

  contentHeight = content.offsetHeight
  limiterHeight = parseFloat(getComputedStyle(limiter).maxHeight)

  if contentHeight < limiterHeight + 50
    expand()
  else
    expandButton.addEventListener('click', expand)
