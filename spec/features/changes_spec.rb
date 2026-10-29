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

  # Unpoly collects the notes for the next release under an "Unreleased" heading until it
  # knows the version number. The changelog spec constructs this case; this checks the
  # pages against the real checkout, when it has such a section.
  it 'shows none of the Unreleased section' do
    changelog_path = File.join(Unpoly::Site.current.path, 'docs', 'changes', "CHANGELOG_#{Unpoly::Site.current.changelog.current_major}.x.md")
    unreleased = File.read(changelog_path)[/^Unreleased\n-+\n(.*?)(?=^\d+\.\d+\.\d+\S*\n-+$)/m, 1]
    skip 'the Unpoly changelog has no Unreleased section' if unreleased.blank?

    # The pages render the Markdown, so we look for the longest run of plain words in each entry.
    phrases = unreleased.split(/\n\s*\n|^\s*- /).filter_map { |entry|
      plain = entry.gsub(/\[([^\]]*)\]\([^)]*\)/, '\1').gsub(/[`*_]/, '')
      plain.scan(/[A-Za-z]+(?:[ ,]+[A-Za-z]+){4,}/).max_by(&:length)
    }
    expect(phrases).to be_present

    request = Rack::MockRequest.new(Capybara.app)
    newest = Unpoly::Site.current.versions.first
    texts = {
      '/changes' => Nokogiri::HTML(request.get('/changes').body).text,
      "/changes/#{newest}" => Nokogiri::HTML(request.get("/changes/#{newest}").body).text,
      '/changes/external_post' => Nokogiri::HTML(request.get('/changes/external_post').body).text,
      'releases.json' => request.get('/skills/unpoly-docs/references/changes/releases.json').body,
    }

    texts.each do |path, text|
      text = text.dup.force_encoding('UTF-8').squish
      phrases.each do |phrase|
        expect(text).not_to include(phrase), "#{path} shows #{phrase.inspect} from the Unreleased section"
      end
    end
  end

end
