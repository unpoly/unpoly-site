up.bus.on 'fragment:ready', ($fragment) ->
  if $fragment.is('#content')
    $('body').scrollTop(0)
    