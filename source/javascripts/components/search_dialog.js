// The site's search.
//
// It opens as a modal overlay (up.layer.open), so the framework provides the dialog:
// backdrop, focus trap and restore, Escape, scroll lock, stacking. This file provides
// what goes into it, see source/_search_dialog.html.erb.
//
// Pagefind answers a query with pages, and this file lists them as one list: each page
// with its title, its badge, and the sections that matched beneath it. The order is
// Pagefind's score with our boosts on top (see below).
//
// The index is fetched on the first open, never on page load.

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

const MESSAGES = {
  noResults: (query) => `No results for ${query}`,
  unavailable: 'Search is unavailable right now.',
  // For the console only: readers can do nothing about it.
  noIndex: 'Search index not built. Run bundle exec rake search:index.',
}

// The badges that name an area rather than a kind of code. Rows wearing one have a prose
// title; every other row is named after an identifier and set as code.
const AREA_BADGES = ['Learn', 'API']

function normalize(text) {
  // A reader types "up-follow", the title is "[up-follow]" — highlighting ignores the
  // punctuation around the name.
  return text.toLowerCase().replace(/[[\]()]/g, '')
}

// One spelling per page: Pagefind links to "/up.follow/", the site to "/up.follow".
function normalizePath(url) {
  const [path, hash] = url.split('#')
  const clean = path.replace(/\/index\.html$/, '').replace(/\.html$/, '').replace(/(.)\/$/, '$1')
  return hash ? `${clean}#${hash}` : clean
}

function isTypingTarget(element) {
  // "/" is Firefox's quick-find and a plain character in any field, so we only claim it
  // when the reader is not writing something. Same guard GitHub uses.
  return element && (element.matches('input, textarea, select') || element.isContentEditable)
}

