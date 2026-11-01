require 'nokogiri'

# What search engines learn about a page beyond its text: whether to list it, the one URL
# to list it under (canonical), and where to find every page (sitemap, robots.txt).
# One rule decides all three (indexable? and canonical_url in config.rb).
describe 'search engines', type: :feature do

  def head_of(path)
    visit path
    Nokogiri::HTML(page.html).at('head')
  end

  def robots_of(path)
    head_of(path).at('meta[name=robots]')&.[]('content')
  end

  def canonical_of(path)
    links = head_of(path).css('link[rel=canonical]')
    expect(links.size).to be <= 1, "#{path} has #{links.size} canonical links"
    links.first&.[]('href')
  end

  def sitemap_urls
    visit '/sitemap.xml'
    xml = Nokogiri::XML(page.body) { |config| config.strict }
    xml.remove_namespaces!
    xml.css('urlset > url > loc').map(&:text)
  end

  let(:release_path) { "/changes/#{Unpoly::Site.current.releases.first.version}" }

  describe 'the menus' do
    it 'asks search engines to follow their links, but not to list them' do
      %w[/learn/menu /api/menu /changes/menu /menu/narrow /version_choice].each do |path|
        expect(robots_of(path)).to eq('noindex, follow'), "#{path} should be noindex, follow"
        expect(canonical_of(path)).to be_nil, "#{path} should have no canonical link"
      end
    end
  end

  it 'lets search engines list a documentation page' do
    expect(robots_of('/api/up-defer')).to be_nil
    expect(robots_of('/learn/lazy-loading')).to be_nil
  end

  it 'keeps the parser fixtures out of search engines' do
    expect(robots_of('/api/test.module.function')).to eq('noindex, follow')
    expect(robots_of('/learn/test.page')).to eq('noindex, follow')
  end

  describe 'the canonical link' do
    it 'names the production URL without a trailing slash' do
      expect(canonical_of('/api/up-defer')).to eq('https://unpoly.com/api/up-defer')
      expect(canonical_of('/api/up-defer/')).to eq('https://unpoly.com/api/up-defer')
      expect(canonical_of('/learn/lazy-loading')).to eq('https://unpoly.com/learn/lazy-loading')
      expect(canonical_of('/api/up:link:follow')).to eq('https://unpoly.com/api/up:link:follow')
      expect(canonical_of(release_path)).to eq("https://unpoly.com#{release_path}")
    end

    it 'names the hubs and the landing page' do
      expect(canonical_of('/')).to eq('https://unpoly.com/')
      expect(canonical_of('/learn')).to eq('https://unpoly.com/learn')
      expect(canonical_of('/api')).to eq('https://unpoly.com/api')
    end

    it 'names the URL under which the sitemap lists the page' do
      urls = sitemap_urls
      ['/', '/learn', '/api', '/api/up-defer', '/learn/lazy-loading', release_path].each do |path|
        expect(urls).to include(canonical_of(path))
      end
    end
  end

  describe 'the sitemap' do
    it 'lists every documentation page once, by its canonical URL' do
      urls = sitemap_urls
      expect(urls).to eq(urls.uniq)
      expect(urls.size).to be > 500
      expect(urls).to all(match(%r{\Ahttps://unpoly\.com/}))
      expect(urls.grep(%r{\Ahttps://unpoly\.com/.+/\z})).to be_empty
    end

    it 'leaves out the menus, the parser fixtures, Markdown twins and pages outside the layout' do
      paths = sitemap_urls.map { |url| url.delete_prefix('https://unpoly.com') }
      expect(paths).not_to include('/learn/menu', '/api/menu', '/changes/menu', '/menu/narrow', '/version_choice')
      expect(paths).not_to include('/api/test.module.function', '/learn/test.page', '/api/test.module')
      expect(paths.grep(/\.(md|txt|xml)\z/)).to be_empty
      expect(paths.grep(%r{\A/(examples|images)/})).to be_empty
      expect(paths).not_to include('/changes/external_post', '/changes/google_groups')
    end

    it 'has no <lastmod>, <priority> or <changefreq>' do
      visit '/sitemap.xml'
      expect(page.body).not_to match(/<(lastmod|priority|changefreq)>/)
    end
  end

  # What a search result shows below its headline, and a link unfurler (Slack, GitHub)
  # below its title.
  describe 'the description and Open Graph tags' do
    def meta_of(path)
      head = head_of(path)
      {
        description: head.css('meta[name=description]').map { |meta| meta['content'] },
        og_description: head.css('meta[property="og:description"]').map { |meta| meta['content'] },
        og_title: head.at('meta[property="og:title"]')&.[]('content'),
        og_url: head.at('meta[property="og:url"]')&.[]('content'),
        og_image: head.at('meta[property="og:image"]')&.[]('content'),
        og_image_width: head.at('meta[property="og:image:width"]')&.[]('content'),
        og_image_height: head.at('meta[property="og:image:height"]')&.[]('content'),
        og_image_alt: head.at('meta[property="og:image:alt"]')&.[]('content'),
        twitter_card: head.at('meta[name="twitter:card"]')&.[]('content'),
        title: head.at('title').text,
      }
    end

    it 'describes a documentation page with its summary, the first paragraph of its text' do
      meta = meta_of('/api/up.render')

      expect(meta[:description].size).to eq(1)
      expect(meta[:description].first).to start_with('Replaces elements on the current page')
      expect(meta[:og_description]).to eq(meta[:description])
    end

    it 'describes a Learn page by its first paragraph as plain text' do
      meta = meta_of('/learn/following-links')

      expect(meta[:description].size).to eq(1)
      expect(meta[:description].first).to start_with('Any link can update a fragment of the current page')
      expect(meta[:description].first).not_to match(/[<>`\[\]]/)
    end

    it 'describes the landing page and the hubs with their own intro text' do
      # The landing page's lead-in ends in a colon, leading into the code samples. Its
      # trailer says what Unpoly does.
      expect(meta_of('/')[:description].first).to start_with('The application stays on your server')
      expect(meta_of('/learn')[:description]).to eq([find('.hub-intro').text.squish])
      expect(meta_of('/api')[:description]).to eq(['Technical reference for every attribute, function, event and HTTP header in Unpoly. For concepts and walkthroughs, see Learn.'])
    end

    # Most release notes start with a heading or a list, so their first paragraph would
    # be an arbitrary one, or the upgrading teaser's on every list-only release.
    it 'gives a release no description, but titles and links its unfurl' do
      ['/changes/3.10.0', '/changes/3.14.1', release_path].each do |path|
        meta = meta_of(path)
        expect(meta[:description]).to be_empty, "#{path} should have no description"
        expect(meta[:og_description]).to be_empty, "#{path} should have no og:description"
        expect(meta[:og_title]).to eq(meta[:title]), "og:title of #{path}"
        expect(meta[:og_url]).to eq(canonical_of(path)), "og:url of #{path}"
      end
    end

    it 'describes the upgrading page by its first paragraph' do
      expect(meta_of('/changes/upgrading')[:description].first).to start_with('New Unpoly releases will occasionally rename')
    end

    it 'titles and links an unfurl like the window title and the canonical link' do
      ['/', '/learn', '/api/up-defer', '/learn/lazy-loading', '/support'].each do |path|
        meta = meta_of(path)
        expect(meta[:og_title]).to eq(meta[:title]), "og:title of #{path}"
        expect(meta[:og_url]).to eq(canonical_of(path)), "og:url of #{path}"
        expect(meta[:description].size).to eq(1), "#{path} should have one description"
      end
    end

    # The image itself is rendered by the build (Unpoly::Site::OgImage, spec/lib).
    describe 'the preview image' do
      it 'names an image of the page, with its size and what it says' do
        ['/', '/learn', '/api/up-defer', '/learn/lazy-loading', release_path, '/support'].each do |path|
          meta = meta_of(path)
          expect(meta[:og_image]).to match(%r{\Ahttps://unpoly\.com/og/\h{16}\.png\z}), "og:image of #{path}"
          expect(meta.values_at(:og_image_width, :og_image_height)).to eq(%w[1200 630]), "og:image size of #{path}"
          expect(meta[:twitter_card]).to eq('summary_large_image'), "twitter:card of #{path}"
        end
      end

      it "describes a page's image by its title and description" do
        expect(meta_of('/api/up.render')[:og_image_alt]).to start_with('up.render(): Replaces elements on the current page')
        expect(meta_of('/learn')[:og_image_alt]).to eq("Learn Unpoly: #{meta_of('/learn')[:description].first}")
      end

      it "describes the landing page's image by the claim" do
        expect(meta_of('/')[:og_image_alt]).to start_with('Build a complete frontend in HTML: The application stays on your server')
      end

      it "describes a release's image by its date and commits, as it has no description" do
        release = Unpoly::Site.current.release_for_version('3.0.0')
        expect(meta_of('/changes/3.0.0')[:og_image_alt]).to eq("Version 3.0.0: Released on #{release.date.strftime('%B %d, %Y')} with #{release.commit_count} commits")
      end

      # That the same page keeps its image is up to the digest (spec/lib).
      it 'gives every page an image of its own' do
        images = ['/', '/learn', '/api', '/api/up-defer', '/api/up.render', '/learn/lazy-loading', release_path].map { |path| meta_of(path)[:og_image] }
        expect(images.uniq.size).to eq(images.size)
      end

      it 'leaves the image out where search engines may not list a page' do
        meta = meta_of('/learn/menu')
        expect(meta.values_at(:og_image, :og_image_width, :og_image_height, :og_image_alt, :twitter_card)).to all(be_nil)
      end

      it 'leaves the image out when the build does not render images (SKIP_OG_IMAGES=1)' do
        ENV['SKIP_OG_IMAGES'] = '1'
        meta = meta_of('/api/up-defer')
        expect(meta.values_at(:og_image, :og_image_width, :og_image_height, :og_image_alt, :twitter_card)).to all(be_nil)
        expect(meta[:og_title]).to be_present
      ensure
        ENV.delete('SKIP_OG_IMAGES')
      end
    end

    it 'swaps them when Unpoly navigates to another page', js: true do
      expected = meta_of('/api/up.link')
      visit '/api'
      page.execute_script('window.notReloaded = true')

      find('.api-row--name[href$="/api/up.link"]').click
      expect(page).to have_css('.guide--content h1', text: 'up.link')

      head = page.evaluate_script(<<~JS)
        (() => {
          let content = (selector) => [...document.head.querySelectorAll(selector)].map((meta) => meta.content)
          return {
            notReloaded: window.notReloaded,
            description: content('meta[name=description]'),
            ogDescription: content('meta[property="og:description"]'),
            ogTitle: content('meta[property="og:title"]'),
            ogUrl: content('meta[property="og:url"]'),
            ogImage: content('meta[property="og:image"]'),
            ogImageAlt: content('meta[property="og:image:alt"]'),
            title: document.title,
          }
        })()
      JS
      expect(head['notReloaded']).to eq(true)
      expect(head['description']).to eq(expected[:description])
      expect(head['description'].first).to be_present
      expect(head['ogDescription']).to eq(expected[:og_description])
      expect(head['ogTitle']).to eq([expected[:og_title]])
      expect(head['ogUrl']).to eq(['https://unpoly.com/api/up.link'])
      expect(head['ogImage']).to eq([expected[:og_image]])
      expect(head['ogImageAlt']).to eq([expected[:og_image_alt]])
    end

    it 'leaves them out where search engines may not list a page' do
      meta = meta_of('/learn/menu')
      expect(meta[:description]).to be_empty
      expect(meta[:og_title]).to be_nil
      expect(meta[:og_url]).to be_nil
    end
  end

  it 'names the sitemap in robots.txt' do
    visit '/robots.txt'
    expect(page.body).to include('Sitemap: https://unpoly.com/sitemap.xml')
    expect(page.body).to match(/^Disallow:\s*$/)
  end

end
