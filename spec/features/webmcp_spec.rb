# The WebMCP tools (webmcp.js) that an AI agent in the reader's browser can call. No
# browser in CI implements the API, so the specs call the tools directly, and register
# them with a model context of their own.
describe 'WebMCP tools', type: :feature, js: true do

  def stub_pagefind(results)
    page.execute_script(<<~JS)
      window.pagefind = {
        options: async () => {},
        search: async () => ({ results: #{results.to_json}.map((data) => ({ data: async () => data })) }),
      }
    JS
  end

  # Runs a tool's execute() and returns what it resolved with. Wrapped, because
  # WebDriver takes an answer with an `error` key for an error of its own.
  def call_tool(name, input = {})
    page.evaluate_async_script(<<~JS, name, input)['value']
      let [name, input, done] = arguments
      webmcpTools.find((tool) => tool.name === name).execute(input).then((value) => done({ value }), (error) => done({ value: { thrown: String(error) } }))
    JS
  end

  it 'registers its tools with document.modelContext or navigator.modelContext, and with nothing where neither exists' do
    visit '/up.render'

    registered = page.evaluate_script(<<~JS)
      (function() {
        let names = []
        let context = { registerTool: (tool) => { names.push(tool.name); return Promise.resolve() } }
        let found = registerWebMCP(context)
        let none = registerWebMCP(undefined)
        return { found, none, names }
      })()
    JS
    expect(registered).to eq('found' => true, 'none' => false, 'names' => %w[search_docs get_page_markdown])

    tools = page.evaluate_script('webmcpTools.map((tool) => [tool.name, tool.annotations.readOnlyHint, tool.inputSchema.type])')
    expect(tools).to eq([['search_docs', true, 'object'], ['get_page_markdown', true, 'object']])
  end

  it 'does nothing, and logs nothing, in a browser without the API' do
    visit '/up.render'

    expect(page.evaluate_script("'modelContext' in document || 'modelContext' in navigator")).to be(false)

    # What the script did on boot, once more, with the console watched.
    result = page.evaluate_script(<<~JS)
      (function() {
        let calls = 0
        let original = { error: console.error, warn: console.warn, log: console.log }
        for (let level in original) console[level] = () => calls++
        try {
          return { registered: registerWebMCP(), calls }
        } finally {
          Object.assign(console, original)
        }
      })()
    JS
    expect(result).to eq('registered' => false, 'calls' => 0)
  end

  describe 'search_docs' do
    it 'answers with pages, their Markdown URLs and plain excerpts, and a skill tip only once' do
      visit '/up.render'
      stub_pagefind([
        { url: '/up-follow/', excerpt: 'Follows a <mark>link</mark>.', meta: { title: '[up-follow]', badge: 'HTML' } },
        { url: '/up-follow', excerpt: 'Again', meta: { title: '[up-follow]', badge: 'HTML' } },
        { url: '/following-links/', excerpt: 'How to follow', meta: { title: 'Following links', badge: 'Learn' } },
      ])
      origin = page.evaluate_script('location.origin')

      first = call_tool('search_docs', { query: 'follow' })
      expect(first['results']).to eq([
        { 'title' => '[up-follow]', 'kind' => 'HTML', 'url' => "#{origin}/up-follow", 'mdUrl' => "#{origin}/up-follow.md", 'excerpt' => 'Follows a link.' },
        { 'title' => 'Following links', 'kind' => 'Learn', 'url' => "#{origin}/following-links", 'mdUrl' => "#{origin}/following-links.md", 'excerpt' => 'How to follow' },
      ])
      expect(first['tip']).to include('https://unpoly.com/skill.md')

      second = call_tool('search_docs', { query: 'follow', limit: 1 })
      expect(second['results'].size).to eq(1)
      expect(second).not_to have_key('tip')
    end

    it 'asks for a query' do
      visit '/up.render'
      expect(call_tool('search_docs', {})).to eq('error' => 'Pass a query.')
    end

    it 'flags deprecated pages, and keeps a limit within bounds' do
      visit '/up.render'
      stub_pagefind((1..25).map { |n| { url: "/p#{n}", excerpt: '', meta: { title: "P#{n}", badge: 'JS', deprecated: (n == 1 ? 'true' : nil) }.compact } })

      results = call_tool('search_docs', { query: 'p', limit: 0 })['results']
      expect(results.size).to eq(8)
      expect(results.first['deprecated']).to be(true)
      expect(results.second).not_to have_key('deprecated')
      expect(call_tool('search_docs', { query: 'p', limit: 99 })['results'].size).to eq(20)
    end

    it 'points to the index when search is unavailable' do
      visit '/up.render'
      page.execute_script("window.pagefind = { options: async () => {}, search: async () => { throw new Error('broken index') } }")

      expect(call_tool('search_docs', { query: 'follow' })['error']).to include('unavailable', 'https://unpoly.com/index.md')
    end
  end

  describe 'get_page_markdown' do
    it 'reads the current page’s Markdown twin by default' do
      visit '/start/links'

      result = call_tool('get_page_markdown')
      expect(result['url']).to end_with('/start/links.md')
      expect(result['markdown']).to include('# Link to fragments')
    end

    it 'reads a page by URL or path, the root as the index' do
      visit '/start/links'

      expect(call_tool('get_page_markdown', { url: '/up.render#options.target' })['markdown']).to include('# up.render(')
      expect(call_tool('get_page_markdown', { url: 'https://unpoly.com/up.render' })['url']).to end_with('/up.render.md')
      expect(call_tool('get_page_markdown', { url: '/' })['markdown']).to start_with('# Unpoly')
    end

    it 'points to the search and the index when there is no such page' do
      visit '/start/links'

      result = call_tool('get_page_markdown', { url: '/no-such-page' })
      expect(result['error']).to include('No Markdown at', 'search_docs', 'https://unpoly.com/index.md')

      expect(call_tool('get_page_markdown', { url: 'https://example.com/x' })['error']).to start_with('Only pages of the Unpoly docs')
      expect(call_tool('get_page_markdown', { url: 'http://' })['error']).to start_with('Not a URL')
    end
  end

end
