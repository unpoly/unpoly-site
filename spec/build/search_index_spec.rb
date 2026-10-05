require 'zlib'
require 'json'

# A smoke test against the REAL search index of the last build, because the feature
# specs stub Pagefind and cannot see what the indexer actually stores. It reads the
# index fragments in build/pagefind and checks what the search dialog relies on.
#
# Runs only where a build exists (`bundle exec rake search:index`, or any
# `middleman build`); without one it is skipped, as in CI.
describe 'the built search index' do

  BUILD_INDEX = File.expand_path('../../build/pagefind', __dir__)

  # Parsed once for all examples.
  BUILD_FRAGMENTS = []

  before do
    skip 'no build/pagefind (run `bundle exec rake search:index`)' unless File.directory?(BUILD_INDEX)
  end

  # Every indexed page's fragment: { 'url' => ..., 'meta' => { 'title' => ..., ... } }.
  # A fragment is gzipped JSON behind a short "pagefind_dcd" signature.
  def fragments
    return BUILD_FRAGMENTS if BUILD_FRAGMENTS.any?

    BUILD_FRAGMENTS.concat(Dir[File.join(BUILD_INDEX, 'fragment', '*.pf_fragment')].map do |file|
      data = Zlib::GzipReader.open(file, &:read)
      JSON.parse(data[data.index('{')..])
    end)
  end

  def meta_of(path)
    fragment = fragments.detect { |candidate| candidate['url'].chomp('/') == path }
    expect(fragment).not_to be_nil, "no fragment for #{path}"
    fragment['meta']
  end

  it 'titles a module page with the module name and badges it API' do
    expect(meta_of('/up.link')).to include('title' => 'up.link', 'badge' => 'API')
  end

  it 'titles a class page with the class name' do
    expect(meta_of('/up.Layer')).to include('title' => 'up.Layer', 'badge' => 'API')
  end

  it 'titles a feature page with its signature and badges it with its kind' do
    expect(meta_of('/up.render')).to include('title' => 'up.render([target], [options])', 'badge' => 'JS')
  end

  it 'badges a guide page Learn' do
    expect(meta_of('/targeting-fragments')['badge']).to eq('Learn')
  end

  it 'marks a deprecated page, and only that' do
    deprecated = Unpoly::Guide.current.features.detect { |feature| feature.guide_page? && feature.deprecated? }

    expect(meta_of(deprecated.guide_path)['deprecated']).to eq('true')
    expect(meta_of('/up.render')).not_to have_key('deprecated')
  end

  it 'never stores more than one value in a meta key' do
    mangled = fragments.select { |fragment| fragment['meta'].values.any? { |value| value.to_s.include?(', title:') } }
    expect(mangled.map { |fragment| fragment['url'] }).to eq([])
  end

end
