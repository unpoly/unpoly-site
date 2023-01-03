# The default highlight.js package from bower comes
# with way too many languages, which makes auto-detection
# go horribly wrong.
hljs.configure
  languages: ['javascript', 'html', 'css', 'ruby', 'http']

up.compiler 'pre code', (fragment) ->
  hljs.highlightElement(fragment)

  html = fragment.innerHTML

  markedHTML = html
  markedHTML = markedHTML.replaceAll(/^(\s*)(.+?)\s*<span class="hljs-comment">.*?\bmark-line\b.*?<\/span>$/mg, '$1<mark>$2</mark>')
  markedHTML = markedHTML.replaceAll(/^(\s*)(.+?)\s*<span class="hljs-comment">.*?\bmark-word: ([A-Za-z0-9_.-]+)\b.*?<\/span>$/mg, (match, indent, code, word) -> indent + code.replace(word, '<mark>$&</mark>'))

  if html != markedHTML
    fragment.innerHTML = markedHTML
