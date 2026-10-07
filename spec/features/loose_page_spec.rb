# A loose Learn page (`loose:` in toc.yml) belongs to the Learn area but to no chapter.
# Loaded directly, it renders the docs frame with the Learn menu and nothing selected in
# it, and no reading path. Other pages open it in an overlay, which shows the page's
# content and none of its frame.
describe 'a loose Learn page', type: :feature, js: true do

  before { make_page_loose }

  let(:path) { "/#{LoosePage::SLUG}" }

  it 'renders in the docs frame with the Learn menu and no current node' do
    visit path

    expect(page).to have_css('.guide--menu .menu--nodes .node--self', text: 'Getting started')
    expect(page).to have_no_css('.guide--menu .node--self.up-current')
    expect(page).to have_css('.guide--head .top-nav--section.up-current', text: 'Learn')
  end

  it 'renders no reading path' do
    visit path

    expect(page).to have_css('.guide--content h1')
    expect(page).to have_no_css('.reading-nav')
  end

  it 'is indexed for search as a Learn page' do
    visit path

    expect(page).to have_css('.guide--content[data-pagefind-filter="area:Learn"][data-pagefind-meta="badge:Learn"]')
  end

  it 'is not listed on the Learn hub' do
    visit '/learn'

    expect(page).to have_css('.learn-chapter')
    expect(page).to have_no_css(".guide--content a[href='#{path}']")
  end

  it 'opens the drawer on the Learn section, with no chapter current', driver: :selenium_phone do
    visit path
    find('.guide--head a[href="/menu/narrow"]').click
    wait_for_drawer_to_settle

    expect(page).to have_css('up-drawer .menu--nodes > .node > .node--self.up-current', text: 'Learn')
    expect(page).to have_css('up-drawer .node .node--self', text: 'Links')
    expect(page).to have_no_css('up-drawer .menu--nodes > .node > .node .node--self.up-current')
  end

  it 'opens in an overlay with its content and none of the frame' do
    visit '/install'
    page.execute_script("up.layer.open({ url: #{path.to_json} })")

    within('up-modal') do
      expect(page).to have_css('.guide--content h1')
      expect(page).to have_no_css('.guide--menu, .guide--flank, .guide--footer, .guide--head, .reading-nav')
    end

    page.find('up-modal-dismiss').click
    expect(page).to have_no_css('up-modal')
    expect(page).to have_current_path('/install')
  end

end
