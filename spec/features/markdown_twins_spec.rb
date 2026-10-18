require 'rack/mock'
require 'yaml'

# The Markdown twins of the documentation pages (/api/up.render.md), the index agents start
# from (/index.md, /llms.txt) and the agent skill's files, as the preview serves them.
#
# Golden files in spec/fixtures/markdown pin the twins of the parser fixtures (one page
# with one of everything the converter handles, a module, features), so that every
# change in the output shows up as a diff. After a deliberate change, rewrite them with
#
#     UPDATE_GOLDEN=1 bundle exec rspec spec/features/markdown_twins_spec.rb
#
# and review the diff.
describe 'Markdown twins', type: :feature do

  GOLDEN_DIR = File.expand_path('../fixtures/markdown', __dir__)

  def get(path, headers = {})
    Rack::MockRequest.new(Capybara.app).get(path, { 'HTTP_HOST' => 'unpoly.test' }.merge(headers))
  end

  def markdown(path)
    response = get(path)
    expect(response.status).to eq(200), "GET #{path} answered #{response.status}:\n#{response.body[0, 2000]}"
    response.body.force_encoding('UTF-8')
  end

  def expect_golden(path, name)
    # The documented version changes with every release, the golden files should not.
    actual = markdown(path).gsub(Unpoly::Site.current.version, '<version>')
    golden = File.join(GOLDEN_DIR, "#{name}.md")
    if ENV['UPDATE_GOLDEN']
      FileUtils.mkdir_p(GOLDEN_DIR)
      File.write(golden, actual)
    end
    expect(File).to exist(golden), "#{golden} is missing (UPDATE_GOLDEN=1 to write it)"
    expect(actual).to eq(File.read(golden)), "#{path} differs from #{golden} (UPDATE_GOLDEN=1 to accept)"
  end

  describe 'golden files' do
    {
      '/learn/test.markdown.md' => 'test.markdown',
      '/learn/test.page.md' => 'test.page',
      '/api/test.module.md' => 'test.module',
      '/api/test.Class.md' => 'test.Class',
      '/api/test.module.function.md' => 'test.module.function',
      '/api/test.module.paramSections.md' => 'test.module.paramSections',
      '/api/test.module.deprecatedFunction.md' => 'test.module.deprecatedFunction',
      '/api/test.module.functionWithLearnRefs.md' => 'test.module.functionWithLearnRefs',
      '/api/test-module-selector.md' => 'test-module-selector',
    }.each do |path, name|
      it "converts #{path} as pinned in spec/fixtures/markdown/#{name}.md" do
        expect_golden(path, name)
      end
    end
  end

  describe 'a twin' do
    it 'is served as Markdown' do
      expect(get('/learn/test.page.md').headers['Content-Type']).to eq('text/markdown; charset=utf-8')
    end

    it 'links to other twins on the host it was requested from' do
      expect(markdown('/learn/start/links.md')).to include('](http://unpoly.test/api/up-follow.md)')
    end

    it 'names the kind and module of a feature in its front matter, the module in its nav line, and neither in its title' do
      text = markdown('/api/up.render.md')
      expect(text).to start_with(%(---\nname: "up.render"\narea: "API"\nkind: "JavaScript function"\nparent: "up.fragment module"\nurl: "http://unpoly.test/api/up.render"\n---\n))
      expect(text).to include(%(<nav aria-label="Unpoly docs">[All docs](http://unpoly.test/index.md) · [up.fragment module](http://unpoly.test/api/up.fragment.md)</nav>\n\n# up.render([target], [options])\n))
    end

    it 'places each page in the hierarchy: area, kind and parent in the front matter, the parent in the nav line' do
      feature = markdown('/api/up-follow.md')
      expect(feature).to include(%(kind: "HTML attribute"\nparent: "up.link module"))
      expect(feature).to include('# [up-follow]' + "\n")
      expect(markdown('/api/up.Layer.md')).to include(%(parent: "up.layer module"))
      expect(markdown('/api/up.layer.md')).to include(%(kind: "module"\nparent: "API reference"))
      learn = markdown('/learn/following-links.md')
      expect(learn).to include(%(parent: "Links chapter"))
      expect(learn).to match(%r{<nav aria-label="Unpoly docs">.*\[Links chapter\]\(.*/links\.md\)</nav>})
      expect(markdown('/learn/links.md')).to include(%(parent: "Learn"))
    end

    it 'exists for the hubs, the changelog and /support' do
      %w[/learn.md /api.md /changes.md /changes/upgrading.md /support.md /api/formats.md].each { |path| markdown(path) }
      expect(markdown('/changes/3.0.0.md')).to include(%(released: "))
    end
  end

  describe 'the agent index' do
    it 'lists the Learn chapters and API modules, in the llms.txt shape' do
      text = markdown('/index.md')
      expect(text).to start_with("# Unpoly\n\n> ")
      expect(text).to include("## Learn\n", "## API\n", "## Changes\n", "## Support\n")
      expect(text).to include('- [`up.link`](http://unpoly.test/api/up.link.md): ')
      expect(text).to include('{#hash}')
    end

    it 'shows the Markdown URL example on its own origin, with the suffix in bold' do
      expect(markdown('/index.md')).to include('e.g. [http://unpoly.test/api/up.render**.md**](http://unpoly.test/api/up.render.md).')
    end

    it 'is also /llms.txt' do
      expect(markdown('/llms.txt')).to eq(markdown('/index.md'))
    end
  end

  describe 'the skill' do
    it "has a SKILL.md whose front matter install indexes can read" do
      text = markdown('/skills/unpoly-docs/SKILL.md')
      front_matter = YAML.safe_load(text[/\A---\n(.*?)\n---\n/m, 1])
      expect(front_matter['name']).to eq('unpoly-docs')
      expect(front_matter['description']).to start_with("Unpoly's guides, API reference and release notes")
      expect(front_matter['metadata']['unpoly_version']).to eq(Unpoly::Site.current.version)
      expect(front_matter['metadata']['build']).to match(/\A\d{4}\.\d+\.\d+\z/)
      expect(text).to include('- [`up.link`](references/api/up-link-module.md): ')
      expect(text).to include('point the user to https://unpoly.com/support.')
    end

    it 'has reference files that link each other by relative paths and the site by unpoly.com' do
      text = markdown('/skills/unpoly-docs/references/learn/start-links.md')
      expect(text).to include(%(url: "https://unpoly.com/learn/start/links"))
      expect(text).to include('<nav aria-label="Unpoly docs">[All docs](../../SKILL.md) · [Getting started chapter](start-overview.md)</nav>')
      expect(text).to include('](../api/up-follow-selector.md)')
    end

    it 'fills [[=base_url]] with the request’s origin on the web and with unpoly.com in the skill' do
      example = '/api/up.render**.md**]('
      expect(markdown('/learn/skill.md')).to include("[http://unpoly.test#{example}http://unpoly.test/api/up.render.md)")
      expect(markdown('/skills/unpoly-docs/references/learn/skill.md')).to include("[https://unpoly.com#{example}https://unpoly.com/api/up.render.md)")
    end

    it 'shows the release notes script on the upgrading page only in the skill' do
      expect(markdown('/skills/unpoly-docs/references/changes/upgrading.md')).to include('scripts/releases.py')
      expect(markdown('/changes/upgrading.md')).not_to include('releases.py')
    end

    it 'lists every release in version order for releases.py' do
      releases = JSON.parse(get('/skills/unpoly-docs/references/changes/releases.json').body)
      versions = releases.map { |release| release['version'] }
      expect(versions.first).to eq('0.1.0')
      expect(versions.index('3.9.0')).to be < versions.index('3.10.0')
      expect(releases.last['path']).to start_with('references/changes/')
    end

    it 'serves the search script but not its tests' do
      expect(get('/skills/unpoly-docs/scripts/search.py').status).to eq(200)
      expect(get('/skills/unpoly-docs/scripts/releases.py').status).to eq(200)
      expect(get('/skills/unpoly-docs/scripts/test_search.py').status).to eq(404)
      expect(get('/skills/unpoly-docs/scripts/test_releases.py').status).to eq(404)
    end
  end

  describe 'pages' do
    it 'link their twin from the ai-tools corner and the document head' do
      visit '/api/up.render'
      expect(page).to have_css('.ai-tools[data-markdown="ignore"] a.ai-tools--item.-markdown[href="/api/up.render.md"][type="text/markdown"]')
      expect(page).to have_css('head link[rel="alternate"][type="text/markdown"][href="/api/up.render.md"]', visible: false)
    end

    it 'list their place in the reading order in the head' do
      visit '/learn/start/links'
      expect(page).to have_css('head link[rel="prev"][href="/learn/install"]', visible: false)
      expect(page).to have_css('head link[rel="next"][href="/learn/start/forms"]', visible: false)
      expect(page).to have_css('nav.reading-nav[aria-label="Reading order"] a[aria-label^="Next: "]')
    end

    it 'have the ai-tools corner on pages without an Edit link too' do
      %w[/learn /api /changes /changes/upgrading /support /api/formats /changes/3.0.0].each do |path|
        visit path
        expect(page).to have_css(%(.ai-tools a.ai-tools--item.-markdown[href="#{path}.md"])), "no ai-tools corner on #{path}"
      end
    end

    it 'point agents from the landing page to the index, without an ai-tools corner' do
      visit '/'
      expect(page).not_to have_css('.ai-tools')
      expect(page).to have_css('head link[rel="alternate"][type="text/markdown"][href="/index.md"]', visible: false)
      expect(page).to have_css('head link[rel="alternate"][href="/llms.txt"]', visible: false)
    end
  end

end
