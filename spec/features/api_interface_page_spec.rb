describe 'interface page', type: :feature, js: true do

  before do
    visit '/api/up.fragment'
  end

  it 'is titled by the namespace name in monospace' do
    expect(page).to have_css('h1', exact_text: 'up.fragment')
    expect(page).to have_css('h1 code', text: 'up.fragment')
    expect(page).to have_css('hgroup.page-title > h1 + p.subtitle', text: 'JavaScript namespace')
    expect(page).to have_title(/\Aup\.fragment\b/)
  end

  it 'names a class a JavaScript class below its name' do
    visit '/api/up.RenderJob'

    expect(page).to have_css('h1', exact_text: 'up.RenderJob')
    expect(page).to have_css('hgroup.page-title > h1 + p.subtitle', text: 'JavaScript class')
  end

  it 'shows no kind on a guide page' do
    visit '/learn/lazy-loading'

    expect(page).to have_css('.guide--content h1', exact_text: 'Lazy loading content')
    expect(page).to have_no_css('.subtitle')
    expect(page).to have_no_css('hgroup')
  end

  it 'links to the guide pages that explain the namespace in context' do
    expect(page).to have_css('.learn-refs a[href="/learn/advanced-rendering"]')
  end

  it 'lists all features of the namespace' do
    expect(page).to have_css('#features')
    expect(page).to have_css('#features + ul a[href="/api/up.render"]')
  end

end
