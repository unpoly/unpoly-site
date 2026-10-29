require 'rack/mock'

describe 'changes', type: :feature, js: true do

  let(:version) { Unpoly::Site.current.stable_version }

  it 'shows the changelog of a release' do
    visit "/changes/#{version}"

    expect(page).to have_css('h1', text: "Version #{version}")
    expect(page).to have_css('.prose')
  end

  it 'links from the changes index to the release of the current version' do
    visit '/changes'

    expect(page).to have_css("a[href='/changes/#{version}']")
  end

  # By version, not by date: a late patch of an old major (1.0.3) would otherwise sit
  # between two 2.x releases and look like a sorting bug.
  it 'lists the releases newest version first, in the index and in its menu' do
    visit '/changes'

    expected = Unpoly::Site.current.releases_by_version.reverse.map { |release| "/changes/#{release.version}" }
    index = page.all('.prose a[href^="/changes/"]', visible: :all).map { |link| link[:href].delete_prefix(page.server_url) }.grep(%r{\A/changes/\d})
    menu = page.all('.menu a[href^="/changes/"]', visible: :all).map { |link| link[:href].delete_prefix(page.server_url) }.grep(%r{\A/changes/\d})
    expect(index.uniq).to eq(expected)
    expect(menu.uniq).to eq(expected)
  end

  # The release notes are copied from here into GitHub Discussions and makandracards,
  # so they must link to unpoly.com even when copied from the preview.
  it 'links unpoly.com from the external post, also in the preview' do
    response = Rack::MockRequest.new(Capybara.app).get('/changes/external_post', 'HTTP_HOST' => 'unpoly.test')
    body = response.body.force_encoding('UTF-8')

    expect(response.status).to eq(200)
    expect(body).to include('](https://unpoly.com/')
    expect(body).not_to include('unpoly.test')
  end

end
