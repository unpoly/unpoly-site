# The search's ranking against the REAL index of the last build: the dialog loads the
# Pagefind index the preview serves from build/pagefind, unstubbed, and ranks it as a
# reader would see it. The ranking itself is explained at the top of
# source/javascripts/components/search_dialog.js.
#
# The corpus changes with every edit to the documentation, so these examples assert
# outcomes a reader relies on (who is in the list, who comes before whom), never exact
# ranks or scores.
#
# Runs only where a build exists (`bundle exec rake search:index`); skipped otherwise,
# as in CI.
describe 'the search ranking', type: :feature, js: true do

  before do
    skip 'no build/pagefind (run `bundle exec rake search:index`)' unless File.directory?(File.expand_path('../../build/pagefind', __dir__))
    visit '/loading-state'
  end

  # The pages the dialog lists for a query, in order.
  def ranked(query)
    find('.search-pill', visible: :all).click unless page.has_css?('up-modal.search-dialog', wait: 0)
    # The previous list stays until the new one is complete, so it is cleared first.
    find('.search-dialog--input').set('')
    expect(page).to have_no_css('.search-dialog--hit')
    find('.search-dialog--input').set(query)
    expect(page).to have_css('.search-dialog--hit')
    page.evaluate_script("[...document.querySelectorAll('.search-dialog--hit:not(.-section)')].map((hit) => hit.getAttribute('href'))")
  end

  # The first pages Pagefind itself returns, before the dialog multiplies any score. Shares
  # the dialog's Pagefind instance, so `ranking` changes what the dialog would see, too.
  def pagefind_alone(query, ranking: nil, limit: 30)
    page.evaluate_async_script(<<~JS, query, ranking, limit)
      let [query, ranking, limit, done] = arguments
      import('/pagefind/pagefind.js').then(async (pagefind) => {
        if (ranking) await pagefind.options({ ranking })
        let search = await pagefind.search(query)
        let pages = await Promise.all(search.results.slice(0, limit).map((result) => result.data()))
        done(pages.map((page) => page.url.replace(/\\/$/, '')))
      })
    JS
  end

  it 'recalls the layer features for "layer"' do
    expect(ranked('layer')).to include('/up-layer-new', '/up.layer.current', '/up.layer.on', '/up.layer.ask')
  end

  it 'keeps the page that discusses a term the most at the top' do
    expect(ranked('csp').first).to eq('/script-security')
    expect(ranked('offline').first).to eq('/network-issues')
    expect(ranked('autosubmit').first).to eq('/up-autosubmit')
  end

  it 'lifts a signature page by its title and its boost' do
    results = ranked('layer')

    # The boost: [up-layer=new] passes a page that Pagefind scores higher.
    expect(pagefind_alone('layer').index('/layer-option')).to be < pagefind_alone('layer').index('/up-layer-new')
    expect(results.index('/up-layer-new')).to be < results.index('/layer-option')

    # The title: without its tier title, [up-layer=new] is not even among the pages the
    # dialog fetches.
    expect(pagefind_alone('layer', ranking: { metaWeights: { title: 2, tier_title: 0 } })).not_to include('/up-layer-new')
  end

  it 'breaks a near-tie by kind' do
    # Both are signature pages, and Pagefind puts the event a hair ahead.
    expect(pagefind_alone('defer').first(2)).to contain_exactly('/up-defer', '/up:deferred:load')

    results = ranked('defer')

    expect(results.index('/up-defer')).to be < results.index('/up:deferred:load')
  end

end
