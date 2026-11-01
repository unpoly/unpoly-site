describe 'interface page', type: :feature, js: true do

  before do
    visit '/api/up.fragment'
  end

  it 'is titled by the module name in monospace' do
    expect(page).to have_css('h1 code', text: 'up.fragment')
    expect(page).to have_css('h1 .subtitle', text: 'JavaScript namespace')
    expect(page).to have_title(/\Aup\.fragment\b/)
  end

  it 'names a class a JavaScript class below its name' do
    visit '/api/up.RenderJob'

    expect(page).to have_css('h1 code', text: 'up.RenderJob')
    expect(page).to have_css('h1 .subtitle', text: 'JavaScript class')
  end

  it 'shows no kind on a guide page' do
    visit '/learn/lazy-loading'

    expect(page).to have_css('.guide--content h1')
    expect(page).to have_no_css('h1 .subtitle')
  end

  it 'links to the guide pages that explain the module in context' do
    expect(page).to have_css('.learn-refs a[href="/learn/advanced-rendering"]')
  end

  it 'lists all features of the module' do
    expect(page).to have_css('#features')
    expect(page).to have_css('#features + ul a[href="/api/up.render"]')
  end

end
