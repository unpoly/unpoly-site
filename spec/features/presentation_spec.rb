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
  end

  describe 'a hub page' do
    it 'lists every topic with the pages under it' do
      visit '/learn'

      expect(page).to have_css('.topic-preview', minimum: 5)
      expect(page).to have_css('.topic-preview--children a', minimum: 20)
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
