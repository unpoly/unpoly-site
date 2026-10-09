// The site's full-text search, without a screen: load the Pagefind index, ask it, rank
// what it answers. The search dialog (search_dialog.js) shows the results to readers,
// webmcp.js hands them to AI agents in the browser. Both call searchPages().
//
// The index is fetched on the first search, never on page load. Pagefind indexes the
// built site, so in the preview server search works after `rake search:index`.
//
// Everything here is a global binding of the page's script (Sprockets concatenates
// the components), which is how the dialog and the specs reach SEARCH.

// Everything tunable about ranking and shape lives here, so that trying a different
// result mix is one edit rather than a hunt through the file.
//
// HOW THE FULL TEXT IS RANKED (config.rb has the index side)
//
// Pagefind scores a page as the sum of two numbers:
//
// 1. The body number: how well the page's text matches. More occurrences count more,
//    with diminishing returns, and a long page pays for its length (pageLength).
//
// 2. The title number: how well the page's title matches. Every title is indexed as
//    metadata and a match counts titleWeight. A page in the signature tier — the pages a
//    reader most likely means, marked with @signature in the doc comments — has its
//    title indexed a second time, as `tier_title`, and that match counts tierTitleWeight
//    on top.
//
// Once Pagefind answers, rankPages() multiplies each score, so these boosts apply to both
// numbers alike:
//
// - by signatureBoost if the page is in the signature tier (flagged `tier:signature`);
// - by its rung on kindLadder, a light tie-breaker: Learn > selector > config > event >
//   function > everything else. The kind is read from the page's badge.
//
// Why the title number lives in the index. Pagefind ranks every match, but this file
// only fetches the first mergeWindow results (each one is a request), so a multiplier
// here can only reorder pages that are already in that window. [up-layer=new] matches
// "layer" mostly in its title; on its text alone it ranks #79 of 212 and no multiplier
// here ever sees it. A title match must count inside Pagefind's own ranking. (Measured:
// with signatureBoost alone, "layer" lost [up-layer=new], up.layer.on and up.layer.ask
// from its top 10.) The same window does not matter for the kind ladder: a tie-breaker
// of at most 5% only reorders near-ties, and those sit next to each other in the window.
//
// Why the boosts are so different in size. A title match is one occurrence; a body score
// sums many occurrences. A modest multiplier is enough to separate two pages that both
// discuss a term at length, but a single title occurrence needs a large weight to
// compete with a page that mentions the term twenty times. Giving every page that large
// title weight lets a short page with the term in its name beat the guide about it
// (measured: titleWeight 10 for everyone pushed network-issues to #3 for "offline").
// So the title weight is low for everyone and high for the signature tier only.
//
// The ladder's values were first tuned as index weights, where Pagefind squares them
// (1.05 was ~10%). Here they multiply the score directly, so 1.05 is 5%: about half the
// effect, applied to the title number as well. They were re-validated, not re-tuned.
//
// Compound names in titles: decided, nothing is added. pagefind.yml keeps "-.:_" inside
// words, and Pagefind then stores "up-defer" as the whole word and as its parts, in
// metadata as in text. Measured on a throwaway index (2026-10-04): "defer" scores against
// a tier_title of "up-defer" exactly as against a plain "defer" (0.741 both), and
// appending the parts ("up-defer up defer") gained nothing.
//
// The knobs. The ranking knobs below take effect when the page reloads. A change to the
// tier (@signature) or pagefind.yml needs a re-index:
// SKIP_CHECK_LINKS=1 bundle exec rake search:index.
//
// Known and accepted: this ranking is good on the whole, not optimal for every query.
// For "etag" the guide Conditional requests lists fifth, below four short API pages
// about ETags (snapshot of 2026-10-04).
// Fitting the numbers to one query breaks another, so we stopped. A page that ranks
// wrong is fixed by curating the tier (@signature in the doc comments), not by another
// knob.
const SEARCH = {
  // Ranking, see above. A title match on any page (Pagefind's
  // ranking.metaWeights.title; its default is 5).
  titleWeight: 2,
  // A title match on a signature page, on top of titleWeight. 0 turns it off.
  tierTitleWeight: 10,
  // What a signature page's score is multiplied with. 1 turns it off. Only the first
  // mergeWindow results are reordered.
  signatureBoost: 1.4,
  // What a page's score is multiplied with, by its badge. A badge not listed counts 1
  // (headers, cookies, CSS, modules, classes).
  kindLadder: { Learn: 1.05, HTML: 1.04, CONFIG: 1.03, EVENT: 1.02, JS: 1.01 },
  // How much a long page pays for its length (Pagefind's ranking.pageLength, 0 to 1;
  // its default is 0.75). Lower favors long pages.
  pageLength: 0.6,
  minQueryLength: 2,
  debounceMs: 120,
  // Pages shown.
  maxPages: 12,
  // Pages fetched from Pagefind and ranked by rankPages(). Wider than what is shown, so
  // that a boost can lift a page from below the cut.
  mergeWindow: 30,
  maxSectionsPerPage: 3,
  // How long loading the index and searching it may take before the list says that
  // search is unavailable. Generous, so a slow connection gets a late list rather than
  // a false alarm; a late answer still replaces the message. (Specs lower it, see
  // spec/features/search_spec.rb.)
  pagefindTimeoutMs: 5000,
  pagefindUrl: '/pagefind/pagefind.js',
}

