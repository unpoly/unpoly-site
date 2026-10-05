# Every page family must get its own frame however the reader arrives: on a direct
# load, through a fragment update from any other family, from a search result, from the
# drawer, from the logo, and when history restores it. The frame is what the server
# renders around the content: the sidebar and its menu, the torso modifiers that
# decide the width mode, and the text column.
#
# Fragment navigation only swaps Unpoly's main target, so any part of the frame that
# lives outside that target survives from the page the reader came from. These specs
# catch that by comparing each arrival with a direct load of the same URL.
describe 'the frame on every way into a page', type: :feature, js: true do

  # One representative URL per page family.
  FRAME_FAMILIES = {
    landing: '/',
    learn: '/targeting-fragments',
    api: '/up.render',
    hub: '/api',
    article: '/support',
  }.freeze

  # Sidebar menus, by family.
  FRAME_MENUS = {
    learn: '/learn/menu',
    api: '/api/menu',
    hub: '/api/menu',
  }.freeze

  # Direct-load frames, measured once per driver and URL (see #reference_frame).
  FRAME_REFERENCES = {}

  FRAME_JS = <<~JS.freeze
    (function() {
      let q = (s) => document.querySelector(s)
      let left = q('.guide--left')
      // A menu counts once its nodes are there, not while a placeholder waits for them.
      let menu = q('.guide--menu .menu--nodes')?.closest('.menu')
      let content = q('.guide--content').getBoundingClientRect()
      return {
        torso: [...q('.guide--torso').classList].filter((c) => c.startsWith('-')).sort().join(' '),
        sidebar: !!left && left.getClientRects().length > 0 && getComputedStyle(left).display !== 'none',
        menu: menu && new URL(up.fragment.source(menu), location.href).pathname,
        column: [Math.round(content.left), Math.round(content.width)],
        windowWidth: window.innerWidth,
        overflows: document.documentElement.scrollWidth > window.innerWidth,
      }
    })()
  JS

  def frame
    page.evaluate_script(FRAME_JS)
  end

  # A menu loads after the page, so a frame is only final once it has.
  def settled_frame
    deadline = Time.now + Capybara.default_max_wait_time
    loop do
      current = frame
      return current if !current['sidebar'] || current['menu'] || Time.now > deadline
      sleep 0.1
    end
  end

  # The frame a direct load of the URL renders, measured once per driver.
  def reference_frame(path)
    FRAME_REFERENCES[[Capybara.current_driver, path]] ||= begin
      visit path
      settled_frame
    end
  end

  # Marks the document, so we can tell a fragment update from a full page load.
  def mark_document
    page.execute_script('window.frameMark = "marked"')
  end

  def expect_fragment_update
    expect(page.evaluate_script('window.frameMark')).to eq('marked'), 'expected a fragment update, but the page was loaded in full'
  end

  def expect_frame_of(path)
    expect(page).to have_current_path(path)
    expected = FRAME_REFERENCES.fetch([Capybara.current_driver, path])
    deadline = Time.now + Capybara.default_max_wait_time
    actual = nil
    loop do
      actual = settled_frame
      break if actual == expected || Time.now > deadline
      sleep 0.1
    end
    expect(actual).to eq(expected), "frame of #{path} differs from a direct load:\n  expected #{expected}\n  got      #{actual}"
  end

  # Measures the reference frames before the example navigates, so that measuring
  # does not interrupt a navigation sequence.
  def prepare_references(*paths)
    paths.each { |path| reference_frame(path) }
  end

  # Follows a plain link to the path, the way any link in the content would be followed.
  def follow_link_to(path)
    page.execute_script(<<~JS, path)
      let link = document.createElement('a')
      link.href = arguments[0]
      link.id = 'frame-spec-link'
      link.textContent = 'Go'
      document.querySelector('.guide--content').prepend(link)
    JS
    find('#frame-spec-link').click
  end

  def click_logo
    find('.guide--head a[href="/"]').click
  end

  def click_header_link(label)
    within('.guide--head') { click_link(label) }
  end

  describe 'a direct load' do

    it 'renders the landing full width, without a sidebar' do
      frame = reference_frame(FRAME_FAMILIES[:landing])

      expect(frame['torso']).to eq('-full-width')
      expect(frame['sidebar']).to be(false)
      expect(frame['column']).to eq([0, frame['windowWidth']])
      expect(frame['overflows']).to be(false)
    end

    [:learn, :api, :hub].each do |family|
      it "renders a #{family} page with its own section's menu in the sidebar" do
        frame = reference_frame(FRAME_FAMILIES[family])

        expect(frame['torso']).to eq('')
        expect(frame['sidebar']).to be(true)
        expect(frame['menu']).to eq(FRAME_MENUS[family])
        expect(frame['overflows']).to be(false)
      end
    end

    {
      '/learn' => '/learn/menu',
      '/up.link' => '/api/menu',
      '/changes' => '/changes/menu',
      '/install' => '/learn/menu',
    }.each do |path, menu|
      it "renders #{path} with the #{menu} sidebar" do
        frame = reference_frame(path)

        expect(frame['torso']).to eq('')
        expect(frame['sidebar']).to be(true)
        expect(frame['menu']).to eq(menu)
        expect(frame['overflows']).to be(false)
      end
    end

    it 'gives an article page a centred column without a sidebar' do
      frame = reference_frame(FRAME_FAMILIES[:article])

      expect(frame['torso']).to eq('-article')
      expect(frame['sidebar']).to be(false)
      left, width = frame['column']
      expect((left - (frame['windowWidth'] - left - width)).abs).to be <= 1
      expect(frame['overflows']).to be(false)
    end

    it 'sets text in one column, at the same place on every page with a sidebar' do
      # Pages with and without a contents rail, a hub and a reference page: the text
      # never moves or changes its width between them.
      columns = ['/learn', '/api', '/targeting-fragments', '/up.render', '/up.link', '/changes', '/install'].map do |path|
        [path, reference_frame(path)['column']]
      end

      expect(columns.map(&:last).uniq.size).to eq(1), "columns differ: #{columns.to_h}"
    end

    it 'sets an article page in a column as wide as the documentation' do
      expect(reference_frame(FRAME_FAMILIES[:article])['column'].last).to eq(reference_frame(FRAME_FAMILIES[:learn])['column'].last)
    end

    it 'makes the column no narrower than 660px where the contents rail appears' do
      expect(reference_frame(FRAME_FAMILIES[:learn])['column'].last).to be_between(660, 662)
    end

  end

  # The torso is a flexbox row: sidebar, text, contents rail. The text has priority:
  # its column takes free space until it reaches 880px, and only then do the flanks
  # grow beyond 270px, both alike, up to 400px. Where a flank is hidden, its space goes
  # to the column, so the column snaps from 880px to 660px where the rail appears at
  # 1280px (accepted). An article page keeps empty flanks, so its column is as wide as
  # a documentation page's at every window width, and centred in the window.
  describe 'the flanks and the text column across window widths' do

    FLANKS_JS = <<~JS.freeze
      (function() {
        let box = (s) => { let e = document.querySelector(s); return e && e.getClientRects().length ? e.getBoundingClientRect() : null }
        let sidebar = box('.guide--left'), rail = box('.guide--right')
        let content = box('.guide--content')
        return {
          sidebar: sidebar && sidebar.width,
          rail: rail && rail.width,
          column: content.width,
          offCentre: content.left + content.width / 2 - window.innerWidth / 2,
          overflows: document.documentElement.scrollWidth > window.innerWidth,
        }
      })()
    JS

    def flanks_at(path)
      visit path
      page.evaluate_script(FLANKS_JS)
    end

    {
      selenium_phone:         [390,  nil, nil, 350, 0],
      selenium_small_desktop: [1100, 270, nil, 750, 135],
      selenium_below_rail:    [1279, 319, nil, 880, 159.5],
      selenium:               [1280, 270, 270, 660, 0],
      selenium_wide:          [1500, 270, 270, 880, 0],
      selenium_wider:         [1680, 360, 360, 880, 0],
      selenium_widest:        [1920, 400, 400, 880, 0],
    }.each do |driver, (window, sidebar, rail, column, off_centre)|
      it "gives a #{window}px window a #{column}px column, a #{sidebar || 'hidden'} sidebar and a #{rail || 'hidden'} rail", driver: driver do
        docs = flanks_at('/loading-state')

        expect(docs['sidebar']).to sidebar ? be_within(0.5).of(sidebar) : be_nil
        expect(docs['rail']).to rail ? be_within(0.5).of(rail) : be_nil
        expect(docs['column']).to be_within(0.5).of(column)
        expect(docs['offCentre']).to be_within(0.5).of(off_centre)
        expect(docs['overflows']).to be(false)

        # A page without contents reserves the rail all the same.
        hub = flanks_at('/api')
        expect(hub['column']).to be_within(0.5).of(docs['column'])
        expect(hub['offCentre']).to be_within(0.5).of(docs['offCentre'])

        article = flanks_at('/support')
        expect(article['column']).to be_within(0.5).of(docs['column'])
        expect(article['offCentre'].abs).to be <= 0.5
      end
    end

  end

  describe 'a fragment update from another family' do

    FRAME_FAMILIES.each do |from, from_path|
      FRAME_FAMILIES.each do |to, to_path|
        next if from == to

        it "renders the #{to} frame when coming from the #{from} page" do
          prepare_references(to_path)
          visit from_path
          mark_document

          follow_link_to(to_path)

          expect_frame_of(to_path)
          expect_fragment_update
        end
      end
    end

    it 'keeps rendering the right frame across a chain of updates' do
      prepare_references('/learn', '/api', '/support', '/')
      visit '/'
      mark_document

      click_header_link('Learn')
      expect_frame_of('/learn')
      click_header_link('API')
      expect_frame_of('/api')
      click_header_link('Support')
      expect_frame_of('/support')
      click_logo
      expect_frame_of('/')
      expect_fragment_update
    end

  end

  describe 'the logo' do

    (FRAME_FAMILIES.keys - [:landing]).each do |from|
      it "renders the landing full width when clicked on the #{from} page" do
        prepare_references('/')
        visit FRAME_FAMILIES[from]
        mark_document

        click_logo

        expect_frame_of('/')
        expect_fragment_update
      end
    end

  end

  describe 'a search result' do

    def stub_pagefind(results)
      page.execute_script(<<~JS)
        window.pagefind = {
          options: async () => {},
          search: async () => ({ results: #{results.to_json}.map((data) => ({ data: async () => data })) })
        }
      JS
    end

    def open_search_and_pick(query, hit_css)
      find('.search-pill', visible: :all).click
      find('.search-dialog--input').set(query)
      find(hit_css, match: :first).click
    end

    it 'renders the API frame when picked on the landing' do
      prepare_references('/up.render')
      visit '/'
      stub_pagefind([{ url: '/up.render', meta: { title: 'up.render([target], [options])', badge: 'JS' }, sub_results: [] }])
      mark_document

      open_search_and_pick('up.render', '.search-dialog--hit[href$="/up.render"]')

      expect_frame_of('/up.render')
      expect_fragment_update
    end

    it 'renders the Learn frame when a Learn page is picked on the landing' do
      prepare_references('/targeting-fragments')
      visit '/'
      stub_pagefind([{ url: '/targeting-fragments', meta: { title: 'Targeting fragments', badge: 'Learn' }, sub_results: [] }])
      mark_document

      open_search_and_pick('targeting', '.search-dialog--hit.-page[href$="/targeting-fragments"]')

      expect_frame_of('/targeting-fragments')
      expect_fragment_update
    end

    it 'renders the Learn frame when picked on an article page' do
      prepare_references('/targeting-fragments')
      visit '/support'
      stub_pagefind([{ url: '/targeting-fragments', meta: { title: 'Targeting fragments', badge: 'Learn' }, sub_results: [] }])
      mark_document

      open_search_and_pick('targeting', '.search-dialog--hit[href$="/targeting-fragments"]')

      expect_frame_of('/targeting-fragments')
      expect_fragment_update
    end

    it 'renders the Learn frame when picked on an API page' do
      prepare_references('/targeting-fragments')
      visit '/up.render'
      stub_pagefind([{ url: '/targeting-fragments', meta: { title: 'Targeting fragments', badge: 'Learn' }, sub_results: [] }])
      mark_document

      open_search_and_pick('targeting', '.search-dialog--hit[href$="/targeting-fragments"]')

      expect_frame_of('/targeting-fragments')
      expect_fragment_update
    end

  end

  describe 'history' do

    it 'restores the frame of every page after mixed navigation' do
      prepare_references('/', '/learn', '/up.render', '/support')
      visit '/'
      mark_document

      click_header_link('Learn')
      expect_frame_of('/learn')
      follow_link_to('/up.render')
      expect_frame_of('/up.render')
      click_header_link('Support')
      expect_frame_of('/support')
      click_logo
      expect_frame_of('/')

      %w[/support /up.render /learn /].each do |path|
        page.go_back
        expect_frame_of(path)
      end

      %w[/learn /up.render /support /].each do |path|
        page.go_forward
        expect_frame_of(path)
      end

      expect_fragment_update
    end

  end

  describe 'on a phone', driver: :selenium_phone do

    def open_drawer
      find('.guide--head a[href="/menu/narrow"]').click
      expect(page).to have_css('up-drawer .menu')
    end

    it 'gives a documentation page the same frame as a direct load when entered from the landing' do
      prepare_references('/targeting-fragments')
      visit '/'
      mark_document

      follow_link_to('/targeting-fragments')

      expect_frame_of('/targeting-fragments')
      expect_fragment_update
    end

    it 'renders the landing full width when the logo is clicked on an API page' do
      prepare_references('/')
      visit '/up.render'
      mark_document

      click_logo

      expect_frame_of('/')
      expect_fragment_update
    end

    it 'renders the article frame when the drawer leads from the landing to Support' do
      prepare_references('/support')
      visit '/'
      mark_document

      open_drawer
      within('up-drawer') { find('a[href="/support"]', match: :first).click }

      expect_frame_of('/support')
      expect_fragment_update
    end

    it 'renders the API frame when the drawer leads from an article page to a module' do
      prepare_references('/up.link')
      visit '/support'
      mark_document

      open_drawer
      within('up-drawer') do
        # Modules sit one level down, behind the API row's collapser.
        find('.menu--nodes > .node > button.node--toggle[aria-label="Expand API"]').click
        find('a[href="/up.link"]', match: :first).click
      end

      expect_frame_of('/up.link')
      expect_fragment_update
    end

  end

end
