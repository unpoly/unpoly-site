describe 'search', type: :feature do

  it 'filters the tree', js: true do
    visit '/'

    expect(page).to have_css('.search')
    expect(page).to have_css('.menu', text: 'Layers')
    expect(page).to have_css('.menu', text: 'Form')

    fill_in('search', with: 'Layers')

    expect(page).to have_css('.menu', text: 'Layers')
    expect(page).to_not have_css('.menu', text: 'Form')
  end

  it 'allows to expand the search to a full-text search', js: true do
    visit '/'

    fill_in('search', with: 'navigation')
    page.send_keys(:return)

    expect(page).to have_content('navigational container')
  end

end
