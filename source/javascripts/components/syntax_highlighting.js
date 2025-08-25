// The default highlight.js package from bower comes
// with way too many languages, which makes auto-detection
// go horribly wrong.
hljs.configure({
  languages: ['javascript', 'html', 'css', 'ruby', 'http']
})

const removeCommentCloser = function(phrase) {
  phrase = phrase.trim()
  // phrase = phrase.replace(/^(\<!--|&lt;!--|#|\/\/|\/\*)/, '')
  phrase = phrase.replace(/(-->|--&gt;|\*\/)$/, '')
  phrase = phrase.trim()
  return phrase
}

up.compiler('pre code', function(codeElement) {
  const preElement = codeElement.closest('pre')

  hljs.highlightElement(codeElement)

  const html = codeElement.innerHTML

  let postprocessedHTML = html

  postprocessedHTML = postprocessedHTML.replaceAll(
    /^(\s*)(.+?)\s*<span class="hljs-comment">.{0,10}\bmark-line\b.*?<\/span>$/mg,
    '$1<mark>$2</mark>'
  )

//  postprocessedHTML = postprocessedHTML.replaceAll(
//    /^(\s*)(.+?)\s*<span class="hljs-comment">.{0,10}\bmuted\b.*?<\/span>$/mg,
//    '$1<span class="dimmed">$2</span>'
//  )

  postprocessedHTML = postprocessedHTML.replaceAll(
    /^(\s*)(.+?)\s*<span class="hljs-comment">.{0,10}\bmark:\s+(.+)<\/span>(<span class="language-\w+">)?$/mg,
    function(match, indent, code, phrase, nextLanguage) {
      phrase = removeCommentCloser(phrase)
      const suffix = (nextLanguage || '')
      return indent + code.replace(phrase, '<mark>$&</mark>') + suffix
  })

  postprocessedHTML = postprocessedHTML.replaceAll(
    /^(\s*)(.+?\s*)<span class="hljs-comment">.{0,10}\b(chip|result):\s+(.+)<\/span>(<span class="language-\w+">)?$/mg,
    function(match, indent, code, kind, phrase, nextLanguage) {
      phrase = removeCommentCloser(phrase)
      const suffix = (nextLanguage || '')
      return indent + code + ('<span class="code-chip -' + kind + '">') + phrase + '</span>' + suffix
  })

  postprocessedHTML = postprocessedHTML.replace(
    /^<span class="hljs-comment">.{0,10}\blabel:\s+([^\n]+?)<\/span>\n/,
    function(match, labelText) {
      labelText = removeCommentCloser(labelText)
      const labelUID = "code-block-label-" + up.util.uid()
      const labelElement = up.element.createFromSelector('.code-block-label', {text: labelText, id: labelUID})
      preElement.prepend(labelElement)
      preElement.setAttribute('aria-describedby', labelUID)
      return ''; // remove comment + newline
  })

  if (html !== postprocessedHTML) {
    codeElement.innerHTML = postprocessedHTML
  }
})
