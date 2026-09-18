describe 'search', type: :feature do

  # The landing page runs without the sidebar, so the search that filters the
  # menu tree is exercised on a documentation page. Chapter names like "Overlays"
  # live in the Learn menu, so the tree filter is driven from a Learn page.
  it 'filters the tree', js: true do
    visit '/loading-state'

    expect(page).to have_css('.search')
    expect(page).to have_css('.menu', text: 'Overlays')
    expect(page).to have_css('.menu', text: 'Forms')

    fill_in('search', with: 'Overlays')

    expect(page).to have_css('.menu', text: 'Overlays')
    expect(page).to_not have_css('.menu', text: 'Forms')
  end

  it 'allows to expand the search to a full-text search', js: true do
    visit '/loading-state'

    fill_in('search', with: 'navigation')
    page.send_keys(:return)

    expect(page).to have_content('navigational container')
  end

  it 'focuses the sidebar field when the header pill is clicked', js: true do
    visit '/loading-state'

    # The menu, and with it the search field, is loaded after the page.
    expect(page).to have_css('.search--input')

    find('.search-pill').click

    expect(page).to have_css('.search--input:focus')
  end

  it 'falls back to a link where the page has no search field', js: true do
    visit '/'

    expect(page).to have_css('.search-pill', visible: :all)
    find('.search-pill', visible: :all).click

    expect(page).to have_current_path('/api')
  end

end
