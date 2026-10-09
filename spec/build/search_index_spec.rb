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

  def fragment_of(path)
    fragment = fragments.detect { |candidate| candidate['url'].chomp('/') == path }
    expect(fragment).not_to be_nil, "no fragment for #{path}"
    fragment
  end

  def meta_of(path)
    fragment_of(path)['meta']
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

  it 'puts a signature page in the tier, with its title a second time' do
    expect(meta_of('/up-layer-new')).to include('tier' => 'signature', 'tier_title' => '[up-layer=new]')
    expect(meta_of('/caching')).to include('tier' => 'signature', 'tier_title' => 'Caching')
  end

  it 'leaves an unmarked page out of the tier' do
    expect(meta_of('/up.layer.get').keys).not_to include('tier', 'tier_title')
  end

  # Filters, not metadata: Pagefind searches metadata, and a hub's name must not make a
  # page match or rank (config.rb, search_meta_tags).
  it 'names the hub of a guide page, a feature and a module, and stores it as a filter' do
    expect(fragment_of('/start/links')['filters']).to include('hub' => ['Getting started'])
    expect(fragment_of('/following-links')['filters']).to include('hub' => ['Links'])
    expect(fragment_of('/up.follow')['filters']).to include('hub' => ['up.link'])
    expect(fragment_of('/up-follow')['filters']).to include('hub' => ['up.link'])
    expect(fragment_of('/up.link')['filters']).to include('hub' => ['API'])
    expect(meta_of('/following-links')).not_to have_key('hub')
  end

  it 'flags a chapter overview instead of naming its hub, and keeps its title as it is' do
    expect(fragment_of('/links')['filters']).to include('overview' => ['true'])
    expect(fragment_of('/links')['filters']).not_to have_key('hub')
    expect(meta_of('/links')['title']).to eq('Links')
    expect(fragment_of('/following-links')['filters']).not_to have_key('overview')
  end

  it 'leaves the "Read more" buttons of a chapter overview out of the text' do
    expect(fragment_of('/links')['content']).not_to include('Read more')
    expect(fragments.map { |fragment| fragment['content'] }.grep(/Read more:/)).to eq([])
  end

  it 'keeps the parser fixtures out of the index' do
    expect(fragments.map { |fragment| fragment['url'] }.grep(%r{\A/test\.})).to eq([])
  end

  # Pagefind takes one key per data-pagefind-meta attribute. Two keys written into one
  # attribute end up as one mashed value ("API, title:up.link"), which must never happen.
  it 'never stores more than one value in a meta key' do
    keys = fragments.flat_map { |fragment| fragment['meta'].keys }.uniq
    mangled = fragments.select do |fragment|
      fragment['meta'].values.any? { |value| keys.any? { |key| value.to_s.match?(/,\s*#{Regexp.escape(key)}:/) } }
    end
    expect(mangled.map { |fragment| fragment['url'] }).to eq([])
  end

end
