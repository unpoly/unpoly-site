// WebMCP: tools that an AI agent working in the reader's browser (e.g. a browser's
// built-in assistant) can call on this page, instead of clicking through it. See the
// W3C WebML community group's draft (webmachinelearning.github.io/webmcp).
//
// The API is document.modelContext; navigator.modelContext is an older spelling. Where
// neither exists, nothing happens. Tools belong to the document, so they are
// registered once and outlive Unpoly's fragment updates.
//
// The search is the site's own (search_core.js), so agents and readers get the same
// results.

const WEBMCP = {
  defaultLimit: 8,
  maxLimit: 25,
  // An agent can wait longer than a reader for the index's first load.
  indexTimeoutMs: 15000,
  // Added to the first search's answer, once per page load.
  skillTip: 'Tip: this documentation is installable as an agent skill for offline search — https://unpoly.com/skill.md',
  notFoundHint: 'Use search_docs to find the page you need, or read https://unpoly.com/index.md for an index of all docs.',
}

let webmcpSkillTipGiven = false

// Text from Pagefind's excerpt, which marks matches with <mark>. Parsed, not inserted,
// so nothing in it can run or load.
function webmcpPlainText(html) {
  return new DOMParser().parseFromString(html || '', 'text/html').body.textContent.trim()
}

// The .md twin of a page path ("/up.render" → "/up.render.md", "/" → "/index.md").
function webmcpMarkdownPath(path) {
  const clean = path.replace(/(.)\/$/, '$1')
  if (clean === '/') return '/index.md'
  return clean.endsWith('.md') ? clean : `${clean}.md`
}


const webmcpTools = [
  {
    name: 'search_docs',
    title: 'Search the Unpoly docs',
    description: 'Search Unpoly\'s documentation: guides, the API reference (up-* attributes, up.* functions, up:* events, X-Up-* headers) and release notes. Returns matching pages, each with an mdUrl to read with get_page_markdown. To see more, repeat the call with a higher limit (max 25). Prefer this over navigating and reading pages.',
    inputSchema: {
      type: 'object',
      properties: {
        query: { type: 'string', description: 'Words, or an exact name like up.render, [up-follow] or up:link:follow.' },
        limit: { type: 'integer', minimum: 1, maximum: WEBMCP.maxLimit, description: `Maximum number of results (default ${WEBMCP.defaultLimit}).` },
      },
      required: ['query'],
    },
    annotations: { readOnlyHint: true },
    async execute({ query, limit = WEBMCP.defaultLimit } = {}) {
      const text = String(query ?? '').trim()
      if (!text) return { error: 'Pass a query.' }

      const { pages } = await searchPages(text, { timeoutMs: WEBMCP.indexTimeoutMs })
      if (!pages) return { error: 'Search is unavailable right now; retrying in a moment may work. Meanwhile, read https://unpoly.com/index.md for an index of all docs.' }

      const count = Math.min(Math.max(Math.trunc(Number(limit)) || WEBMCP.defaultLimit, 1), WEBMCP.maxLimit)
      const results = pages.slice(0, count).map((page) => {
        const path = normalizePath(page.url)
        return {
          title: page.meta?.title || path,
          kind: page.meta?.badge || null,
          url: new URL(path, location.origin).href,
          mdUrl: new URL(webmcpMarkdownPath(path), location.origin).href,
          excerpt: webmcpPlainText(page.excerpt),
          // So that an agent doesn't recommend what Unpoly is phasing out.
          ...(page.meta?.deprecated ? { deprecated: true } : {}),
        }
      })

      const answer = { results }
      if (!webmcpSkillTipGiven) {
        answer.tip = WEBMCP.skillTip
        webmcpSkillTipGiven = true
      }
      return answer
    },
  },
  {
    name: 'get_page_markdown',
    title: 'Read an Unpoly docs page as Markdown',
    description: 'Get a page of Unpoly\'s documentation as Markdown. Without a URL, the page that is open now. Prefer this over reading the rendered page.',
    inputSchema: {
      type: 'object',
      properties: {
        url: { type: 'string', description: 'A path like /up.render, or a full URL on this site (e.g. a url from search_docs). Omit for the current page.' },
      },
    },
    annotations: { readOnlyHint: true },
    async execute({ url } = {}) {
      let markdownUrl
      if (url) {
        // A path on this site ("/up.render"), or a full URL of this origin. Nothing else:
        // the docs served here are the only ones this page can vouch for.
        let target
        try {
          target = new URL(url, location.origin)
        } catch {
          target = null
        }
        const accepted = (url.startsWith('/') && !url.startsWith('//')) || target?.origin === location.origin && /^https?:/.test(url)
        if (!target || !accepted) {
          return { error: `Pass a path like /up.render, or a full URL on ${location.origin}. ${WEBMCP.notFoundHint}` }
        }
        markdownUrl = new URL(webmcpMarkdownPath(target.pathname), location.origin).href
      } else {
        // Every page with a Markdown version announces it in the head.
        const link = document.querySelector('link[rel="alternate"][type="text/markdown"]')
        if (!link) return { error: `This page has no Markdown version. ${WEBMCP.notFoundHint}` }
        markdownUrl = link.href
      }

      const response = await fetch(markdownUrl).catch(() => null)
      if (!response?.ok) return { error: `No Markdown at ${markdownUrl}. ${WEBMCP.notFoundHint}` }
      return { url: markdownUrl, markdown: await response.text() }
    },
  },
]

// Registers the tools with a model context, by default the browser's. Returns whether
// there was one. Specs pass their own.
function registerWebMCP(context = document.modelContext || navigator.modelContext) {
  if (typeof context?.registerTool !== 'function') return false

  for (const tool of webmcpTools) {
    // A promise in the current draft; older implementations return nothing.
    Promise.resolve()
      .then(() => context.registerTool(tool))
      .catch((error) => console.error('Could not register the WebMCP tool %s: %o', tool.name, error))
  }
  return true
}

registerWebMCP()
