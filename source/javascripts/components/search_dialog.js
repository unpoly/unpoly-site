// The site's search.
//
// It opens as a modal overlay (up.layer.open), so the framework provides the dialog:
// backdrop, focus trap and restore, Escape, scroll lock, stacking. This file provides
// what goes into it, see source/_search_dialog.html.erb.
//
// Pagefind answers a query with pages (search_core.js, which also holds the ranking),
// and this file lists them as one list: each page with its title, its badge, and the
// sections that matched beneath it.
//
// The index is fetched on the first open, never on page load.

const MESSAGES = {
  noResults: (query) => `No results for ${query}`,
  unavailable: 'Search is unavailable right now.',
  // Read out by screen readers after each search (the status line in the dialog).
  status: (count, query) => count ? `${count} ${count === 1 ? 'result' : 'results'} for '${query}'` : 'No results',
}

// The badges that name an area rather than a kind of code. Rows wearing one have a prose
// title; every other row is named after an identifier and set as code.
const AREA_BADGES = ['Learn', 'API']

function normalize(text) {
  // A reader types "up-follow", the title is "[up-follow]" — highlighting ignores the
  // punctuation around the name.
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
  const current = []
  const deprecated = []
  for (const page of pages) {
    if (page.meta?.deprecated) {
      deprecated.push({ page, deprecated: true })
    } else {
      current.push({ page })
    }
  }

  return [...current, ...deprecated].slice(0, SEARCH.maxPages)
}

// The reader's last query lives as long as the page, not the dialog: reopening the
// search brings it back.
const state = {
  query: '',
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
  const notice = dialog.querySelector('.search-dialog--notice')
  const tip = dialog.querySelector('.search-dialog--tip')
  const status = dialog.querySelector('.search-dialog--status')
  // The framework makes the overlay's box the dialog (role="dialog", aria-modal), so
  // the box is what needs the name.
  dialog.querySelector('up-modal-box').setAttribute('aria-label', 'Search the documentation')

  let debounceTimer = null
  // The query whose results are on screen, and the one the reader is waiting for.
  let pendingQuery = null

  function scheduleSearch() {
    // The tip is for the empty dialog. Once the reader types it is gone for good.
    tip.hidden = true
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
    resultsContainer.innerHTML = ''
    notice.innerHTML = ''
    input.removeAttribute('aria-activedescendant')

    if (!result) {
      input.setAttribute('aria-expanded', 'false')
      status.textContent = ''
      return
    }

    const { query, rows = [], unavailable } = result
    const html = rows.map((row) => renderPage(row, query)).join('')

    if (html) {
      resultsContainer.innerHTML = html
      // Stable ids, so the field can point at the selected option.
      hits().forEach((hit, index) => { hit.id = `search-dialog-hit-${index}` })
    } else {
      const message = unavailable ? MESSAGES.unavailable : MESSAGES.noResults(query)
      notice.innerHTML = `<div class="search-dialog--empty">${escapeHtml(message)}</div>`
    }

    status.textContent = unavailable ? MESSAGES.unavailable : MESSAGES.status(rows.length, query)
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
          <span class="search-dialog--context">${escapeHtml(title)} — </span>
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
    input.setAttribute('aria-activedescendant', hit.id)
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
  tip.hidden = Boolean(state.query)
  input.select()
  loadSearchIndex()
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

// The header's trigger says what it does: it opens a dialog, and / opens it too. Only
// with JavaScript, which is what makes it more than a link to the reference. The
// aria-label contains the visible text ("Search docs"); the title is the tooltip.
up.compiler('.search-pill', function(pill) {
  pill.setAttribute('aria-haspopup', 'dialog')
  pill.setAttribute('aria-keyshortcuts', '/')
  pill.setAttribute('aria-label', 'Search docs — opens the search dialog')
  pill.setAttribute('title', 'Press / to search')
})

// For specs, and for anything that wants to open the search without a click.
window.openSearch = openSearch
