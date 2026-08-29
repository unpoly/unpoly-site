describe 'feature page', type: :feature, js: true do

  before do
    visit '/up.render'
  end

  it 'shows the signature, kind and visibility of the feature' do
    expect(page).to have_css('h1', text: 'up.render([target], [options])')
    expect(page).to have_css('h1 .subtitle', text: 'JavaScript function')
    expect(page).to have_css('.feature.-stable')

    # The breadcrumb is only shown on narrow screens, where there is no menu.
    expect(page).to have_css('h1 .breadcrumb[href="/up.fragment"]', text: 'up.fragment', visible: :all)
  end

  it 'documents the parameters of the feature' do
    expect(page).to have_css('.feature--param', text: 'target')
    expect(page).to have_css('.feature--param .tag', text: /optional/i)
  end

  it 'documents the return value of the feature' do
    expect(page).to have_css('#return-value')
    expect(page).to have_css('.feature--param.-response', text: 'up.RenderJob')
  end

  it 'renders the prose of the feature, linking code references to their own page' do
    expect(page).to have_css('.feature--prose')
    expect(page).to have_css('.feature--prose a[href="/up.navigate"] code', text: 'up.navigate()')
  end

end
