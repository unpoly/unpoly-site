# The preview images of the last build (Unpoly::Site::OgImage): a page registers its image
# while it renders, and the build's last step renders and copies what was registered.
# Only a real build shows that the two meet, so this checks the build on disk. Skipped
# without one, as in CI.
describe 'the preview images of the built site' do

  def build_dir
    File.expand_path('../../build', __dir__)
  end

  # The tags that layouts/_head writes for a page's image, og:image first.
  def image_tags
    ['meta[property="og:image"]', 'meta[property="og:image:width"]', 'meta[property="og:image:height"]', 'meta[property="og:image:alt"]', 'meta[name="twitter:card"]']
  end

  # Each built page's canonical URL, whether search engines may list it, and its image tags.
  def pages
    @pages ||= Dir.glob('**/*.html', base: build_dir).map do |file|
      head = Nokogiri::HTML5(File.read(File.join(build_dir, file))).at('head')
      {
        file: file,
        url: head&.at('meta[property="og:url"]')&.[]('content'),
        noindex: !!head&.at('meta[name="robots"][content*="noindex"]'),
        tags: image_tags.map { |selector| head&.at(selector)&.[]('content') },
      }
    end
  end

  before do
    skip 'no build (run `bundle exec middleman build`)' unless File.file?(File.join(build_dir, 'index.html'))
  end

  it 'gives a page all of the image tags or none' do
    partial = pages.select { |page| page[:tags].compact.size.between?(1, image_tags.size - 1) }
    expect(partial.map { |page| page[:file] }).to eq([])
  end

  it 'gives every page that search engines may list an image, and no other page' do
    skip 'a build without images (SKIP_OG_IMAGES=1)' unless File.directory?(File.join(build_dir, 'og'))

    listed = File.read(File.join(build_dir, 'sitemap.xml')).scan(%r{<loc>(.*?)</loc>}).flatten
    with_image = pages.select { |page| page[:tags].first }
    expect(with_image.map { |page| page[:url] }).to match_array(listed)
    expect(pages.select { |page| page[:noindex] && page[:tags].any? }.map { |page| page[:file] }).to eq([])
  end

  it 'has the image of every page that names one, and no other' do
    names = pages.filter_map { |page| page[:tags].first }.map { |url| url[%r{/og/(\h{16}\.png)\z}, 1] }
    expect(names).to all(be_present)

    files = Dir.glob('*', base: File.join(build_dir, 'og'))
    expect(files).to match_array(names.uniq)
  end

end
