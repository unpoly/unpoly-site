#= require jquery/dist/jquery
#= require highlightjs/highlight.pack
#= require up

# The default highlight.js package from bower comes
# with way too many languages, which makes auto-detection
# go horribly wrong.
hljs.configure
  languages: ['javascript', 'html']

up.compiler 'pre code', ($fragment) ->
  hljs.highlightBlock($fragment.get(0));
