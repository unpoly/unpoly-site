u = up.util
e = up.element

normalizeText = (text) ->
  text = text.trim()
  text = text.toLowerCase()
  text

up.compiler '.search', (search) ->
  input = search.querySelector('.search__input')
  resetButton = search.querySelector('.search__reset')

  reset = ->
    input.value = ''
    up.emit(input, 'input')
    input.focus()

  normalizedQuery = ->
    normalizeText(input.value)

  onInput = ->
    toggleReset()
    up.emit('search:changed', { query: normalizedQuery() })

  toggleReset = ->
    e.toggle(resetButton, !!normalizedQuery().length)

  input.addEventListener 'input', onInput

  resetButton.addEventListener 'click', reset

  toggleReset()
