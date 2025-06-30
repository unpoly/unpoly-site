u = up.util
e = up.element

normalizeText = (text) ->
  text = text.trim()
  text = text.toLowerCase()
  text

isAnyFieldFocused = ->
  focusedField = document.activeElement
  focusedField && focusedField.matches(up.form.fieldSelector())

up.compiler '.search', (searchForm) ->
  input = searchForm.querySelector('.search__input')
  hotKeyInfo = searchForm.querySelector('.search__hot_key')
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

  onFocus = ->
    toggleElements()

  onBlur = ->
    toggleElements()

  onGlobalKeyDown = (event) ->
    if event.key == '/' && !isAnyFieldFocused()
      input.focus()
      input.select()
      event.preventDefault()
    else if event.key == 'Escape' && isFocused()
      input.blur()
      event.preventDefault()

  isFocused = ->
    document.activeElement == input

  toggleElements = ->
    hasQueryNow = hasQuery()
    menu.toggleNodes(!expanded)
    e.toggle(contentSearch, expanded)
    e.toggle(resetButton, hasQueryNow)
    e.toggle(expandHelp, hasQueryNow)
    e.toggle(hotKeyInfo, !isFocused() && !hasQueryNow)

  searchForm.addEventListener('submit', onSubmit)
  input.addEventListener('input', onInput)
  input.addEventListener('focus', onFocus)
  input.addEventListener('blur', onBlur)
  resetButton.addEventListener('click', onReset)
  expandHelp.addEventListener('click', onSubmit)

  up.destructor(searchForm, up.on('keydown', onGlobalKeyDown))

  toggleElements()
