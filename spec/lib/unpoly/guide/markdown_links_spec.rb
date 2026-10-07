describe Unpoly::Guide::MarkdownLinks do

  let(:twin_paths) { Set['/up.render', '/start/links', '/changes/1.0.0', '/support'] }

  describe Unpoly::Guide::MarkdownLinks::Web do
    subject(:links) { described_class.new(base_url: 'http://localhost:4568', twin_paths: twin_paths, page_path: '/start/links') }

    it 'links a page with a twin to the twin, on the base URL, keeping the anchor' do
      expect(links.href('/up.render')).to eq('http://localhost:4568/up.render.md')
      expect(links.href('/up.render#options.target')).to eq('http://localhost:4568/up.render.md#options.target')
    end

    it 'keeps the extension-less URL of a page without a twin' do
      expect(links.href('/imprint')).to eq('http://localhost:4568/imprint')
      expect(links.href('/imprint#contact')).to eq('http://localhost:4568/imprint#contact')
    end

    it 'links the root to the generated index' do
      expect(links.href('/')).to eq('http://localhost:4568/index.md')
    end

    it 'treats full unpoly.com URLs as links into the site' do
      expect(links.href('https://unpoly.com/up.render')).to eq('http://localhost:4568/up.render.md')
      expect(links.href('https://unpoly.com')).to eq('http://localhost:4568/index.md')
      expect(links.href('https://unpoly.com#install')).to eq('http://localhost:4568/index.md#install')
      expect(links.href('https://unpoly.community/x')).to eq('https://unpoly.community/x')
    end

    it 'keeps anchors on the same page and links to other sites' do
      expect(links.href('#usage')).to eq('#usage')
      expect(links.href('https://github.com/unpoly/unpoly')).to eq('https://github.com/unpoly/unpoly')
      expect(links.href('mailto:support@unpoly.com')).to eq('mailto:support@unpoly.com')
    end

    it 'resolves a relative link against the page' do
      expect(links.href('forms')).to eq('http://localhost:4568/start/forms')
      expect(links.href('../up.render')).to eq('http://localhost:4568/up.render.md')
    end

    it 'links media and the HTML page on the base URL' do
      expect(links.media_url('/images/api/a.png')).to eq('http://localhost:4568/images/api/a.png')
      expect(links.page_url).to eq('http://localhost:4568/start/links')
    end
  end

  describe Unpoly::Guide::MarkdownLinks::Skill do
    let(:files) do
      {
        '/up.render' => 'references/api/up-render-function.md',
        '/start/links' => 'references/learn/start-links.md',
      }
    end

    subject(:links) { described_class.new(files: files, file: 'references/learn/start-links.md', twin_paths: twin_paths, page_path: '/start/links') }

    it 'links a page of the skill by a relative file path, keeping the anchor' do
      expect(links.href('/up.render#options.target')).to eq('../api/up-render-function.md#options.target')
      expect(links.href('/start/links')).to eq('start-links.md')
    end

    it 'links a page outside the skill on unpoly.com, to its twin where there is one' do
      expect(links.href('/support')).to eq('https://unpoly.com/support.md')
      expect(links.href('/changes/1.0.0')).to eq('https://unpoly.com/changes/1.0.0.md')
      expect(links.href('/imprint')).to eq('https://unpoly.com/imprint')
    end

    it 'links media and the HTML page on unpoly.com, since the skill ships neither' do
      expect(links.media_url('/images/api/a.png')).to eq('https://unpoly.com/images/api/a.png')
      expect(links.page_url).to eq('https://unpoly.com/start/links')
    end

    it 'makes a skill path relative to the file being written' do
      expect(links.relative('SKILL.md')).to eq('../../SKILL.md')
    end
  end

end
