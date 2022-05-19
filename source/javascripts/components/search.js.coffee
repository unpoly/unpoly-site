u = up.util
e = up.element

normalizeText = (text) ->
  text = text.trim()
  text = text.toLowerCase()
  text

up.compiler '.search', (searchForm) ->
  input = searchForm.querySelector('.search__input')
  resetButton = searchForm.querySelector('.search__reset')
  expandHelp = searchForm.querySelector('.search__expand_help')

  reset = ->
    input.value = ''
    up.emit(input, 'input')
    input.focus()

  normalizedQuery = ->
    normalizeText(input.value)

  hasQuery = ->
    normalizedQuery().length >= 3

  onSubmit = (event) ->
    event.preventDefault()
    if hasQuery()
      up.emit('query:expand', { query: normalizedQuery() })

  onInput = ->
    toggleElements()
    if hasQuery()
      up.emit('query:changed', { query: normalizedQuery() })
    else
      up.emit('query:cleared')

  toggleElements = ->
    e.toggle(resetButton, hasQuery())
    e.toggle(expandHelp, hasQuery())

  searchForm.addEventListener('submit', onSubmit)
  input.addEventListener('input', onInput)
  resetButton.addEventListener('click', reset)
  expandHelp.addEventListener('click', onSubmit)

  toggleElements()
