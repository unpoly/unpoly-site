#= require ./shared

u = up.util

up.compiler '.search', ($search, data) ->

  $query = $search.find('.search__query')
  $symbols = $search.find('.search__symbol')

  matchSymbol = ($symbol, query) ->
    $symbol.data('search-text').indexOf(query) >= 0

  find = ->
    query = u.trim($query.val()).toLowerCase()
    for symbol in $symbols
      $symbol = $(symbol)
      isMatch = matchSymbol($symbol, query)
      $symbol.toggle(isMatch)

  $query.on 'input', find
  find()
