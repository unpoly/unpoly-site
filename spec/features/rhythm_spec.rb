# Spacing and the footer, measured in the real frame. Graduated from the C-tail
# batch's probes: the title gap had silently collapsed to 0px on every page.
describe 'vertical rhythm', type: :feature, js: true do

  def title_gap
    page.evaluate_script(<<~JS)
      Math.round(document.querySelector('.guide--content h1').getBoundingClientRect().top -
        document.querySelector('.guide--head').getBoundingClientRect().bottom)
    JS
  end

  %w[/learn /targeting-fragments /up.render /support].each do |path|
    it "leaves 25px between the header and the title on #{path}" do
      visit path
      expect(page).to have_css('.guide--content h1')

      expect(title_gap).to eq(25)
    end
  end

  it 'gives every landing band the same space above its first line and below its last' do
    visit '/'

    gaps = page.evaluate_script(<<~JS)
      [...document.querySelectorAll('.landing--section:not(.-hero):not(.-strip)')].map((section) => {
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

    tinted = page.evaluate_script("[...document.querySelectorAll('.landing--section:not(.-strip)')].map((s) => s.classList.contains('-tinted'))")

    expect(tinted).to eq([false, true, false, true, false, true, false])
  end

  describe 'the footer' do

    it 'ends the landing and a documentation page with the same centered line' do
      ['/', '/targeting-fragments'].each do |path|
        visit path
        footer = find('.guide--footer')

        expect(footer).to have_text('Made by Henning Koch · Imprint · Privacy policy')
        expect(footer).to have_link('Imprint', href: '/imprint')
        expect(page.evaluate_script("getComputedStyle(document.querySelector('.guide--footer')).textAlign")).to eq('center')
      end
    end

    it 'shares its top space with the last element instead of adding to it' do
      visit '/learn'

      # The last element of the hub ends in a 40px margin, as large as the footer's own:
      # collapsed, the gap is 40px; added, it would be 80px.
      gap = page.evaluate_script(<<~JS)
        Math.round(document.querySelector('.guide--footer').getBoundingClientRect().top -
          document.querySelector('.guide--content').getBoundingClientRect().bottom)
      JS

      expect(gap).to eq(40)
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
