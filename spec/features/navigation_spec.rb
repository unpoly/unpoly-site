describe 'navigation', type: :feature, js: true do

  # Marks the current document, so we can tell a fragment update from a full page load.
  def mark_document
    page.execute_script('window.documentMark = "marked"')
  end

  def document_marked?
    page.evaluate_script('window.documentMark') == 'marked'
  end

  it 'follows a link from the menu without a full page load' do
    visit '/up.fragment'
    # The menu is loaded lazily, replacing a placeholder.
    expect(page).to have_css('.menu--nodes')
    mark_document

    within '.menu--nodes' do
      click_link 'up.render()'
    end

    expect(page).to have_css('h1', text: 'up.render([target], [options])')
    expect(page).to have_current_path('/up.render')
    expect(document_marked?).to be(true)
  end

  it 'follows a code reference from the prose to the page of that feature' do
    visit '/up.render'

    within '.feature--prose' do
      first('a[href="/up.navigate"]').click
    end

    expect(page).to have_css('h1', text: 'up.navigate')
    expect(page).to have_current_path('/up.navigate')
  end

  it 'highlights the current page in the menu' do
    visit '/up.render'

    expect(page).to have_css('.menu .up-current', text: 'up.render()')
  end

  it 'expands the current module one level, as an accordion' do
    visit '/up.fragment'

    within '.menu' do
      # The current node expands one level: its feature groups are visible ...
      expect(page).to have_css('.node.-expanded', text: 'up.fragment')
      expect(page).to have_link('up.render()')

      # ... but everything outside its ancestry stays collapsed.
      expect(page).to have_css('.node:not(.-expanded)', text: 'up.form', visible: :all)
      expect(page).to_not have_link('up.submit()')
    end
  end

end
