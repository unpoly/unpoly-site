describe 'interface page', type: :feature, js: true do

  before do
    visit '/up.fragment'
  end

  it 'shows the title and symbol of the module' do
    expect(page).to have_css('h1', text: 'Fragment API')
    expect(page).to have_css('h1 .subtitle', text: 'up.fragment')
  end

  it 'links to the guide pages of the module' do
    expect(page).to have_css('.topics a[href="/navigation"]')
  end

  it 'promotes essential features before listing all features' do
    expect(page).to have_css('#essential-features')
    expect(page).to have_css('.essential_features a[href="/up.render"]', text: 'up.render')
    expect(page).to have_css('#features')
  end

end
