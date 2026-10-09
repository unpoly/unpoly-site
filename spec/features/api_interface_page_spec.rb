describe 'interface page', type: :feature, js: true do

  before do
    visit '/up.fragment'
  end

  it 'is titled by the module name in monospace' do
    expect(page).to have_css('h1 code', text: 'up.fragment')
    expect(page).to have_css('h1 .subtitle', text: 'module')
    expect(page).to have_title(/\Aup\.fragment\b/)
  end

  it 'links to the guide pages that explain the module in context' do
    expect(page).to have_css('.learn-refs a[href="/advanced-rendering"]')
  end

  it 'lists all features of the module' do
    expect(page).to have_css('#features')
    expect(page).to have_css('#features + ul a[href="/up.render"]')
  end

end
