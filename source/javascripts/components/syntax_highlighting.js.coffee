# The default highlight.js package from bower comes
# with way too many languages, which makes auto-detection
# go horribly wrong.
hljs.configure
  languages: ['javascript', 'html', 'css', 'ruby', 'http']

up.compiler 'pre code', (fragment) ->
  # match = /\blanguage-()
  hljs.highlightElement(fragment)
