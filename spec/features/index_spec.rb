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

  it 'runs without the documentation sidebar' do
    expect(page).to have_css('.landing')
    expect(page).to have_no_css('.guide--left')
  end
end
