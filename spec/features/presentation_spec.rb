# Guards for what the 2026 restyling must not break. These are structural, not
# pixel-level: they check that the pieces a page is built from are still there
# and still laid out, on the kinds of page most likely to be forgotten.
describe 'presentation', type: :feature, js: true do

  # The one thing a stylesheet can silently take away from every page at once.
  def page_overflows_horizontally?
    page.evaluate_script(<<~JS)
      (function() {
        let doc = document.documentElement
        return doc.scrollWidth - doc.clientWidth > 1
      })()
    JS
  end

  describe 'no page scrolls sideways' do
    # The divider that used to bleed half a viewport, inline code that could not
    # wrap and tables with nowhere to scroll each did this to every page they
    # appeared on, hidden behind `overflow-x: hidden`.
    %w[
      /
      /up.render
      /up-follow
      /install
      /preserving-elements
      /learn
      /changes
    ].each do |path|
      it "holds its width on #{path}" do
        visit path
        expect(page_overflows_horizontally?).to be(false)
      end
    end

    it 'lets a table scroll inside the text column rather than widening the page' do
      visit '/install'

      scrollable = page.evaluate_script(<<~JS)
        (function() {
          let tables = Array.from(document.querySelectorAll('.prose table'))
          return tables.length > 0 && tables.every(function(t) {
            return getComputedStyle(t).overflowX === 'auto'
          })
        })()
      JS

      expect(scrollable).to be(true)
    end
  end

  describe 'a reference page' do
    before { visit '/up-follow' }

    # Parameter groups are a recent addition to the doc format and the one piece
    # of information architecture the restyling was told not to lose.
    it 'keeps its parameters in named groups' do
      expect(page).to have_css('.pearl-title', text: /navigation/i)
      expect(page).to have_css('.pearl-title', text: /request/i)
    end

    it 'keeps the type and optionality chips on a parameter' do
      expect(page).to have_css('.feature--param .tag.-ghost', text: /optional/i)
      expect(page).to have_css('.feature--param-optionality')
    end

    it 'points at the guides that explain it' do
      visit '/up.link'
      expect(page).to have_css('.learn-refs a')
    end
  end

  describe 'a guide page' do
    before { visit '/loading-state' }

    it 'offers its own contents' do
      expect(page).to have_css('.toc .toc--item a')
    end

    it 'ends with the way on through the chapter' do
      expect(page).to have_css('.reading-nav--link.-next .reading-nav--title')
    end

    # "Next" is what most readers want at the end, so it is a button; "Previous" stays
    # a quiet link. No line sets the pair off from the text, and a wide space sets it
    # off from the muted footer.
    it 'makes Next a button, sets the pair off without a line, and leaves room before the footer' do
      tail = page.evaluate_script(<<~JS)
        (function() {
          let style = (s) => getComputedStyle(document.querySelector(s))
          let box = (s) => document.querySelector(s).getBoundingClientRect()
          return {
            next: [style('.reading-nav--link.-next').borderTopStyle, style('.reading-nav--link.-next').paddingLeft],
            previous: style('.reading-nav--link.-previous').borderTopStyle,
            line: style('.reading-nav').borderTopStyle,
            footerGap: Math.round(box('.guide--footer').top - box('.reading-nav').bottom),
          }
        })()
      JS

      expect(tail['next']).to eq(['solid', '16px'])
      expect(tail['previous']).to eq('none')
      expect(tail['line']).to eq('none')
      expect(tail['footerGap']).to eq(64)
    end
  end

  describe 'a read-more link closing an overview section' do
    it 'stands apart from the links in the text, and stays quieter than the Next button' do
      # Embedded the way an overview's Markdown embeds it.
      visit '/loading-state'
      page.execute_script(<<~JS)
        document.querySelector('.prose').insertAdjacentHTML('beforeend',
          '<p>A sentence with <a href="/progress-bar">a link</a>.</p><p class="read-more"><a href="/progress-bar">Read more: Progress bar</a></p>')
      JS

      links = page.evaluate_script(<<~'JS')
        (function() {
          let style = (s) => { let c = getComputedStyle(document.querySelector(s)); return { color: c.color, underline: c.textDecorationLine, weight: c.fontWeight, border: c.borderTopStyle } }
          return {
            readMore: style('.read-more a'),
            arrow: getComputedStyle(document.querySelector('.read-more a'), '::after').content,
            text: style('.prose p:not(.read-more) a'),
            next: style('.reading-nav--link.-next'),
            nextTitle: style('.reading-nav--link.-next .reading-nav--title'),
          }
        })()
      JS

      expect(links['readMore']['underline']).to eq('none')
      expect(links['readMore']['color']).not_to eq(links['text']['color'])
      expect(links['arrow']).not_to eq('none')
      # The Next button has a border and a bold title; the read-more link has neither.
      expect(links['next']['border']).to eq('solid')
      expect(links['readMore']['border']).to eq('none')
      expect(links['nextTitle']['weight']).to eq('700')
      expect(links['readMore']['weight']).to eq('400')
    end
  end

  describe 'an aside in a guide' do
    it 'stands out by a quiet tint over the whole column, without a border' do
      # Embedded the way a guide's Markdown embeds it, so the spec does not depend on
      # which guide currently has one.
      visit '/loading-state'
      page.execute_script(<<~JS)
        document.querySelector('.prose').insertAdjacentHTML('beforeend',
          '<div class="aside"><h2>Related chapters</h2><p>Spinners are covered by the <a href="/progress-bar">Progress bar</a> page.</p></div>')
      JS

      aside = page.evaluate_script(<<~JS)
        (function() {
          let aside = document.querySelector('.prose .aside')
          let style = getComputedStyle(aside)
          let heading = aside.querySelector('h2')
          return {
            background: style.backgroundColor,
            border: style.borderTopStyle,
            headingLine: heading ? getComputedStyle(heading).borderTopStyle : 'none',
            width: aside.getBoundingClientRect().width,
            column: document.querySelector('.guide--content').getBoundingClientRect().width,
          }
        })()
      JS

      expect(aside['background']).to eq('rgba(0, 0, 0, 0.03)')
      expect(aside['border']).to eq('none')
      expect(aside['headingLine']).to eq('none')
      expect(aside['width']).to eq(aside['column'])
    end
  end

  describe 'a hub page' do
    it 'lists every topic with the pages under it' do
      visit '/learn'

      expect(page).to have_css('.topic-preview', minimum: 5)
      expect(page).to have_css('.topic-preview--children a', minimum: 20)
    end
  end

  describe 'the generated index of a page group without an overview' do
    it 'lists the formats with their own summaries, and nothing else' do
      visit '/formats'

      expect(page).to have_css('h1', text: 'Formats')
      expect(page.all('.guide--content a.topic-preview--title').map { |link| URI.parse(link[:href]).path }).to eq(['/url-patterns', '/relaxed-json'])
    end

    it 'is one ordinary row in the API sidebar' do
      visit '/up.render'
      expect(page).to have_css('.guide--menu .menu--nodes')

      expect(page).to have_css('.guide--menu a.node--self[href="/formats"]', count: 1)
      expect(page).to have_no_css('.guide--menu .node.-group > .node--self', text: /formats/i, visible: :all)
    end
  end

  describe 'a runnable example' do
    before { visit '/examples/modal' }

    it 'shows its source files beside the running demo' do
      expect(page).to have_css('.example--file', minimum: 2)
      expect(page).to have_css('.example--demo')
      expect(page).to have_css('.example .action', text: 'Back')
    end
  end

  describe 'an overlay' do
    it 'renders the version switcher in a popup with the site chrome' do
      visit '/loading-state'

      find('.version-nav').click

      expect(page).to have_css('up-popup .choice')
      expect(page).to have_css('up-popup a', text: /\d+\.\d+/)
    end
  end

  describe 'the sidebar tree' do
    before { visit '/up.link' }

    it 'marks a deprecated feature as struck through' do
      expect(page).to have_css('.menu .node.-deprecated')

      struck = page.evaluate_script(<<~JS)
        (function() {
          let node = document.querySelector('.menu .node.-deprecated .node--self')
          return node && getComputedStyle(node).textDecorationLine.includes('line-through')
        })()
      JS

      expect(struck).to be(true)
    end

    # The meta columns used to disappear below a window width, which made no
    # sense once the tree became a constant width. They are always shown now, and
    # this is the guard against them quietly going away again.
    it 'shows a feature its meta columns beside its title' do
      expect(page).to have_css('.node--tag', text: /config/i, visible: :all)

      # Whatever width the driver gives us, the rule must be the tree's width and
      # not something that hides the columns everywhere.
      state = page.evaluate_script(<<~JS)
        (function() {
          let menu = document.querySelector('.menu')
          let meta = document.querySelector('.node--self .node--meta')
          return {
            menu: Math.round(menu.getBoundingClientRect().width),
            shown: !!meta && getComputedStyle(meta).display !== 'none'
          }
        })()
      JS

      expect(state['shown']).to be(true), "menu is #{state['menu']}px wide and the meta columns are hidden"
      
    end
  end

end
