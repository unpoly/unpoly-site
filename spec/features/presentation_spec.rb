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

    # Without an italic cut the browser slants the upright one.
    it 'sets emphasis in a real italic cut of Roboto' do
      faces = page.evaluate_async_script(<<~JS)
        let done = arguments[0]
        document.fonts.load('italic 400 17px Roboto').then((faces) => done(faces.map((face) => [face.family, face.style, face.weight, face.status])))
      JS

      expect(faces).to include(['Roboto', 'italic', '400', 'loaded'])
    end

    # One variable file serves every upright weight; without real weights the browser
    # would fake them, so the spec turns faking off and compares the widths.
    it 'draws regular, medium and bold Roboto from one variable font' do
      faces = page.evaluate_async_script(<<~JS)
        let done = arguments[0]
        Promise.all([400, 500, 700].map((weight) => document.fonts.load(weight + ' 40px Roboto'))).then(() => {
          let faces = [...document.fonts].filter((face) => face.family.includes('Roboto') && face.style === 'normal' && !face.family.includes('Mono'))
          let widths = [400, 500, 700].map((weight) => {
            let sample = document.createElement('span')
            sample.textContent = 'Hamburgefonstiv'
            sample.style.cssText = 'font: ' + weight + ' 40px Roboto; font-synthesis: none; position: absolute; white-space: nowrap'
            document.body.append(sample)
            let width = sample.getBoundingClientRect().width
            sample.remove()
            return width
          })
          done({ faces: faces.map((face) => [face.weight, face.status]), widths })
        })
      JS

      expect(faces['faces']).to eq([['100 900', 'loaded']])
      expect(faces['widths']).to eq(faces['widths'].sort)
      expect(faces['widths'].uniq.size).to eq(3)
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

  # The read-more links of an overview, the learn-refs of a reference page and the Next
  # link at a page's end share one outlined-button look.
  BUTTON_JS = <<~'JS'.freeze
    (function(selector) {
      let style = getComputedStyle(document.querySelector(selector))
      return [style.borderTopStyle, style.borderTopColor, style.paddingLeft, style.borderTopLeftRadius, style.color, style.textDecorationLine]
    })(arguments[0])
  JS

  describe 'the edit link on the title line' do
    it 'is a quiet gray outlined button, set apart from the indigo ways on' do
      visit '/targeting-fragments'

      expect(page).to have_css('.edit-link', text: /\AEdit\s+page\z/)
      expect(page).to have_no_css('.edit-link i.fa')
      edit = page.evaluate_script(BUTTON_JS, '.edit-link')
      nxt = page.evaluate_script(BUTTON_JS, '.reading-nav--link.-next')

      expect(edit.first).to eq('solid')
      expect(edit[5]).to eq('none')
      expect(edit[4]).not_to eq(nxt[4])

      # On the title's first line, at its right end.
      line = page.evaluate_script(<<~JS)
        (function() {
          let edit = document.querySelector('.edit-link').getBoundingClientRect()
          let title = document.querySelector('.guide--content h1').getBoundingClientRect()
          let column = document.querySelector('.guide--content').getBoundingClientRect()
          return { top: edit.top - title.top, right: column.right - edit.right }
        })()
      JS
      expect(line['top']).to be_between(0, 10)
      expect(line['right'].abs).to be <= 0.5
      expect(page).to have_css('.edit-link[aria-label="Edit this page"]')

      # A source file at one revision on GitHub. The revision used to end in a newline,
      # which the browser sent as %0A.
      href = find('.edit-link')[:href]
      expect(href).to match(%r{\Ahttps://github\.com/unpoly/unpoly/blob/[0-9a-f]{40}/src/unpoly/pages/targeting-fragments\.md\?plain=1#L\d+:L\d+\z})
    end

    it 'says just "Edit" where the burger replaces the sidebar', driver: :selenium_tablet do
      visit '/targeting-fragments'

      expect(page).to have_css('.edit-link', text: /\AEdit\z/)
      expect(page).to have_css('.edit-link[aria-label="Edit this page"]')
    end

    it 'leaves the title alone on a phone', driver: :selenium_phone do
      visit '/targeting-fragments'

      expect(page).to have_css('.edit-link', visible: :hidden)
    end
  end

  describe 'a read-more link closing an overview section' do
    it 'is an outlined button like the Next link, unlike the links in the text' do
      # Embedded the way an overview's Markdown embeds it.
      visit '/loading-state'
      page.execute_script(<<~JS)
        document.querySelector('.prose').insertAdjacentHTML('beforeend',
          '<p>A sentence with <a href="/progress-bar">a link</a>.</p><p class="read-more"><a href="/progress-bar">Read more: Progress bar</a></p>')
      JS

      read_more = page.evaluate_script(BUTTON_JS, '.read-more a')

      expect(read_more).to eq(page.evaluate_script(BUTTON_JS, '.reading-nav--link.-next'))
      expect(read_more.first).to eq('solid')
      expect(page.evaluate_script(BUTTON_JS, '.prose p:not(.read-more) a').first).to eq('none')
    end
  end

  describe 'the learn-refs of a reference page' do
    it 'is an outlined button per guide, labelled with its title, without the old stripe' do
      visit '/up-follow'

      expect(page).to have_css('.learn-refs a.learn-refs--link[href="/following-links"]', text: /\ALearn:\s+Following links\z/, count: 1)
      expect(page.evaluate_script(BUTTON_JS, '.learn-refs--link').first).to eq('solid')
      expect(page.evaluate_script("getComputedStyle(document.querySelector('.learn-refs')).borderLeftStyle")).to eq('none')
      expect(page).to have_no_css('.learn-refs--label', visible: :all)
    end

    it 'sets two guides side by side' do
      visit '/up.radio'

      tops = page.evaluate_script("[...document.querySelectorAll('.learn-refs--link')].map((link) => Math.round(link.getBoundingClientRect().top))")

      expect(tops.size).to eq(2)
      expect(tops.uniq.size).to eq(1)
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
