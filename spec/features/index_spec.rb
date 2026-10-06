describe 'index', type: :feature, js: true do
  before do
    visit '/'
  end

  it 'shows our claim' do
    expect(page).to have_css('h1', text: 'The missing application layer for HTML')
  end

  it 'marks the Unpoly attributes in the hero code' do
    within '.landing--code.-hero' do
      expect(page).to have_css('mark', text: 'up-target')
      expect(page).to have_css('mark', text: 'up-poll')
    end
  end

  it 'leads into both areas of the documentation' do
    expect(page).to have_link('Learn Unpoly', href: '/learn')
    expect(page).to have_link('API Reference', href: '/api')
  end

  it 'draws the request-flow diagram with readable text' do
    within '.diagram' do
      expect(page).to have_css('text', text: 'FRAGMENTS')
      expect(page).to have_css('text', text: 'PATCH')
    end
  end

  it 'names the companies running Unpoly in production' do
    expect(page).to have_css('.landing--logos-label', text: /in production at/i)
    expect(page).to have_css('.landing--logo', count: 10)
  end

  it 'closes the "Is Unpoly right for you?" band with the logo wall, rather than giving it a band of its own' do
    band = find('.landing--section', text: 'Is Unpoly right for you?')

    expect(band).to have_css('.landing--inner > .landing--logos:last-child .landing--logo', count: 10)
  end

  it 'fits every code example into its box at 1280px, without scrolling' do
    widths = page.evaluate_script("[...document.querySelectorAll('pre.landing--code')].map((pre) => [pre.scrollWidth, pre.clientWidth])")

    widths.each { |scroll, client| expect(scroll).to be <= client }
  end

  # The landing's text styles every <a> as a link; its buttons must not catch that.
  it 'draws its buttons without a link underline, in white on their own color' do
    buttons = page.evaluate_script(<<~JS)
      [...document.querySelectorAll('.landing a.action')].map((button) => {
        let style = getComputedStyle(button)
        return [button.textContent.trim(), style.textDecorationLine, style.color]
      })
    JS

    expect(buttons.map(&:first)).to include('Learn Unpoly', 'API Reference')
    buttons.each do |label, line, color|
      expect([label, line, color]).to eq([label, 'none', 'rgb(255, 255, 255)'])
    end
  end

  it 'runs without the documentation sidebar' do
    expect(page).to have_css('.landing')
    expect(page).to have_no_css('.guide--left')
  end
end
