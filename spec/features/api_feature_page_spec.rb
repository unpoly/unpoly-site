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

describe 'a feature page title', type: :feature, js: true do

  # The text of the title, with its line break opportunities as "|".
  TITLE_JS = <<~JS.freeze
    (function() {
      let h1 = document.querySelector('.guide--content h1').cloneNode(true)
      h1.querySelectorAll('.breadcrumb, .subtitle').forEach((e) => e.remove())
      h1.querySelectorAll('wbr').forEach((e) => e.replaceWith('|'))
      return h1.textContent.trim()
    })()
  JS

  it 'may break a long signature where Prettier would: after "(", before ".", after ", "' do
    visit '/up.RenderJob.prototype.then'

    expect(page.evaluate_script(TITLE_JS)).to eq('up|.RenderJob|.prototype|.then(|onFulfilled, |onRejected)')
  end

  it 'leaves the signature in the search index unbroken' do
    visit '/up.render'

    expect(page).to have_css('[data-pagefind-meta="tier_title:up.render([target], [options])"]', visible: :all)
  end

  it 'is set at the size of the type scale on a desktop' do
    visit '/up.render'

    expect(page.evaluate_script("getComputedStyle(document.querySelector('.guide--content h1')).fontSize")).to eq('38px')
  end

  describe 'on a phone', driver: :selenium_phone do
    it 'is set smaller, but still larger than a section heading' do
      visit '/up.render'

      sizes = page.evaluate_script("['h1', 'h2'].map((tag) => getComputedStyle(document.querySelector('.guide--content ' + tag)).fontSize)")

      expect(sizes).to eq(['26px', '24px'])
    end
  end

end
