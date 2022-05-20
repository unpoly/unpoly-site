const client = algoliasearch('HQEWMGFXBZ', 'c46b02ab3bf1018d8b2a240e8f70f101')
const index = client.initIndex('unpoly-site_development')

up.compiler('.guide__results', function(resultsElement) {

  let searchRunning = false
  let nextQuery = null

  function queueSearch(query) {
    if (searchRunning) {
      nextQuery = query
    } else {
      searchNow(query)
    }
  }

  function searchNow(query) {
    // only query string
    index.search(query, {
      hitsPerPage: 10,
      attributesToRetrieve: ['path', 'shortKind'],
      attributesToHighlight: [],
      attributesToSnippet: ['title:40', 'name:40', 'text:40'],
      snippetEllipsisText: '…',
      highlightPreTag: '<mark>',
      highlightPostTag: '</mark>'
    }).then(onResultsReceived)
  }

  function onResultsReceived({ hits }) {

    let html = ''

    html += '<h1 class="title">Search results</h1>'

    for (let hit of hits) {
      html += `
        <a href="${hit.path}" class="documentable_preview">
          <div class="documentable_preview__kind">${hit.shortKind}</div>
          <div class="documentable_preview__title">
            <span class="documentable_preview__signature">${hit._snippetResult.title.value}</span>
          </div>
          <div class="documentable_preview__summary">${hit._snippetResult.text.value}</div>
        </a>
      `
    }
    // for (let hit of hits) {
    //   html += `
    //     <div class="search_result">
    //       <div class="search_result__kind">${hit.longKind}</div>
    //       <div class="search_result__title">
    //         <a class="hyperlink" href="${hit.path}">${hit._snippetResult.title.value}</a>
    //       </div>
    //       <div class="search_result__text">${hit._snippetResult.text.value}</div>
    //     </div>
    //   `
    // }

    resultsElement.innerHTML = html
    showResults()

    if (nextQuery) {
      searchNow(nextQuery)
      nextQuery = null
    }
  }

  function getContentElement() {
    return document.querySelector('.guide__content')
  }

  function hideResults() {
    up.element.show(getContentElement())
    up.element.hide(resultsElement)
  }

  function showResults() {
    up.element.hide(getContentElement())
    up.element.show(resultsElement)
  }

  // searchNow('overlay value')

  up.destructor(resultsElement, up.on('query:expand', ({ query }) => queueSearch(query)))
  up.destructor(resultsElement, up.on('query:cleared', () => hideResults()))
})

