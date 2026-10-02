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

  describe 'focus after following a link' do

    def focused
      page.evaluate_script(<<~JS)
        (function() {
          let element = document.activeElement
          return {
            column: element.matches('.guide--main'),
            inContent: !!element.closest('.guide--content'),
            inSidebar: !!element.closest('.guide--left'),
          }
        })()
      JS
    end

    def expect_focus_on_column_then_content
      expect(page).to have_css('.guide--main:focus')
      expect(focused['column']).to be(true)

      page.send_keys(:tab)

      # The next Tab reaches the page's content, not the sidebar menu before it.
      expect(focused).to include('inContent' => true, 'inSidebar' => false)
    end

    it 'focuses the text column when a sidebar link is followed' do
      visit '/up.render'
      within('.guide--menu') { click_link 'up.navigate()' }
      expect(page).to have_css('h1', text: 'up.navigate')

      expect_focus_on_column_then_content
    end

    it 'focuses the text column when the landing leads into the documentation' do
      visit '/'
      within('.guide--head') { click_link 'Learn' }
      expect(page).to have_current_path('/learn')

      expect_focus_on_column_then_content
    end

  end

end