// One spelling per page: Pagefind links to "/up.follow/", the site to "/up.follow".
function normalizePath(url) {
  const [path, hash] = url.split('#')
  const clean = path.replace(/\/index\.html$/, '').replace(/\.html$/, '').replace(/(.)\/$/, '$1')
  return hash ? `${clean}#${hash}` : clean
}

// What a result row calls a page. A chapter's first page says so ("Links (overview)"),
// in search results only: next to the chapter's other pages it would look like one of
// them. config.rb puts the flag into a filter, so that it doesn't count as a word.
function pageTitle(page) {
  const title = page.meta?.title || normalizePath(page.url)
  return isOverview(page) ? `${title} (overview)` : title
}

function isOverview(page) {
  return Boolean(page.filters?.overview)
}

// The closest hub above a page (config.rb, search_hub), which a result row names below
// its title: a guide page's chapter, a feature's module, "API" for a module. An overview
// has none.
function pageHub(page) {
  return page.filters?.hub?.[0] || null
}

// The index lives as long as the page, not the dialog: it is fetched once.
let searchIndexLoading = null

// The index is fetched once, on the first search (the dialog loads it when it opens). A
// failure is remembered rather than retried on every keystroke.
function loadSearchIndex() {
  searchIndexLoading ||= loadPagefind()
  return searchIndexLoading
}

// The Pagefind module, or null when the index is missing.
async function loadPagefind() {
  // A spec can put its own index here; nothing is fetched then.
  if (window.pagefind) return window.pagefind

  try {
    const pagefind = await import(SEARCH.pagefindUrl)
    await pagefind.options?.({ excerptLength: 25, ranking: { pageLength: SEARCH.pageLength, metaWeights: { title: SEARCH.titleWeight, tier_title: SEARCH.tierTitleWeight } } })
    return pagefind
  } catch (error) {
    // In the preview server this is the normal state until `rake search:index` runs.
    console.error('Search index not built. Run bundle exec rake search:index. (%o)', error)
    return null
  }
}

// Pagefind's results in our order: each score times the page's boosts. See SEARCH above.
function rankPages(results, pages) {
  const score = (result, page) => (result.score ?? 0) *
    (page.meta?.tier === 'signature' ? SEARCH.signatureBoost : 1) *
    (SEARCH.kindLadder[page.meta?.badge] ?? 1)
  const scored = pages.map((page, i) => ({ page, score: score(results[i], page) }))
  return scored.sort((a, b) => b.score - a.score).map(({ page }) => page)
}

// Pagefind can list a page twice, under "/up.follow/" and "/up.follow". The first one
// stays.
function uniquePages(pages) {
  const seen = new Set()
  return pages.filter((page) => {
    const path = normalizePath(page.url)
    if (seen.has(path)) return false
    seen.add(path)
    return true
  })
}

// A page the index marks deprecated (config.rb) sinks below the others, for readers and
// agents alike.
function sinkDeprecated(pages) {
  return [...pages.filter((page) => !page.meta?.deprecated), ...pages.filter((page) => page.meta?.deprecated)]
}

// Full-text pages for a query, each page once, deprecated pages last. `pages` is null
// when the full text is unavailable or slower than timeoutMs; in the slow case `late`
// still resolves with the pages once they arrive. The timeout covers loading the index
// as well, which only takes time on the first search.
async function searchPages(query, { timeoutMs = SEARCH.pagefindTimeoutMs } = {}) {
  const search = (async () => {
    const pagefind = await loadSearchIndex()
    if (!pagefind) return null
    const result = await pagefind.search(query)
    const wanted = result.results.slice(0, SEARCH.mergeWindow)
    return sinkDeprecated(uniquePages(rankPages(wanted, await Promise.all(wanted.map((page) => page.data())))))
  })()
  search.catch((error) => console.error('Full text search failed: %o', error))

  const timedOut = Symbol('timeout')
  const timeout = new Promise((resolve) => setTimeout(() => resolve(timedOut), timeoutMs))

  try {
    const pages = await Promise.race([search, timeout])
    return pages === timedOut ? { pages: null, late: search } : { pages }
  } catch (error) {
    return { pages: null }
  }
}
