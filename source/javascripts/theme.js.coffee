up.bus.on 'fragment:ready', ($fragment) ->
  if $fragment.is('#content')
    $('body').scrollTop(0)

up.awaken 'pre code', ($fragment) ->
  hljs.highlightBlock($fragment.get(0));
