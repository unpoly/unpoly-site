# The default highlight.js package from bower comes
# with way too many languages, which makes auto-detection
# go horribly wrong.
hljs.configure
  languages: ['javascript', 'html', 'css', 'ruby', 'http']

up.compiler 'pre code', (codeElement) ->
  preElement = codeElement.closest('pre')

  hljs.highlightElement(codeElement)

  html = codeElement.innerHTML

  postprocessedHTML = html

  postprocessedHTML = postprocessedHTML.replaceAll(
    /^(\s*)(.+?)\s*<span class="hljs-comment">.{0,10}\bmark-line\b.*?<\/span>$/mg,
    '$1<mark>$2</mark>'
  )

  postprocessedHTML = postprocessedHTML.replaceAll(
    /^(\s*)(.+?)\s*<span class="hljs-comment">.{0,10}\bmark-phrase (?:"([^"]+)"|'([^']+)').*?<\/span>(<span class="language-\w+">)?$/mg,
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

  postprocessedHTML = postprocessedHTML.replace(
    /^<span class="hljs-comment">.{0,10}\blabel (?:"([^"]+)"|'([^']+)')[^\n]*\n/,
    (match, label1, label2) ->
      labelText = label1 || label2
      labelUID = "code-block-label-" + up.util.uid()
      labelElement = up.element.createFromSelector('.code-block-label', text: labelText, id: labelUID)
      preElement.prepend(labelElement)
      preElement.setAttribute('aria-describedby', labelUID)
      return '' # remove comment + newline
  )

  if html != postprocessedHTML
    codeElement.innerHTML = postprocessedHTML

#  firstCodeChild = codeElement.children[0]
#
#  labelPattern = /^.{0,10}\blabel (?:"([^"]+)"|'([^']+)')/
#
#  if (firstCodeChild && firstCodeChild.matches('.hljs-comment'))
#    labelPatternMatch = labelPattern.exec(firstCodeChild.innerText)
#    if labelPatternMatch
#      preElement = codeElement.closest('pre')
#      firstCodeChild.remove()
#      labelText = labelPatternMatch[1] || labelPatternMatch[2]
#      labelElement = up.element.createFromSelector('.code-block-label', text: labelText)
#      preElement.prepend(labelElement)
#      preElement.setAttribute('aria-label', labelText)
