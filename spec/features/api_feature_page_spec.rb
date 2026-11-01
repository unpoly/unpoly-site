describe 'feature page', type: :feature, js: true do

  before do
    visit '/api/up.render'
  end

  it 'shows the signature, kind and visibility of the feature' do
    expect(page).to have_css('h1', exact_text: 'up.render([target], [options])')
    expect(page).to have_css('hgroup.page-title > h1 + p.subtitle', text: 'JavaScript function')
    expect(page).to have_css('.feature.-stable')
  end

  # Search engines take a page's title from its <h1>, so it holds nothing else.
  it 'has nothing but the title in its <h1>, with the kind in a subtitle beside it' do
    visit '/api/up-submit'

    expect(page).to have_css('.guide--content h1', exact_text: '[up-submit]')
    subtitle = page.find('hgroup.page-title > p.subtitle', text: 'HTML attribute')
    expect(subtitle).to have_css('svg.subtitle--icon', visible: :all)
    expect(subtitle['data-pagefind-ignore']).not_to be_nil
    expect(subtitle['data-markdown']).to eq('ignore')
  end

  it 'lists the parameter groups as chips in a list' do
    visit '/api/up-submit'

    chips = all('.minitoc ul.minitoc--items > li > a.minitoc--link')
    expect(chips.size).to be > 1
    expect(chips.first.text).to match(/\Atargeting\z/i)
  end

  # The groups are <h3>s below the parameters' <h2>, which the contents list already
  # names. The chips above lead to them.
  it 'leaves the parameter groups out of the contents' do
    visit '/api/up-submit'

    group_ids = all('h3.pearl-title', visible: :all).map { |heading| heading[:id] }
    toc_hrefs = all('.toc.-rail .toc--item a', visible: :all).map { |link| link[:href].split('#').last }
    expect(group_ids.size).to be > 1
    expect(toc_hrefs).to include('attributes')
    expect(toc_hrefs & group_ids).to be_empty
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
    expect(page).to have_css('.feature--prose a[href="/api/up.navigate"] code', text: 'up.navigate()')
  end

end

describe 'a feature page title', type: :feature, js: true do

  # The text of the title, with its line break opportunities as "|".
  TITLE_JS = <<~JS.freeze
    (function() {
      let h1 = document.querySelector('.guide--content h1').cloneNode(true)
      h1.querySelectorAll('wbr').forEach((e) => e.replaceWith('|'))
      return h1.textContent.trim()
    })()
  JS

  it 'may break a long signature where Prettier would: after "(", before ".", after ", ", but never after a leading "up"' do
    visit '/api/up.RenderJob.prototype.then'

    expect(page.evaluate_script(TITLE_JS)).to eq('up.RenderJob|.prototype|.then(|onFulfilled, |onRejected)')
  end

  it 'leaves the signature in the search index unbroken' do
    visit '/api/up.render'

    expect(page).to have_css('[data-pagefind-meta="tier_title:up.render([target], [options])"]', visible: :all)
  end

  it 'is set at the size of the type scale on a desktop' do
    visit '/api/up.render'

    expect(page.evaluate_script("getComputedStyle(document.querySelector('.guide--content h1')).fontSize")).to eq('38px')
  end

  describe 'on a phone', driver: :selenium_phone do
    it 'is set smaller, but still larger than a section heading' do
      visit '/api/up.render'

      sizes = page.evaluate_script("['h1', 'h2'].map((tag) => getComputedStyle(document.querySelector('.guide--content ' + tag)).fontSize)")

      expect(sizes).to eq(['26px', '24px'])
    end
  end

end

describe 'the HTML of a feature page' do

  # <wbr> is a void element. libxml2's HTML4 parser doesn't know that and wrapped what
  # followed it, so the page carried stray </wbr> end tags.
  it 'writes no end tag for a <wbr>' do
    body = Rack::MockRequest.new(Capybara.app).get('/api/up-submit', 'HTTP_HOST' => 'unpoly.test').body

    expect(body).to include('<wbr>')
    expect(body).not_to include('</wbr>')
  end

end
