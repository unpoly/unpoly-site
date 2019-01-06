up.animation 'zoom-in', (element, options) ->
  up.element.setStyle(element, opacity: 0, transform: 'scale(0.5)')
  up.animate(element, { opacity: 1, transform: 'scale(1)' }, options)

up.animation 'zoom-out', (element, options) ->
  up.element.setStyle(element, opacity: 1, transform: 'scale(1)')
  up.animate(element, { opacity: 0, transform: 'scale(0.5)' }, options)
