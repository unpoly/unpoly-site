let index


const SEARCH_CONFIG = {
  hitsPerPage: 15,
  attributesToRetrieve: ['path', 'visibility'],
  attributesToHighlight: [],
  attributesToSnippet: ['title:40', 'name:40', 'text:30'],
  snippetEllipsisText: '…',
  highlightPreTag: '<mark>',
  highlightPostTag: '</mark>'
}

function getIndex(name) {
  return window.ALGOLIA_INDEX ||= buildIndex(name)
}

function buildIndex(name) {
  try {
    if (!name) throw new Error('No Algolia index name given')
    const client = algoliasearch('HQEWMGFXBZ', 'c46b02ab3bf1018d8b2a240e8f70f101')
    return client.initIndex(name)
  } catch (error) {
    console.error('Error building Algolia index: %o', error)
  }
}

up.compiler('.content-search', function(container, data) {
  let index = getIndex(data.algoliaIndex)

  if (!index) {
    up.element.hide(container)
    document.querySelectorAll('.content-search--related').forEach(up.element.hide)
    return
  }

  function searchNow(query) {
    return index.search(query, SEARCH_CONFIG).then(onAlgoliaResponse)
  }

  function renderAlgoliaHit(hit) {
    return `
      <a class="content-search--hit -${hit.visibility}" href="${hit.path}">
        <div class="content-search--hit-head">
          <span class="content-search--hit-title">${hit._snippetResult.title.value}</span>
          <span class="content-search--hit-visibility">
            <span class="tag -${hit.visibility}">${hit.visibility}</span>
          </span>
        </div>
        <div class="content-search--hit-text">${hit._snippetResult.text.value}</div>
      </a>
    `
  }

  function renderNoHits(query) {
    return `
      <div class="content-search--no-hits">
        No text results for <b>${query}</b>
      </div>
    `
  }

  function onAlgoliaResponse({ hits, query }) {
    let html

    if (hits.length) {
      html = hits.map(renderAlgoliaHit).join('')
    } else {
      html = renderNoHits(query)
    }

    container.innerHTML = html
  }

  // Public API
  container.search = searchNow
})
