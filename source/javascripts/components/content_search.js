const client = algoliasearch('HQEWMGFXBZ', 'c46b02ab3bf1018d8b2a240e8f70f101')
const index = client.initIndex('unpoly-site_development')

const SEARCH_CONFIG = {
  hitsPerPage: 10,
  attributesToRetrieve: ['path', 'visibility'],
  attributesToHighlight: [],
  attributesToSnippet: ['title:40', 'name:40', 'text:30'],
  snippetEllipsisText: '…',
  highlightPreTag: '<mark>',
  highlightPostTag: '</mark>'
}

up.compiler('.content_search', function(container) {

  function searchNow(query) {
    return index.search(query, SEARCH_CONFIG).then(onAlgoliaResponse)
  }

  function renderAlgoliaHit(hit) {
    return `
      <a class="content_search__hit is_${hit.visibility}" href="${hit.path}">
        <div class="content_search__hit_head">
          <span class="content_search__hit_title">${hit._snippetResult.title.value}</span>
          <span class="content_search__hit_visibility">
            <span class="tag is_${hit.visibility}">${hit.visibility}</span>
          </span>
        </div>
        <div class="content_search__hit_text">${hit._snippetResult.text.value}</div>
      </a>
    `
  }

  function renderNoHits(query) {
    return `
      <div class="content_search__no_hits">
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

    console.log("html is", html)

    container.innerHTML = html
  }

  // Public API
  container.search = searchNow
})
