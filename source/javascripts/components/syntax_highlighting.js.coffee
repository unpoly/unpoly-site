# The default highlight.js package from bower comes
# with way too many languages, which makes auto-detection
# go horribly wrong.
hljs.configure
  languages: ['javascript', 'html', 'css', 'ruby', 'http']

up.compiler 'pre code', (fragment) ->
  hljs.highlightElement(fragment)

  html = fragment.innerHTML

  markedHTML = html.replaceAll(/^(\s*)(.+?)\s*<span class="hljs-comment">.*?\bmark-line\b.*?<\/span>$/mg, '$1<mark>$2</mark>')

  if html != markedHTML
    fragment.innerHTML = markedHTML
