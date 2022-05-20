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
  menu = document.querySelector('.menu')
  contentSearch = document.querySelector('.content_search')
  expanded = false

  normalizedQuery = ->
    normalizeText(input.value)

  hasQuery = ->
    normalizedQuery().length >= 3

  onReset = ->
    input.value = ''
    input.focus()

    unexpand()

  onSubmit = (event) ->
    event.preventDefault()
    if hasQuery()
      expand()

  expand = ->
    contentSearch.search(normalizedQuery()).then ->
      expanded = true
      toggleElements()

  unexpand = ->
    expanded = false
    menu.resetFilter()
    toggleElements()

  onInput = ->
    toggleElements()
    if hasQuery() && !expanded
      menu.filter(normalizedQuery())
    else
      unexpand()

  toggleElements = ->
    menu.toggleNodes(!expanded)
    e.toggle(contentSearch, expanded)
    e.toggle(resetButton, hasQuery())
    e.toggle(expandHelp, hasQuery())

  searchForm.addEventListener('submit', onSubmit)
  input.addEventListener('input', onInput)
  resetButton.addEventListener('click', onReset)
  expandHelp.addEventListener('click', onSubmit)

  toggleElements()
