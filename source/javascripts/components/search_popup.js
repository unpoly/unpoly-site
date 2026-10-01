// The site's search.
//
// Two indexes answer one query. The symbol sidecar (/search/symbols.json) holds every
// name a reader might type — features, modules, and the attributes and config keys the
// menu already treats as nodes. Pagefind holds the prose. Names are matched here, in
// memory, and rank above full-text hits, because someone typing "up-watch-delay" wants
// that attribute, not the paragraph that mentions it.
//
// Both are fetched on the first open, never on page load.

// Everything tunable about ranking and shape lives here, so that trying a different
// result mix is one edit rather than a hunt through the file.
const SEARCH = {
  minQueryLength: 2,
  debounceMs: 120,
  maxSymbols: 6,
  // Some names have several homes: [up-transition] is a selector of its own and a
  // modifying attribute of four other selectors. Showing every home would fill the
  // whole group with one name, so only the best-ranked one is listed and the rest are
  // reachable from the page it links to.
  oneRowPerName: true,
  maxPages: 8,
  maxSectionsPerPage: 3,
  symbolsUrl: '/search/symbols.json',
  pagefindUrl: '/pagefind/pagefind.js',
  // How well a name matched, lowest first. A param sinks below a feature that matched
  // equally well, and anything deprecated sinks below everything else.
  score: { exact: 0, prefix: 10, wordStart: 20, contains: 30, param: 4, deprecated: 100 },
}

const MESSAGES = {
  noResults: (query) => `No results for ${query}`,
  noIndex: 'Search index not built. Run bundle exec rake search:index.',
}

