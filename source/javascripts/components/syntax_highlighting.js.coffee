# The default highlight.js package from bower comes
# with way too many languages, which makes auto-detection
# go horribly wrong.
hljs.configure
  languages: ['javascript', 'html', 'css', 'ruby', 'http']

up.compiler 'pre code', (fragment) ->
  hljs.highlightElement(fragment)

  html = fragment.innerHTML

  markedHTML = html

  markedHTML = markedHTML.replaceAll(
    /^(\s*)(.+?)\s*<span class="hljs-comment">.*?\bmark-line\b.*?<\/span>$/mg,
    '$1<mark>$2</mark>'
  )

  markedHTML = markedHTML.replaceAll(
    /^(\s*)(.+?)\s*<span class="hljs-comment">.*?\bmark-phrase (?:"([^"]+)"|'([^']+)').*?<\/span>(<span class="language-\w+">)?$/mg,
    (match, indent, code, phrase1, phrase2, nextLanguage) ->
      phrase = (phrase1 || phrase2).trim()
      suffix = (nextLanguage || '')
      indent + code.replace(phrase, '<mark>$&</mark>') + suffix
  )

#  markedHTML = markedHTML.replaceAll(
#    /^(\s*)(.+?)\s*<span class="hljs-comment">.*?\bmark-pattern \/([^\/])\/.*?<\/span>$/mg,
#    (match, indent, code, pattern) ->
#      pattern = new RegExp(pattern)
#      indent + code.replace(phrase, '<mark>$&</mark>')
#  )

  if html != markedHTML
    fragment.innerHTML = markedHTML
