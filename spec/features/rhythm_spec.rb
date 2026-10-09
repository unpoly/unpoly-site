# Spacing and the footer, measured in the real frame. Graduated from the C-tail
# batch's probes: the title gap had silently collapsed to 0px on every page.
describe 'vertical rhythm', type: :feature, js: true do

  def title_gap
    page.evaluate_script(<<~JS)
      Math.round(document.querySelector('.guide--content h1').getBoundingClientRect().top -
        document.querySelector('.guide--head').getBoundingClientRect().bottom)
    JS
  end

  # The title sits farther from the header than from the text below it, so it belongs
  # to the text it heads.
  %w[/learn /targeting-fragments /up.render /support].each do |path|
    it "leaves 40px between the header and the title on #{path}, more than below the title" do
      visit path
      expect(page).to have_css('.guide--content h1')

      expect(title_gap).to eq(40)
      below = page.evaluate_script(<<~JS)
        (function(title) { return Math.round(title.nextElementSibling.getBoundingClientRect().top - title.getBoundingClientRect().bottom) })(document.querySelector('.guide--content h1'))
      JS
      expect(below).to eq(25)
    end
  end

  it 'starts the sidebar, the title and the rail on one line' do
    visit '/targeting-fragments'
    expect(page).to have_css('.guide--menu .menu--nodes')

    tops = page.evaluate_script(<<~JS)
      ['.guide--menu .menu--nodes > .node > .node--self', '.guide--content h1', '.guide--right .toc'].map((s) => Math.round(document.querySelector(s).getBoundingClientRect().top))
    JS

    expect(tops.uniq.size).to eq(1), "tops differ: #{tops}"
  end

  it 'gives every landing band, the hero included, the same space above its first line and below its last' do
    visit '/'

    gaps = page.evaluate_script(<<~JS)
      [...document.querySelectorAll('.landing--section')].map((section) => {
        let box = section.getBoundingClientRect()
        let children = [...section.querySelectorAll('.landing--inner > *')].filter((child) => child.getClientRects().length)
        return [Math.round(children[0].getBoundingClientRect().top - box.top),
                Math.round(box.bottom - children[children.length - 1].getBoundingClientRect().bottom)]
      })
    JS

    gaps.each { |top, bottom| expect(top).to be_within(1).of(bottom) }
  end

  it 'alternates the landing bands, starting with a tinted second band' do
    visit '/'

    tinted = page.evaluate_script("[...document.querySelectorAll('.landing--section')].map((s) => s.classList.contains('-tinted'))")

    expect(tinted.first(2)).to eq([false, true])
    tinted.each_cons(2) { |above, below| expect(above).not_to eq(below) }
  end

  describe 'the footer' do

    it 'ends the landing and a documentation page with the same centered line' do
      ['/', '/targeting-fragments'].each do |path|
        visit path
        footer = find('.guide--footer')

        expect(footer).to have_text('Made by Henning Koch · Imprint · Privacy policy')
        expect(footer).to have_link('Henning Koch', href: 'https://triskweline.de/')
        expect(footer).to have_link('Imprint', href: '/imprint')
        expect(page.evaluate_script("getComputedStyle(document.querySelector('.guide--footer')).textAlign")).to eq('center')
      end
    end

    it 'shares its top space with the last element instead of adding to it' do
      visit '/learn'

      # The last element of the hub ends in a 40px margin, as large as the footer's own:
      # collapsed, the gap is 40px; added, it would be 80px. Measured from that element,
      # not from .guide--content, whose box absorbs the margin when collapsing breaks
      # (a flex or grid parent, a new formatting context).
      gap = page.evaluate_script(<<~JS)
        Math.round(document.querySelector('.guide--footer').getBoundingClientRect().top -
          document.querySelector('.guide--content').lastElementChild.getBoundingClientRect().bottom)
      JS

      expect(gap).to eq(40)
    end

    it 'leaves 32px below its line, half the space it once had' do
      visit '/targeting-fragments'

      expect(page.evaluate_script("getComputedStyle(document.querySelector('.guide--footer')).paddingBottom")).to eq('32px')
    end

  end

  describe 'the request-flow diagram on a phone', driver: :selenium_phone do

    it 'runs edge to edge and scrolls sideways at its 620px floor' do
      visit '/'

      facts = page.evaluate_script(<<~JS)
        (function() {
          let figure = document.querySelector('.diagram').getBoundingClientRect()
          let scroller = document.querySelector('.diagram--scroller')
          return { left: figure.left, right: Math.round(figure.right), width: innerWidth,
                   canvas: Math.round(document.querySelector('.diagram--canvas').getBoundingClientRect().width),
                   scrolls: scroller.scrollWidth > scroller.clientWidth,
                   pageScrolls: document.documentElement.scrollWidth > innerWidth }
        })()
      JS

      expect(facts).to include('left' => 0, 'right' => facts['width'], 'canvas' => 620, 'scrolls' => true, 'pageScrolls' => false)
    end

  end

end