function normalize(text) {
  // A reader types "up-follow", the symbol is "[up-follow]", the config key is
  // "config.submitSelectors" — matching ignores the punctuation around the name.
  return text.toLowerCase().replace(/[[\]()]/g, '')
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

// Marks the matched part of a symbol name, so the eye lands where the match is.
function highlightName(name, query) {
  const at = normalize(name).indexOf(normalize(query))
  if (at === -1) return escapeHtml(name)

  // normalize() only lowercases and drops bracket characters, so offsets can shift.
  // Walking the original string keeps the marks on the right letters.
  let plain = 0
  let start = -1
  let end = -1
  for (let i = 0; i < name.length; i++) {
    if (!/[[\]()]/.test(name[i])) {
      if (plain === at) start = i
      if (plain === at + normalize(query).length) { end = i; break }
      plain++
    }
  }
  if (start === -1) return escapeHtml(name)
  if (end === -1) end = name.length

  return escapeHtml(name.slice(0, start)) +
    '<mark>' + escapeHtml(name.slice(start, end)) + '</mark>' +
    escapeHtml(name.slice(end))
}

class SymbolIndex {
  constructor(symbols) {
    this.symbols = symbols.map(([name, path, badge, title, owner, deprecated]) => ({
      name,
      path,
      badge,
      title: title || null,
      owner: owner || null,
      deprecated: deprecated === 1,
      haystack: normalize(name),
    }))
  }

  search(query, limit) {
    const needle = normalize(query)
    const scored = []

    for (const symbol of this.symbols) {
      const score = this.score(symbol, needle)
      if (score !== null) scored.push({ symbol, score })
    }

    scored.sort((a, b) => (
      a.score - b.score ||
      a.symbol.name.length - b.symbol.name.length ||
      a.symbol.name.localeCompare(b.symbol.name)
    ))

    const seen = new Set()
    const chosen = []
    for (const { symbol } of scored) {
      if (SEARCH.oneRowPerName) {
        if (seen.has(symbol.name)) continue
        seen.add(symbol.name)
      }
      chosen.push(symbol)
      if (chosen.length === limit) break
    }
    return chosen
  }

  score(symbol, needle) {
    const { haystack } = symbol
    let score

    if (haystack === needle) {
      score = SEARCH.score.exact
    } else if (haystack.startsWith(needle)) {
      score = SEARCH.score.prefix
    } else {
      const at = haystack.indexOf(needle)
      if (at === -1) return null
      // A match right after a separator reads as a word of its own: "follow" in
      // "up.follow" or "up:link:follow" beats "follow" buried inside another word.
      score = /[.:\-_]/.test(haystack[at - 1]) ? SEARCH.score.wordStart : SEARCH.score.contains
    }

    if (symbol.owner) score += SEARCH.score.param
    if (symbol.deprecated) score += SEARCH.score.deprecated
    return score
  }
}

up.compiler('.search-popup', function(popup) {
  const input = popup.querySelector('.search-popup--input')
  const resultsContainer = popup.querySelector('.search-popup--results')
  const closeButton = popup.querySelector('.search-popup--close')
  const backdrop = popup.querySelector('.search-popup--backdrop')

  let symbolIndex = null
  let pagefind = null
  let pagefindBroken = false
  let loading = null
  let debounceTimer = null
  let lastQuery = null
  let openerElement = null

  function isOpen() {
    return !popup.hidden
  }

  function open() {
    if (isOpen()) return

    openerElement = document.activeElement
    popup.hidden = false
    document.documentElement.classList.add('-search-open')
    input.focus()
    input.select()
    load()
    render()
  }

  function close() {
    if (!isOpen()) return

    popup.hidden = true
    document.documentElement.classList.remove('-search-open')
    input.setAttribute('aria-expanded', 'false')
    openerElement?.focus?.()
    openerElement = null
  }

  // Both indexes are fetched once, on the first open. A failure is remembered rather
  // than retried on every keystroke.
  function load() {
    loading ||= Promise.all([loadSymbols(), loadPagefind()])
    return loading
  }

  async function loadSymbols() {
    if (symbolIndex) return
    try {
      const response = await fetch(SEARCH.symbolsUrl)
      if (!response.ok) throw new Error(`HTTP ${response.status}`)
      const payload = await response.json()
      symbolIndex = new SymbolIndex(payload.symbols || [])
    } catch (error) {
      console.error('Could not load the search symbols: %o', error)
      symbolIndex = new SymbolIndex([])
    }
  }

  async function loadPagefind() {
    if (pagefind || pagefindBroken) return
    // A spec can put its own index here; nothing is fetched then.
    if (window.pagefind) {
      pagefind = window.pagefind
      return
    }
    try {
      pagefind = await import(SEARCH.pagefindUrl)
      await pagefind.options?.({ excerptLength: 25 })
    } catch (error) {
      // In the preview server this is the normal state until `rake search:index` runs.
      pagefindBroken = true
    }
  }

  function scheduleSearch() {
    clearTimeout(debounceTimer)
    debounceTimer = setTimeout(runSearch, SEARCH.debounceMs)
  }

  async function runSearch() {
    const query = input.value.trim()
    lastQuery = query

    if (query.length < SEARCH.minQueryLength) {
      render()
      return
    }

    await load()

    const symbols = symbolIndex.search(query, SEARCH.maxSymbols)
    const pages = await searchPages(query)

    // Another keystroke landed while we were waiting; that search owns the screen now.
    if (lastQuery !== query) return

    render({ query, symbols, pages })
  }

  async function searchPages(query) {
    if (!pagefind) return []

    try {
      const search = await pagefind.search(query)
      const wanted = search.results.slice(0, SEARCH.maxPages)
      return await Promise.all(wanted.map((result) => result.data()))
    } catch (error) {
      console.error('Full text search failed: %o', error)
      return []
    }
  }

  function render(state) {
    if (!state) {
      resultsContainer.innerHTML = ''
      input.setAttribute('aria-expanded', 'false')
      return
    }

    const { query, symbols, pages } = state
    const html = [
      ...symbols.map((symbol) => renderSymbol(symbol, query)),
      ...pages.map(renderPage),
    ].join('')

    if (html) {
      resultsContainer.innerHTML = html
    } else if (pagefindBroken && !symbols.length) {
      resultsContainer.innerHTML = `<div class="search-popup--empty">${escapeHtml(MESSAGES.noIndex)}</div>`
    } else {
      resultsContainer.innerHTML =
        `<div class="search-popup--empty">${escapeHtml(MESSAGES.noResults(query))}</div>`
    }

    input.setAttribute('aria-expanded', String(Boolean(html)))
    selectHit(hits()[0])
  }

  function renderSymbol(symbol, query) {
    const label = symbol.title || symbol.name
    const name = highlightName(symbol.name, query)
    const owner = symbol.owner
      ? `<span class="search-popup--owner">${escapeHtml(symbol.owner)}</span>`
      : ''
    const signature = symbol.title && !symbol.owner
      ? `<span class="search-popup--signature">${escapeHtml(label)}</span>`
      : ''

    return `
      <a class="search-popup--hit -symbol -code ${symbol.deprecated ? '-deprecated' : ''}"
         href="${escapeHtml(symbol.path)}" role="option" aria-selected="false">
        <span class="search-popup--name">${name}</span>
        ${owner}${signature}
        ${renderBadge(symbol.badge)}
      </a>
    `
  }

  // One page, with the sections that matched beneath it. The page is a hit of its own,
  // because the reader may want the page rather than the paragraph.
  // The area badges name a place; every other badge names a kind, and a page with a kind
  // is a reference page whose title is an identifier.
  const AREA_BADGES = ['Learn', 'API']

  function renderPage(page) {
    const badge = renderBadge(page.meta?.badge)
    const isCode = page.meta?.badge && !AREA_BADGES.includes(page.meta.badge)
    const sections = (page.sub_results || [])
      .filter((section) => section.url !== page.url)
      .slice(0, SEARCH.maxSectionsPerPage)
      .map((section) => `
        <a class="search-popup--hit -section" href="${escapeHtml(section.url)}"
           role="option" aria-selected="false">
          <span class="search-popup--section">${escapeHtml(section.title)}</span>
          <span class="search-popup--excerpt">${section.excerpt}</span>
        </a>
      `).join('')

    return `
      <a class="search-popup--hit -page ${isCode ? '-code' : ''}" href="${escapeHtml(page.url)}"
         role="option" aria-selected="false">
        <span class="search-popup--name">${escapeHtml(page.meta?.title || page.url)}</span>
        ${badge}
      </a>
      ${sections}
    `
  }

  function renderBadge(badge) {
    if (!badge) return ''
    return `<span class="tag -ghost search-popup--badge">${escapeHtml(badge)}</span>`
  }

  function hits() {
    return Array.from(resultsContainer.querySelectorAll('.search-popup--hit'))
  }

  function selectedHit() {
    return resultsContainer.querySelector('.search-popup--hit.-selected')
  }

  function selectHit(hit) {
    if (!hit) return
    selectedHit()?.classList.remove('-selected')
    selectedHit()?.setAttribute('aria-selected', 'false')
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
    if (!isOpen()) return

    switch (event.key) {
      case 'Escape':
        close()
        event.preventDefault()
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
          up.follow(hit)
          close()
          event.preventDefault()
        }
        break
      }
    }
  }

  function onGlobalKeyDown(event) {
    if (event.key !== '/' || isOpen()) return
    if (isTypingTarget(document.activeElement)) return
    if (event.metaKey || event.ctrlKey || event.altKey) return

    open()
    event.preventDefault()
  }

  // The header pill stays a link to the reference, so that it does something useful
  // without JavaScript. Catching it needs `up:link:follow`, not `click`: the site makes
  // every link instant (unpoly_config.coffee), so Unpoly follows it on mousedown and no
  // click event ever reaches the document. Halting the event is what stops the
  // navigation. The drawer's trigger is a button and has no such story.
  function onTriggerActivate(event) {
    up.event.halt(event)
    open()
  }

  input.addEventListener('input', scheduleSearch)
  popup.addEventListener('keydown', onKeyDown)
  closeButton.addEventListener('click', close)
  backdrop.addEventListener('click', close)

  resultsContainer.addEventListener('click', function(event) {
    if (event.target.closest('.search-popup--hit')) close()
  })

  resultsContainer.addEventListener('mousemove', function(event) {
    const hit = event.target.closest('.search-popup--hit')
    if (hit) selectHit(hit)
  })

  up.destructor(popup, up.on('keydown', onGlobalKeyDown))
  up.destructor(popup, up.on('up:link:follow', '.search-pill', onTriggerActivate))
  up.destructor(popup, up.on('click', '.search-trigger', onTriggerActivate))

  // For specs, and for anything that wants to open the search without a click.
  popup.openSearch = open
  popup.closeSearch = close
})
