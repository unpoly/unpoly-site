describe 'interface page', type: :feature, js: true do

  before do
    visit '/up.fragment'
  end

  it 'shows the title and symbol of the module' do
    expect(page).to have_css('h1', text: 'Fragment API')
    expect(page).to have_css('h1 .subtitle', text: 'up.fragment')
  end

  it 'links to the guide pages that explain the module in context' do
    expect(page).to have_css('.learn-refs a[href="/advanced-rendering"]')
  end

  it 'lists all features of the module' do
    expect(page).to have_css('#all-features')
    expect(page).to have_css('#all-features + ul a[href="/up.render"]')
  end

end
