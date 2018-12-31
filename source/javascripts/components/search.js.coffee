u = up.util
e = up.element

up.compiler '.search', (search) ->
  input = search.querySelector('.search__input')
  resetButton = search.querySelector('.search__reset')

  reset = ->
    input.value = ''
    e.emit(input, 'input')

  toggleReset = ->
    value = input.value.trim()
    present = u.isPresent(value)
    e.toggle(resetButton, present)

  input.addEventListener 'input', toggleReset

  resetButton.addEventListener 'click', reset

  toggleReset()
