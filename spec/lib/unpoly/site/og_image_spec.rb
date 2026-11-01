require 'tmpdir'

describe Unpoly::Site::OgImage do

  # An image as config.rb's og_image helper builds it, with the page's Markdown twin.
  def image(path, title: 'Title', text: 'Text', **subject)
    twin = Unpoly::Site::MarkdownTwins::Twin.new(path, subject) if subject.any?
    Unpoly::Site::OgImage.new(title: title, text: text, page_path: path, twin: twin)
  end

  def glyph(name)
    Unpoly::Site::Icon.html(name)
  end

  describe '#data' do
    it 'shows an API symbol in code, with the glyph and name of its kind' do
      data = image('/api/up.render', title: 'up.render()', documentable: 'up.render').data
      expect(data).to include(title: 'up.render()', code: true, text: 'Text', glyph: glyph('kind-js'), label: 'JavaScript function')

      expect(image('/api/up:link:follow', documentable: 'up:link:follow').data).to include(glyph: glyph('kind-event'), label: 'DOM event')
      expect(image('/api/up.layer.config', documentable: 'up.layer.config').data).to include(glyph: glyph('kind-config'), label: 'Configuration object')
      expect(image('/api/up-defer', documentable: 'up-defer').data).to include(glyph: glyph('kind-attr'), label: 'HTML attribute')
    end

    it 'shows a namespace or class with the package glyph and its kind' do
      expect(image('/api/up.link', documentable: 'up.link').data).to include(code: true, glyph: glyph('package'), label: 'JavaScript namespace')
      expect(image('/api/up.Layer', documentable: 'up.Layer').data).to include(code: true, glyph: glyph('package'), label: 'JavaScript class')
    end

    it "shows any other page in prose, with the glyph and name of its area" do
      expect(image('/learn/lazy-loading', documentable: 'lazy-loading').data).to include(code: false, glyph: glyph('book'), label: 'Learn Unpoly')
      expect(image('/learn', page: :learn).data).to include(glyph: glyph('book'), label: 'Learn Unpoly')
      expect(image('/api', page: :api).data).to include(code: false, glyph: glyph('package'), label: 'API reference')
      expect(image('/changes/3.0.0', release: '3.0.0').data).to include(code: false, glyph: glyph('tag'), label: 'Changes')
      expect(image('/changes', page: :changes).data).to include(glyph: glyph('tag'), label: 'Changes')
      expect(image('/changes/upgrading', page: :upgrading).data).to include(glyph: glyph('tag'), label: 'Changes')
    end

    it 'shows no glyph and no name for a page outside the three areas' do
      expect(image('/support', page: :support).data).to include(glyph: nil, label: nil)
      expect(image('/').data).to include(glyph: nil, label: nil)
      expect(image('/privacy').data).to include(glyph: nil, label: nil)
    end

    it "shows the URL of the page's breadcrumb parent, so that a long name cannot run out of room" do
      expect(image('/api/up.Preview.prototype.showPlaceholder', documentable: 'up.Preview.prototype.showPlaceholder').data[:url]).to eq('unpoly.com/api/up.Preview')
      expect(image('/api/up.render', documentable: 'up.render').data[:url]).to eq('unpoly.com/api/up.fragment')
      expect(image('/api/up.link', documentable: 'up.link').data[:url]).to eq('unpoly.com/api')
      expect(image('/learn/feedback-classes', documentable: 'feedback-classes').data[:url]).to eq('unpoly.com/learn/loading-state')
      expect(image('/changes/3.0.0', release: '3.0.0').data[:url]).to eq('unpoly.com/changes')
    end

    it 'shows the URL of a page without a breadcrumb itself' do
      expect(image('/learn', page: :learn).data[:url]).to eq('unpoly.com/learn')
      expect(image('/support', page: :support).data[:url]).to eq('unpoly.com/support')
      expect(image('/imprint').data[:url]).to eq('unpoly.com/imprint')
      expect(image('/').data[:url]).to eq('unpoly.com')
    end
  end

  describe '#digest' do
    it 'stays the same for the same content' do
      expect(image('/api/up.render', documentable: 'up.render').digest).to match(/\A\h{16}\z/)
      expect(image('/api/up.render', documentable: 'up.render').digest).to eq(image('/api/up.render', documentable: 'up.render').digest)
    end

    it 'changes with anything the image shows' do
      digests = [
        image('/api/up.render', documentable: 'up.render'),
        image('/api/up.render', documentable: 'up.render', text: 'Other text'),
        image('/api/up.render', documentable: 'up.render', title: 'Other title'),
        image('/api/up.render', documentable: 'up-follow'),
      ].map(&:digest)
      expect(digests.uniq.size).to eq(4)
    end

    it 'changes with the template' do
      before = image('/').digest
      allow(described_class).to receive(:template_digest).and_return('other')
      expect(image('/').digest).not_to eq(before)
    end

    it 'names the image URL' do
      img = image('/')
      expect(img.url).to eq("https://unpoly.com/og/#{img.digest}.png")
    end
  end

  it 'describes the image by its title and text' do
    expect(image('/', title: 'Version 3.0.0', text: 'Released on May 1, 2025').alt).to eq('Version 3.0.0: Released on May 1, 2025')
    expect(image('/', title: 'Imprint', text: nil).alt).to eq('Imprint')
  end

  describe '.build!' do
    around do |example|
      Dir.mktmpdir do |dir|
        @cache_dir = File.join(dir, 'cache')
        @build_dir = File.join(dir, 'build')
        example.run
      end
    end

    let(:renderer) { double('renderer', render: 'PNG') }

    def build!(since:)
      described_class.build!(build_dir: @build_dir, cache_dir: @cache_dir, since: since)
    end

    it "renders the images that the build's pages registered, and copies them into the build" do
      since = Time.now - 1
      images = [image('/a'), image('/b')]
      images.each { |img| img.register!(cache_dir: @cache_dir) }

      expect(described_class::Renderer).to receive(:open).once.and_yield(renderer)
      expect(build!(since: since)).to eq("2 preview images in #{@build_dir}/og, 2 of them newly rendered.")
      images.each { |img| expect(File.read(File.join(@build_dir, img.path))).to eq('PNG') }
    end

    it 'renders an image only once, and does not start Chrome when nothing is new' do
      allow(described_class::Renderer).to receive(:open).and_yield(renderer)
      image('/a').register!(cache_dir: @cache_dir)
      build!(since: Time.now - 1)

      expect(described_class::Renderer).not_to receive(:open)
      image('/a').register!(cache_dir: @cache_dir)
      expect(build!(since: Time.now - 1)).to eq("1 preview images in #{@build_dir}/og, 0 of them newly rendered.")
      expect(File).to exist(File.join(@build_dir, image('/a').path))
    end

    it 'leaves out images that only an earlier build registered' do
      allow(described_class::Renderer).to receive(:open).and_yield(renderer)
      image('/old').register!(cache_dir: @cache_dir)
      FileUtils.touch(Dir[File.join(@cache_dir, '*')], mtime: Time.now - 60)
      image('/new').register!(cache_dir: @cache_dir)

      build!(since: Time.now - 1)
      expect(Dir[File.join(@build_dir, 'og', '*')]).to eq([File.join(@build_dir, image('/new').path)])
    end

    it 'deletes cached images that no build used for a month' do
      allow(described_class::Renderer).to receive(:open).and_yield(renderer)
      image('/old').register!(cache_dir: @cache_dir)
      build!(since: Time.now - 1)
      FileUtils.touch(Dir[File.join(@cache_dir, '*')], mtime: Time.now - 31 * 24 * 60 * 60)

      build!(since: Time.now - 1)
      expect(Dir[File.join(@cache_dir, '*')]).to be_empty
    end

    it 'keeps a cached image that the build uses, however long ago it was rendered' do
      allow(described_class::Renderer).to receive(:open).and_yield(renderer)
      image('/a').register!(cache_dir: @cache_dir)
      build!(since: Time.now - 1)
      FileUtils.touch(Dir[File.join(@cache_dir, '*')], mtime: Time.now - 31 * 24 * 60 * 60)

      expect(described_class::Renderer).not_to receive(:open)
      image('/a').register!(cache_dir: @cache_dir)
      build!(since: Time.now - 1)
      expect(Dir[File.join(@cache_dir, '*')].map { |file| File.basename(file) }).to contain_exactly("#{image('/a').digest}.json", "#{image('/a').digest}.png")
    end
  end

  describe described_class::Renderer do
    it 'renders an image of 1200×630 pixels in Chrome' do
      png = described_class.open { |renderer| renderer.render(image('/api/up.render', documentable: 'up.render').data) }

      # The PNG signature, then the IHDR chunk with width and height.
      expect(png[0, 8]).to eq("\x89PNG\r\n\x1A\n".b)
      expect(png[16, 8].unpack('NN')).to eq([1200, 630])
    end
  end

end
