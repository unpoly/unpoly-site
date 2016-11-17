#= require highlightjs/highlight.pack

# The default highlight.js package from bower comes
# with way too many languages, which makes auto-detection
# go horribly wrong.
hljs.configure
  languages: ['javascript', 'html', 'css', 'ruby']

up.compiler 'pre code', ($fragment) ->
  hljs.highlightBlock($fragment.get(0));
