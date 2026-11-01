describe Unpoly::Site::Trail do

  let(:repository) { Unpoly::Site.current }

  def trail_of(guide_id)
    described_class.of(documentable: repository.find_by_guide_id!(guide_id))
  end

  it "leads from a feature through the API to the feature's namespace" do
    expect(trail_of('up-submit')).to eq([['API', '/api'], ['up.form', '/api/up.form']])
  end

  it "leads from a class's method or property to its class" do
    expect(trail_of('up.Layer.prototype.accept')).to eq([['API', '/api'], ['up.Layer', '/api/up.Layer']])
  end

  it 'leads from a namespace or class to the API' do
    expect(trail_of('up.form')).to eq([['API', '/api']])
    expect(trail_of('List')).to eq([['API', '/api']])
  end

  it 'leads from a class with an explicit parent namespace to that namespace' do
    expect(trail_of('up.Layer')).to eq([['API', '/api'], ['up.layer', '/api/up.layer']])
    expect(trail_of('up.RenderJob')).to eq([['API', '/api'], ['up.fragment', '/api/up.fragment']])
  end

  it "leads from a Learn page to its chapter, named by its title and linking its first page" do
    expect(trail_of('feedback-classes')).to eq([['Learn', '/learn'], ['Loading state', '/learn/loading-state']])
    expect(trail_of('start/links')).to eq([['Learn', '/learn'], ['Getting started', '/learn/start/overview']])
  end

  it "leads from a chapter's first page straight to its area" do
    expect(trail_of('loading-state')).to eq([['Learn', '/learn']])
    expect(trail_of('start/overview')).to eq([['Learn', '/learn']])
  end

  it 'leads from a guide page in the API area to its page group, and from the generated index to the API' do
    expect(trail_of('url-patterns')).to eq([['API', '/api'], ['Formats', '/api/formats']])
    expect(described_class.of(topic_index: ['api', 'formats'])).to eq([['API', '/api']])
  end

  it 'leads from a release and the upgrading page to the changes' do
    expect(described_class.of(release: '3.0.0')).to eq([['Changes', '/changes']])
    expect(described_class.of(page: :upgrading)).to eq([['Changes', '/changes']])
  end

  it 'is empty on the hubs' do
    %i[learn api changes support].each do |hub|
      expect(described_class.of(page: hub)).to eq([])
    end
  end

end
