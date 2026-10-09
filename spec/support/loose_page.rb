# Loose pages (`loose:` in toc.yml) are Learn pages in no chapter. The real manifest may
# list none, so specs take a page out of its chapter and make it loose instead.
module LoosePage
  # A page from a chapter's tail, so no chapter loses its overview.
  SLUG = 'tracking-page-views'

  def self.manifest(slug = SLUG)
    repository = Unpoly::Guide.current
    data = YAML.safe_load(File.read(File.join(repository.path, Unpoly::Guide::Toc::PATH)))
    data['learn']['topics'].each { |topic| topic['pages']&.delete(slug) }
    data['learn']['loose'] = Array(data['learn']['loose']) | [slug]
    data
  end

  def self.toc(slug = SLUG)
    Unpoly::Guide::Toc.new(manifest(slug), Unpoly::Guide.current)
  end

  # For feature specs: the site renders with the page made loose.
  def make_page_loose(slug = SLUG)
    toc = LoosePage.toc(slug)
    allow(Unpoly::Guide.current).to receive(:toc).and_return(toc)
    toc
  end
end

RSpec.configure do |config|
  config.include LoosePage
end
