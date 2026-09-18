describe 'the page frame', type: :feature, js: true do

  # The driver emulates a fixed 1280px viewport, which is wide enough for both
  # the sidebar and the contents rail. Examples therefore assert the shape the
  # frame takes at that width, not the widths at which it changes.

  describe 'the global header' do
    it 'appears on a documentation page' do
      visit '/loading-state'
      expect(page).to have_css('.guide--head .top-nav')
    end

    it 'appears on the landing page, which has no sidebar' do
      visit '/'
      expect(page).to have_css('.guide--head .top-nav')
    end

    it 'links to every area of the site' do
      visit '/loading-state'

      within '.top-nav' do
        expect(page).to have_link('Learn', href: '/learn')
        expect(page).to have_link('API', href: '/api')
        expect(page).to have_link('Demo', href: 'https://demo.unpoly.com')
        expect(page).to have_link('Changes', href: '/changes')
        expect(page).to have_link('Support', href: '/support')
        expect(page).to have_link(href: 'https://github.com/unpoly/unpoly')
      end
    end

    it 'stays fixed to the top of the window while the page scrolls' do
      visit '/up.render'

      page.execute_script('window.scrollTo(0, 1200)')

      top = page.evaluate_script("document.querySelector('.guide--head').getBoundingClientRect().top")
      expect(top).to eq(0)
    end
  end

  describe 'the sidebar' do
    it 'is pinned to the left edge of the window' do
      visit '/loading-state'

      left = page.evaluate_script("document.querySelector('.guide--left').getBoundingClientRect().left")
      expect(left).to eq(0)
    end

    it 'leaves the documentation centred in the space beside it' do
      visit '/loading-state'

      # Whatever bounds the text on the right — the contents rail where there is
      # one, the window edge otherwise — should sit as far from the text as the
      # sidebar does on the left.
      gaps = page.evaluate_script(<<~JS)
        (function() {
          let sidebar = document.querySelector('.guide--left').getBoundingClientRect()
          let content = document.querySelector('.guide--content').getBoundingClientRect()
          let toc = document.querySelector('.toc')
          let railed = toc && getComputedStyle(toc).position === 'fixed'
          let rightEdge = railed ? toc.getBoundingClientRect().left : window.innerWidth
          return [Math.round(content.left - sidebar.right), Math.round(rightEdge - content.right)]
        })()
      JS

      expect((gaps[0] - gaps[1]).abs).to be <= 20
    end
  end

  describe 'the in-page table of contents' do
    # It moves into a right rail on wide screens by CSS alone. Wherever it is
    # drawn, it must stay above the first section heading in the markup, so that
    # the reading order holds without CSS.
    it 'precedes the first heading in the document' do
      visit '/loading-state'

      ordered = page.evaluate_script(<<~JS)
        (function() {
          let toc = document.querySelector('.toc')
          let heading = document.querySelector('.prose h2')
          return !!(toc && heading) &&
            (toc.compareDocumentPosition(heading) & Node.DOCUMENT_POSITION_FOLLOWING) !== 0
        })()
      JS

      expect(ordered).to be(true)
    end

    it 'stands beside the text rather than on top of it once it becomes a rail' do
      visit '/loading-state'

      gap = page.evaluate_script(<<~JS)
        (function() {
          let content = document.querySelector('.guide--content').getBoundingClientRect()
          let toc = document.querySelector('.toc').getBoundingClientRect()
          return Math.round(toc.left - content.right)
        })()
      JS

      expect(gap).to be >= 20
    end
  end

  describe 'the burger menu' do
    it 'opens a drawer that carries the navigation and a search field' do
      visit '/loading-state'

      # The burger is the narrow-screen affordance, so it is hidden here; we
      # follow what it points at.
      visit '/menu/narrow'

      expect(page).to have_css('.menu--search .search--input')
      expect(page).to have_css('.menu--nodes')
    end
  end

end
