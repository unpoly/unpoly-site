require 'tmpdir'

describe Unpoly::Guide::SkillPackage do

  around do |example|
    Dir.mktmpdir do |dir|
      @build_dir = dir
      example.run
    end
  end

  let(:package) { described_class.new(build_dir: @build_dir, stamp: '2026.1007.1430') }

  def write(path, content)
    full_path = File.join(@build_dir, 'skills/unpoly-docs', path)
    FileUtils.mkdir_p(File.dirname(full_path))
    File.write(full_path, content)
  end

  def reference(name: 'up.render', body: '')
    %(---\nname: "#{name}"\narea: "API"\nurl: "https://unpoly.com/up.render"\n---\n# Title\n\n#{body}\n)
  end

  before do
    write('SKILL.md', %(---\nname: unpoly-docs\ndescription: "Unpoly's docs: everything."\nmetadata:\n  build: "x"\n---\n# Unpoly docs\n\n- [up.render](references/api/up-render-function.md)\n))
    write('scripts/search.py', 'print(1)')
    write('references/api/up-render-function.md', reference(body: '[Learn](../learn/start-links.md#links) [Out](https://unpoly.com/support.md) [Here](#here)'))
    write('references/learn/start-links.md', reference(name: 'x', body: '`[label](/path)` and ```\n[x](missing.md)\n```'))
  end

  describe '#problems' do
    it 'finds none in a sound skill' do
      expect(package.problems).to eq([])
    end

    it 'finds a relative link to a missing file' do
      write('references/api/up-follow-selector.md', reference(body: '[Gone](gone.md#x)'))
      expect(package.problems).to include('references/api/up-follow-selector.md: broken link to gone.md#x')
    end

    it 'finds file names that differ only in case' do
      write('references/api/Up-render-function.md', reference)
      expect(package.problems.join).to include('differ only in case')
    end

    it 'finds : and $ in file names' do
      write('references/api/up:link.md', reference)
      write('references/api/up.$on.md', reference)
      expect(package.problems.grep(/break file systems/).size).to eq(2)
    end

    it 'finds test files' do
      write('scripts/test_search.py', '')
      expect(package.problems.join).to include('test file')
    end

    it 'finds front matter that the search cannot read' do
      write('references/api/a.md', "---\nname: up.render\n---\n")
      write('references/api/b.md', "# No front matter\n")
      write('references/api/c.md', %(---\nnames: ["a", "b"]\n---\n))
      expect(package.problems.grep(/front matter/).size).to eq(3)
    end

    it 'finds too many files' do
      stub_const("#{described_class}::MAX_FILES", 4)
      expect(package.problems.join).to include('at most 3')
    end
  end

  describe '#package!' do
    before { package.package! }

    def read(path)
      File.binread(File.join(@build_dir, path))
    end

    it 'writes the tarball with SKILL.md at its root, and the well-known index with its digest' do
      tarball = read('agent-skills/unpoly-docs.tar.gz')
      names = []
      Gem::Package::TarReader.new(Zlib::GzipReader.new(StringIO.new(tarball))) { |tar| tar.each { |entry| names << entry.full_name } }
      expect(names).to include('SKILL.md', 'scripts/search.py', 'references/api/up-render-function.md')

      index = JSON.parse(read('agent-skills/index.json'))
      expect(index['skills']).to eq([{
        'name' => 'unpoly-docs',
        'type' => 'archive',
        'description' => "Unpoly's docs: everything.",
        'url' => '/.well-known/agent-skills/unpoly-docs.tar.gz',
        'digest' => "sha256:#{Digest::SHA256.hexdigest(tarball)}",
      }])
    end

    it 'writes the plugin zip with the skill under skills/unpoly-docs/, and the marketplace with its version and digest' do
      zip = read('claude-plugins/unpoly.zip')
      names = zip.scan(/PK\x01\x02.{42}/mn).size
      expect(names).to eq(4)
      expect(zip).to include('skills/unpoly-docs/SKILL.md')

      marketplace = JSON.parse(read('claude-plugins/marketplace.json'))
      expect(marketplace['name']).to eq('unpoly')
      expect(marketplace['plugins']).to eq([{
        'name' => 'unpoly',
        'description' => "Unpoly's docs: everything.",
        'version' => '2026.1007.1430',
        'source' => {
          'source' => 'archive',
          'url' => 'https://unpoly.com/claude-plugins/unpoly.zip',
          'sha256' => Digest::SHA256.hexdigest(zip),
        },
      }])
    end

    it 'writes a zip that unzip accepts', if: system('which unzip > /dev/null') do
      path = File.join(@build_dir, 'claude-plugins/unpoly.zip')
      listing = `unzip -Z1 #{path}`
      expect($?).to be_success
      expect(listing.lines.map(&:chomp)).to include('skills/unpoly-docs/references/learn/start-links.md')
      expect(`unzip -p #{path} skills/unpoly-docs/scripts/search.py`).to eq('print(1)')
    end
  end

  it 'refuses to pack a broken skill' do
    write('references/api/broken.md', reference(body: '[Gone](gone.md)'))
    expect { package.package! }.to raise_error(described_class::Invalid, /broken link/)
  end

end
