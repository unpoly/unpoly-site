up.compiler '.search', ($search, data) ->

  $query = $search.find('.search__query')
  $symbols = $search.find('.search__symbol')

  matchSymbol = ($symbol, query) ->
    isMatch = true
    searchText = $symbol.data('search-text')
    for word in query
      if searchText.indexOf(word) == -1
        isMatch = false
        break
    isMatch

  find = ->
    query = up.util.trim($query.val()).toLowerCase().split(/\s+/)
    for symbol in $symbols
      $symbol = $(symbol)
      isMatch = matchSymbol($symbol, query)
      $symbol.toggle(isMatch)

  $query.on 'input', find
  find()
