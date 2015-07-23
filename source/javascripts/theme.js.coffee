up.bus.on 'fragment:ready', ($fragment) ->
  if $fragment.is('#content')
    $('body').scrollTop(0)

# The default highlight.js package from bower comes
# with way too many languages, which makes auto-detection
# go horribly wrong.
hljs.configure
  languages: ['javascript', 'html']

up.awaken 'pre code', ($fragment) ->
  hljs.highlightBlock($fragment.get(0));
