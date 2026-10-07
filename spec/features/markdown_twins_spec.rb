require 'rack/mock'
require 'yaml'

# The Markdown twins of the documentation pages (/up.render.md), the index agents start
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
    actual = markdown(path).gsub(Unpoly::Guide.current.version, '<version>')
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
      '/test.markdown.md' => 'test.markdown',
      '/test.page.md' => 'test.page',
      '/test.module.md' => 'test.module',
      '/test.Class.md' => 'test.Class',
      '/test.module.function.md' => 'test.module.function',
      '/test.module.paramSections.md' => 'test.module.paramSections',
      '/test.module.deprecatedFunction.md' => 'test.module.deprecatedFunction',
      '/test.module.functionWithLearnRefs.md' => 'test.module.functionWithLearnRefs',
      '/test-module-selector.md' => 'test-module-selector',
    }.each do |path, name|
      it "converts #{path} as pinned in spec/fixtures/markdown/#{name}.md" do
        expect_golden(path, name)
      end
    end
  end

  describe 'a twin' do
    it 'is served as Markdown' do
      expect(get('/test.page.md').headers['Content-Type']).to eq('text/markdown; charset=utf-8')
    end

    it 'links to other twins on the host it was requested from' do
      expect(markdown('/start/links.md')).to include('](http://unpoly.test/up-follow.md)')
    end

    it 'names the module of a feature in its nav line, and nothing in its front matter' do
      text = markdown('/up.render.md')
      expect(text).to start_with(%(---\nname: "up.render"\narea: "API"\nurl: "http://unpoly.test/up.render"\n---\n))
      expect(text).to include(%(<nav aria-label="Unpoly docs">[All docs](http://unpoly.test/index.md) · [up.fragment module](http://unpoly.test/up.fragment.md)</nav>\n\n# up.render([target], [options]) (JavaScript function)\n))
    end

    it 'exists for the hubs, the changelog and /support' do
      %w[/learn.md /api.md /changes.md /changes/upgrading.md /support.md /formats.md].each { |path| markdown(path) }
      expect(markdown('/changes/3.0.0.md')).to include(%(released: "))
    end
  end

  describe 'the agent index' do
    it 'lists the Learn chapters and API modules, in the llms.txt shape' do
      text = markdown('/index.md')
      expect(text).to start_with("# Unpoly\n\n> ")
      expect(text).to include("## Learn\n", "## API\n", "## Changes\n", "## Support\n")
      expect(text).to include('- [up.link](http://unpoly.test/up.link.md): ')
      expect(text).to include('{#hash}')
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
      expect(front_matter['description']).to start_with("Unpoly's complete documentation")
      expect(front_matter['metadata']['unpoly_version']).to eq(Unpoly::Guide.current.version)
      expect(front_matter['metadata']['build']).to match(/\A\d{4}\.\d+\.\d+\z/)
      expect(text).to include('- [up.link](references/api/up-link-module.md): ')
      expect(text).to include('https://unpoly.com/support.md')
    end

    it 'has reference files that link each other by relative paths and the site by unpoly.com' do
      text = markdown('/skills/unpoly-docs/references/learn/start-links.md')
      expect(text).to include(%(url: "https://unpoly.com/start/links"))
      expect(text).to include('<nav aria-label="Unpoly docs">[All docs](../../SKILL.md) · [Learn](index.md)</nav>')
      expect(text).to include('](../api/up-follow-selector.md)')
    end

    it 'serves the search script but not its tests' do
      expect(get('/skills/unpoly-docs/scripts/search.py').status).to eq(200)
      expect(get('/skills/unpoly-docs/scripts/test_search.py').status).to eq(404)
    end
  end

  describe 'pages' do
    it 'link their twin from an MD button and the document head' do
      visit '/up.render'
      expect(page).to have_css('a.md-link[href="/up.render.md"][type="text/markdown"][data-markdown="ignore"]', text: 'MD')
      expect(page).to have_css('head link[rel="alternate"][type="text/markdown"][href="/up.render.md"]', visible: false)
    end

    it 'list their place in the reading order in the head' do
      visit '/start/links'
      expect(page).to have_css('head link[rel="prev"][href="/install"]', visible: false)
      expect(page).to have_css('head link[rel="next"][href="/start/forms"]', visible: false)
      expect(page).to have_css('nav.reading-nav[aria-label="Reading order"] a[aria-label="Next: Submit forms"]')
    end

    it 'show the MD button on pages without an Edit link too' do
      %w[/learn /api /changes /changes/upgrading /support /formats /changes/3.0.0].each do |path|
        visit path
        expect(page).to have_css(%(a.md-link[href="#{path}.md"])), "no MD button on #{path}"
      end
    end

    it 'point agents from the landing page to the index, without an MD button' do
      visit '/'
      expect(page).not_to have_css('a.md-link')
      expect(page).to have_css('head link[rel="alternate"][type="text/markdown"][href="/index.md"]', visible: false)
      expect(page).to have_css('head link[rel="alternate"][href="/llms.txt"]', visible: false)
    end
  end

end
