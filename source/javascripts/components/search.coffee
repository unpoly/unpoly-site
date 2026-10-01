u = up.util
e = up.element

normalizeText = (text) ->
  text = text.trim()
  text = text.toLowerCase()
  text

up.compiler '.search', (searchForm) ->
  input = searchForm.querySelector('.search--input')
  hotKeyInfo = searchForm.querySelector('.search--hot-key')
  resetButton = searchForm.querySelector('.search--reset')
  expandHelp = searchForm.querySelector('.search--expand-help')
  menu = document.querySelector('.menu')
  contentSearch = document.querySelector('.content-search')
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

  # "/" opens the search popup now (components/search_popup.js). The rest of this file
  # goes when the tree filter it drives does.
  onGlobalKeyDown = (event) ->
    if event.key == 'Escape' && isFocused()
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
    # The "/" hint left with the key itself, which the search popup now owns.
    e.toggle(hotKeyInfo, !isFocused() && !hasQueryNow) if hotKeyInfo

  searchForm.addEventListener('submit', onSubmit)
  input.addEventListener('input', onInput)
  input.addEventListener('focus', onFocus)
  input.addEventListener('blur', onBlur)
  resetButton.addEventListener('click', onReset)
  expandHelp.addEventListener('click', onSubmit)

  up.destructor(searchForm, up.on('keydown', onGlobalKeyDown))

  toggleElements()
