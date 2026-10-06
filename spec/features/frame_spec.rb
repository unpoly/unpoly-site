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
          let rail = document.querySelector('.guide--right')
          let railed = rail && rail.getClientRects().length > 0
          let rightEdge = railed ? rail.getBoundingClientRect().left : window.innerWidth
          return [Math.round(content.left - sidebar.right), Math.round(rightEdge - content.right)]
        })()
      JS

      expect((gaps[0] - gaps[1]).abs).to be <= 20
    end
  end

  describe 'the in-page table of contents' do
    # On wide screens a copy stands in the right rail and CSS hides the one in the
    # text. The one in the text must stay above the first section heading, so that the
    # reading order holds without CSS.
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
          let toc = document.querySelector('.guide--right .toc').getBoundingClientRect()
          return Math.round(toc.left - content.right)
        })()
      JS

      expect(gap).to be >= 20
    end

    it 'sets the copy in the rail a step larger than the one in the text' do
      visit '/loading-state'

      sizes = page.evaluate_script(<<~JS)
        ['.guide--right .toc', '.guide--content .toc'].map((toc) =>
          ['.toc--title', '.toc--item'].map((part) => getComputedStyle(document.querySelector(toc + ' ' + part)).fontSize))
      JS

      expect(page).to have_css('.guide--right .toc.-rail')
      expect(page).to have_no_css('.guide--content .toc.-rail', visible: :all)
      expect(sizes).to eq([['14px', '17px'], ['12px', '15px']])
    end

    describe 'in the rail' do
      def current_sections
        page.evaluate_script("[...document.querySelectorAll('.toc .toc--item.-current')].map((item) => item.textContent.trim())")
      end

      def scroll_to_heading(id)
        page.execute_script("document.getElementById(arguments[0]).scrollIntoView(); window.scrollBy(0, -60)", id)
      end

      it 'marks the section the reader is in, and only that one' do
        visit '/up.render'
        expect(page).to have_css('.toc.-rail .toc--item.-current', text: 'Choosing which fragment to update')

        scroll_to_heading('concurrency')
        expect(page).to have_css('.toc.-rail .toc--item.-current', text: 'Concurrency')

        page.execute_script('window.scrollTo(0, document.scrollingElement.scrollHeight)')
        expect(page).to have_css('.toc.-rail .toc--item.-current', text: 'Return value')
        expect(current_sections).to eq(['Return value'])
        expect(page).to have_css('.toc.-rail .toc--item.-current a[aria-current=location]')
      end

      # A marked item may wrap onto one more line in bold; no other item changes.
      it 'marks it in bold, and changes no other item' do
        visit '/up.render'
        expect(page).to have_css('.toc.-rail .toc--item.-current', text: 'Choosing which fragment to update')
        boxes = "[...document.querySelectorAll('.toc.-rail .toc--item')].map((item) => item.getBoundingClientRect().height)"
        weights = "[...document.querySelectorAll('.toc.-rail .toc--item a')].map((link) => getComputedStyle(link).fontWeight)"
        before = page.evaluate_script(boxes)

        expect(page.evaluate_script(weights).first).to eq('700')
        expect(page.evaluate_script(weights).drop(1).uniq).to eq(['400'])
        expect(page.evaluate_script("getComputedStyle(document.querySelector('.toc.-rail .toc--item.-current a')).backgroundColor")).to eq('rgba(0, 0, 0, 0)')

        scroll_to_heading('concurrency')
        expect(page).to have_css('.toc.-rail .toc--item.-current', text: 'Concurrency')

        after = page.evaluate_script(boxes)
        marked = ['Choosing which fragment to update', 'Concurrency'].map do |text|
          page.evaluate_script("[...document.querySelectorAll('.toc.-rail .toc--item')].findIndex((item) => item.textContent.trim() === arguments[0])", text)
        end
        others = (0...before.size).to_a - marked
        expect(others.map { |i| after[i] }).to eq(others.map { |i| before[i] })
      end

      it 'marks the section a link has revealed' do
        visit '/up.render'

        find('.toc.-rail a[href="#passing-the-new-fragment"]').click

        expect(page).to have_css('.toc.-rail .toc--item.-current', text: 'Passing the new fragment')
        expect(current_sections).to eq(['Passing the new fragment'])
      end

      it 'marks the section a deep link opens' do
        visit '/up.render#enabling-side-effects'

        expect(page).to have_css('.toc.-rail .toc--item.-current', text: 'Enabling side effects')
      end

      it 'follows the reader onto the next page' do
        visit '/loading-state'
        expect(page).to have_css('.guide--menu .menu--nodes')
        page.execute_script("up.navigate({ url: '/targeting-fragments' })")
        expect(page).to have_css('.toc.-rail .toc--item.-current', text: 'Swapping a fragment')

        scroll_to_heading('targeting-nothing')
        expect(page).to have_css('.toc.-rail .toc--item.-current', text: 'Targeting nothing')
        expect(current_sections).to eq(['Targeting nothing'])
      end
    end

    it 'shows only one copy at a time' do
      visit '/loading-state'

      expect(page).to have_css('.guide--right .toc', visible: true)
      expect(page).to have_css('.guide--content .toc', visible: :hidden)
    end
  end

  describe 'the burger menu' do
    it 'opens a drawer that carries the navigation but no search' do
      # The burger is the narrow-screen affordance, so it is hidden here; we
      # follow what it points at. drawer_spec covers the drawer itself.
      visit '/menu/narrow'

      expect(page).to have_css('.menu--nodes')
      expect(page).to have_no_css('.guide--content .search-pill, .guide--content input')
    end
  end

end
