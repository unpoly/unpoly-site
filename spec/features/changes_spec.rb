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

  it 'posts the newest releases externally' do
    body = Rack::MockRequest.new(Capybara.app).get('/changes/external_post').body.force_encoding('UTF-8')
    posted = body.scan(/^(\d+\.\d+\.\d+\S*)\n=+$/).flatten

    expect(posted).to eq(Unpoly::Site.current.versions.first(5))
  end

  # The site is deployed independently of Unpoly releases, so the changelog in the Unpoly
  # checkout often documents a version that has no git tag yet (see Changelog#released?).
  it 'leaves out documented versions that are not released yet' do
    changelog_paths = Dir[File.join(Unpoly::Site.current.path, 'docs', 'changes', 'CHANGELOG_*.md')]
    documented = changelog_paths.flat_map { |path| File.read(path).scan(/^(\d+\.\d+\.\d+(?:-[a-z\d]+)?)\n-+$/).flatten }
    tags = `git -C #{Shellwords.escape(Unpoly::Site.current.path)} tag --list 'v*'`.split("\n")
    unreleased = documented.reject { |version| tags.include?("v#{version}") }
    skip 'the Unpoly checkout documents no unreleased version' if unreleased.empty?

    request = Rack::MockRequest.new(Capybara.app)
    index = request.get('/changes').body
    external_post = request.get('/changes/external_post').body
    releases_json = request.get('/skills/unpoly-docs/references/changes/releases.json').body

    unreleased.each do |version|
      expect(request.get("/changes/#{version}").status).to eq(404)
      expect(request.get("/changes/#{version}.md").status).to eq(404)
      expect(request.get("/skills/unpoly-docs/references/changes/#{version.tr('.', '-')}.md").status).to eq(404)
      expect(index).not_to include("/changes/#{version}\"")
      expect(external_post).not_to match(/^#{Regexp.escape(version)}$/)
      expect(releases_json).not_to include(%("#{version}"))
    end
  end

end