function escapeHtml(text) {
  return String(text).replace(/[&<>"]/g, (char) => (
    { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[char]
  ))
}

// Marks the typed part of a title, so the eye lands where the match is.
function highlight(text, query) {
  const needle = normalize(query)
  const at = normalize(text).indexOf(needle)
  if (at === -1 || !needle) return escapeHtml(text)

  // normalize() only lowercases and drops bracket characters, so offsets can shift.
  // Walking the original string keeps the marks on the right letters.
  // The mark ends right after the last matched letter, so it never takes a bracket
  // along that the reader didn't type ("follow" in "up.follow(link)").
  let plain = 0
  let start = -1
  let end = -1
  for (let i = 0; i < text.length; i++) {
    if (!/[[\]()]/.test(text[i])) {
      if (plain === at) start = i
      if (plain === at + needle.length - 1) { end = i + 1; break }
      plain++
    }
  }
  if (start === -1 || end === -1) return escapeHtml(text)

  return escapeHtml(text.slice(0, start)) +
    '<mark>' + escapeHtml(text.slice(start, end)) + '</mark>' +
    escapeHtml(text.slice(end))
}

// The list, as rows to render.
//
// pages: the full-text pages in ranked order, as many as SEARCH.mergeWindow. A page the
// index marks deprecated (config.rb) is struck and sinks below the others.
function listRows(pages) {
  const shown = new Set()
  const current = []
  const deprecated = []
  for (const page of pages) {
    const path = normalizePath(page.url)
    if (shown.has(path)) continue
    shown.add(path)
    if (page.meta?.deprecated) {
      deprecated.push({ page, deprecated: true })
    } else {
      current.push({ page })
    }
  }

  return [...current, ...deprecated].slice(0, SEARCH.maxPages)
}

// The index and the reader's last query live as long as the page, not the dialog: the
// index is fetched once, and reopening the search brings the query back.
const state = {
  pagefind: null,
  loading: null,
  query: '',
}

// The index is fetched once, on the first open. A failure is remembered rather than
// retried on every keystroke.
function load() {
  state.loading ||= loadPagefind()
  return state.loading
}

async function loadPagefind() {
  // A spec can put its own index here; nothing is fetched then.
  if (window.pagefind) {
    state.pagefind = window.pagefind
    return
  }
  try {
    state.pagefind = await import(SEARCH.pagefindUrl)
    await state.pagefind.options?.({ excerptLength: 25, ranking: { pageLength: SEARCH.pageLength, metaWeights: { title: SEARCH.titleWeight, tier_title: SEARCH.tierTitleWeight } } })
  } catch (error) {
    // In the preview server this is the normal state until `rake search:index` runs.
    console.error('%s (%o)', MESSAGES.noIndex, error)
  }
}

// Pagefind's results in our order: each score times the page's boosts. See the top of
// this file.
function rankPages(results, pages) {
  const score = (result, page) => (result.score ?? 0) *
    (page.meta?.tier === 'signature' ? SEARCH.signatureBoost : 1) *
    (SEARCH.kindLadder[page.meta?.badge] ?? 1)
  const scored = pages.map((page, i) => ({ page, score: score(results[i], page) }))
  return scored.sort((a, b) => b.score - a.score).map(({ page }) => page)
}

// Full-text pages for a query. `pages` is null when the full text is unavailable or too
// slow; in the slow case `late` still resolves with the pages once they arrive. The
// timeout covers loading the index as well, which only takes time on the first search.
async function searchPages(query) {
  const search = (async () => {
    await load()
    if (!state.pagefind) return null
    const result = await state.pagefind.search(query)
    const wanted = result.results.slice(0, SEARCH.mergeWindow)
    return rankPages(wanted, await Promise.all(wanted.map((page) => page.data())))
  })()
  search.catch((error) => console.error('Full text search failed: %o', error))

  const timedOut = Symbol('timeout')
  const timeout = new Promise((resolve) => setTimeout(() => resolve(timedOut), SEARCH.pagefindTimeoutMs))

  try {
    const pages = await Promise.race([search, timeout])
    return pages === timedOut ? { pages: null, late: search } : { pages }
  } catch (error) {
    return { pages: null }
  }
}

function isSearchOpen() {
  return up.layer.stack.some((layer) => layer.element.matches('.search-dialog'))
}

// origin: what opened the search; focus returns to it when the dialog closes.
function openSearch(origin = document.activeElement) {
  if (isSearchOpen()) return

  const template = document.querySelector('.search-dialog-template')
  if (!template) return

  up.layer.open({
    mode: 'modal',
    class: 'search-dialog',
    content: template.innerHTML,
    history: false,
    animation: false,
    origin,
  })
}

up.compiler('.search-dialog--input', function(input) {
  const dialog = input.closest('.search-dialog')
  const resultsContainer = dialog.querySelector('.search-dialog--results')
  dialog.setAttribute('aria-label', 'Search the documentation')

  let debounceTimer = null
  // The query whose results are on screen, and the one the reader is waiting for.
  let pendingQuery = null

  function scheduleSearch() {
    state.query = input.value
    clearTimeout(debounceTimer)
    debounceTimer = setTimeout(runSearch, SEARCH.debounceMs)
  }

  // Nothing changes on screen until the full text has answered: the previous list stays
  // until the new one is complete, and is then swapped in at once.
  async function runSearch() {
    const query = input.value.trim()
    pendingQuery = query

    if (query.length < SEARCH.minQueryLength) {
      render(null)
      return
    }

    const { pages, late } = await searchPages(query)

    // Another keystroke landed while we were waiting; that search owns the screen now.
    if (pendingQuery !== query) return

    // No pages at all means the index failed to load, failed to answer or took too long.
    render(pages ? { query, rows: listRows(pages) } : { query, unavailable: true })

    // The full text answered too late for the list above. When it does answer, and the
    // reader is still looking at this query, the list replaces the message at once.
    late?.then((found) => {
      if (found && pendingQuery === query && input.isConnected) render({ query, rows: listRows(found) })
    }, () => {})
  }

  function render(result) {
    if (!result) {
      resultsContainer.innerHTML = ''
      input.setAttribute('aria-expanded', 'false')
      return
    }

    const { query, rows = [], unavailable } = result
    const html = rows.map((row) => renderPage(row, query)).join('')

    if (html) {
      resultsContainer.innerHTML = html
    } else if (unavailable) {
      resultsContainer.innerHTML = `<div class="search-dialog--empty">${escapeHtml(MESSAGES.unavailable)}</div>`
    } else {
      resultsContainer.innerHTML = `<div class="search-dialog--empty">${escapeHtml(MESSAGES.noResults(query))}</div>`
    }

    input.setAttribute('aria-expanded', String(Boolean(html)))
    selectHit(hits()[0])
  }

  // API rows and Learn rows are told apart by color (search-dialog.sass).
  function areaClass(badge) {
    if (!badge) return ''
    return badge === 'Learn' ? '-learn' : '-api'
  }

  // One page, with the sections that matched beneath it. The page is a hit of its own,
  // because the reader may want the page rather than the paragraph.
  function renderPage({ page, deprecated }, query) {
    const badge = page.meta?.badge
    const isCode = badge && !AREA_BADGES.includes(badge)
    const title = page.meta?.title || page.url
    const sections = (page.sub_results || [])
      .filter((section) => normalizePath(section.url) !== normalizePath(page.url))
      .slice(0, SEARCH.maxSectionsPerPage)
    const excerpt = !sections.length && page.excerpt
      ? `<span class="search-dialog--excerpt">${page.excerpt}</span>`
      : ''

    return `
      <a class="search-dialog--hit -page ${isCode ? '-code' : ''} ${areaClass(badge)} ${deprecated ? '-deprecated' : ''}"
         href="${escapeHtml(normalizePath(page.url))}" up-layer="root" role="option" aria-selected="false">
        ${renderBadge(badge)}
        <span class="search-dialog--title">${highlight(title, query)}</span>
        ${excerpt}
      </a>
      ${sections.map((section) => `
        <a class="search-dialog--hit -section" href="${escapeHtml(normalizePath(section.url))}"
           up-layer="root" role="option" aria-selected="false">
          <span class="search-dialog--section">${escapeHtml(section.title)}</span>
          <span class="search-dialog--excerpt">${section.excerpt}</span>
        </a>
      `).join('')}
    `
  }

  function renderBadge(badge) {
    return `<span class="search-dialog--gutter">${badge ? `<span class="tag -ghost search-dialog--badge">${escapeHtml(badge)}</span>` : ''}</span>`
  }

  function hits() {
    return Array.from(resultsContainer.querySelectorAll('.search-dialog--hit'))
  }

  function selectedHit() {
    return resultsContainer.querySelector('.search-dialog--hit.-selected')
  }

  function selectHit(hit) {
    if (!hit) return
    const previous = selectedHit()
    previous?.classList.remove('-selected')
    previous?.setAttribute('aria-selected', 'false')
    hit.classList.add('-selected')
    hit.setAttribute('aria-selected', 'true')
    hit.scrollIntoView({ block: 'nearest' })
  }

  function moveSelection(step) {
    const all = hits()
    if (!all.length) return

    const index = all.indexOf(selectedHit())
    const next = (index + step + all.length) % all.length
    selectHit(all[next])
  }

  function onKeyDown(event) {
    switch (event.key) {
      case 'Escape':
        // The framework's first Escape only leaves a focused field, and the field is
        // where the reader always is. Here Escape closes, as the footer says.
        up.event.halt(event)
        up.layer.get(dialog).dismiss(':key')
        break
      case 'ArrowDown':
        moveSelection(1)
        event.preventDefault()
        break
      case 'ArrowUp':
        moveSelection(-1)
        event.preventDefault()
        break
      case 'Enter': {
        const hit = selectedHit()
        if (hit) {
          // The hit targets the root layer, which closes this dialog on the way.
          up.follow(hit)
          event.preventDefault()
        }
        break
      }
    }
  }

  input.addEventListener('input', scheduleSearch)
  input.addEventListener('keydown', onKeyDown)

  resultsContainer.addEventListener('mousemove', function(event) {
    const hit = event.target.closest('.search-dialog--hit')
    if (hit) selectHit(hit)
  })

  // Reopening brings the last query back, selected, so typing replaces it and the
  // arrow keys refine it, and runs it again against the current index.
  input.value = state.query
  input.select()
  load()
  if (state.query.trim()) runSearch()

  return () => clearTimeout(debounceTimer)
})

up.on('keydown', function(event) {
  if (event.key !== '/' || isSearchOpen()) return
  if (isTypingTarget(document.activeElement)) return
  if (event.metaKey || event.ctrlKey || event.altKey) return

  openSearch()
  event.preventDefault()
})

// The header's trigger stays a link to the reference, so that it does something useful
// without JavaScript. Catching it needs `up:link:follow`, not `click`: the site makes
// every link instant (unpoly_config.coffee), so Unpoly follows it on mousedown and no
// click event ever reaches the document. Halting the event is what stops the
// navigation.
up.on('up:link:follow', '.search-pill', function(event) {
  up.event.halt(event)
  openSearch(event.target)
})

// The search prompt on the /api hub is a button, so a plain click reaches it.
up.on('click', '.search-prompt', function(event, prompt) {
  openSearch(prompt)
})

// For specs, and for anything that wants to open the search without a click.
window.openSearch = openSearch
