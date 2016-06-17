u = up.util

storeQuery = (query) ->
  Cookies.set('query', query)

loadQuery = ->
  Cookies.get('query')

up.compiler '.search', ($search, data) ->

  $query = $search.find('.search__query')
  $symbols = $search.find('.search__symbol')

  if previousQuery = u.presence(loadQuery())
    $query.val(previousQuery).select()

  matchSymbol = ($symbol, query) ->
    isMatch = true
    searchText = $symbol.data('search-text')
    for word in query
      if searchText.indexOf(word) == -1
        isMatch = false
        break
    isMatch

  find = ->
    query = u.trim($query.val()).toLowerCase()
    storeQuery(query)
    words = query.split(/\s+/)
    hasQuery = u.isPresent(query)
    $search.toggleClass('has_query', hasQuery)
    for symbol in $symbols
      $symbol = $(symbol)
      isMatch = matchSymbol($symbol, words)
      $symbol.toggle(isMatch)
      $symbol.toggleClass('is_match', isMatch)

  $query.on 'input', find
  find()
