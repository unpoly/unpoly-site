# The way up from a page (Unpoly::Site::Trail), above its title. Search engines read
# its microdata, so it sits outside the <h1>, which holds the title alone.
describe 'breadcrumb', type: :feature do

  # The trail as [label, href, position], read from the microdata.
  def breadcrumb_steps
    list = page.find('nav.breadcrumb[aria-label="Breadcrumb"] > ol[itemscope][itemtype="https://schema.org/BreadcrumbList"]', visible: :all)
    list.all('li[itemprop="itemListElement"][itemscope][itemtype="https://schema.org/ListItem"]', visible: :all).map do |step|
      link = step.find('a[itemprop="item"]', visible: :all)
      [link.find('[itemprop="name"]', visible: :all).text(:all), link[:href], step.find('meta[itemprop="position"]', visible: :all)[:content]]
    end
  end

  it "leads from a feature to its module" do
    visit '/api/up-submit'
    expect(breadcrumb_steps).to eq([['API', '/api', '1'], ['up.form', '/api/up.form', '2']])
  end

  it 'leads from a module to the API' do
    visit '/api/up.form'
    expect(breadcrumb_steps).to eq([['API', '/api', '1']])
  end

  it 'leads from a Learn page to its chapter' do
    visit '/learn/feedback-classes'
    expect(breadcrumb_steps).to eq([['Learn', '/learn', '1'], ['Loading state', '/learn/loading-state', '2']])
  end

  it 'leads from a Getting started page to its chapter' do
    visit '/learn/start/links'
    expect(breadcrumb_steps).to eq([['Learn', '/learn', '1'], ['Getting started', '/learn/start/overview', '2']])
  end

  it 'leads from a release to the changes' do
    visit '/changes/3.0.0'
    expect(breadcrumb_steps).to eq([['Changes', '/changes', '1']])
  end

  it 'sits outside the <h1>, before the title, and stays out of the search index and the Markdown twin' do
    visit '/api/up-submit'

    expect(page).to have_no_css('h1 .breadcrumb, h1 nav', visible: :all)
    expect(page).to have_css('nav.breadcrumb + hgroup.page-title > h1', visible: :all)
    nav = page.find('nav.breadcrumb', visible: :all)
    expect(nav['data-pagefind-ignore']).not_to be_nil
    expect(nav['data-markdown']).to eq('ignore')
    expect(nav).to have_css('a[up-restore-scroll]', count: 2, visible: :all)
  end

  it 'is missing on the hubs and the landing page' do
    %w[/learn /api /changes /support /].each do |path|
      visit path
      expect(page).to have_no_css('.breadcrumb', visible: :all), "breadcrumb on #{path}"
    end
  end

  describe 'on screen', js: true do
    it 'shows on a phone, with a slash after each step that a screen reader skips', driver: :selenium_phone do
      visit '/api/up-submit'

      expect(page).to have_css('nav.breadcrumb', text: /API\s+up\.form/)
      separator = page.evaluate_script("getComputedStyle(document.querySelector('.breadcrumb--step'), '::after').content")
      expect(separator).to eq('" /" / ""')
    end

    it 'is hidden on a desktop, where the sidebar shows the way' do
      visit '/api/up-submit'

      expect(page).to have_css('nav.breadcrumb', visible: :hidden)
    end
  end

end
