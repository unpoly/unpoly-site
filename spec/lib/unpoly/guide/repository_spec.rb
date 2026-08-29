describe Unpoly::Guide::Repository do

  subject do
    Unpoly::Guide.current
  end

  describe 'lookup by name' do

    it 'finds a documentable by its name' do
      expect(subject.find_by_name('up.render').name).to eq('up.render')
    end

    it 'returns nil for an unknown name' do
      expect(subject.find_by_name('up.doesNotExist')).to be_nil
    end

    it 'raises for an unknown name when the caller expects a match' do
      expect { subject.find_by_name!('up.doesNotExist') }.to raise_error(Unpoly::Guide::Unknown, /up\.doesNotExist/)
    end

    it 'answers whether a name exists' do
      expect(subject.name_exists?('up.render')).to be(true)
      expect(subject.name_exists?('up.doesNotExist')).to be(false)
    end

  end

  describe 'lookup by guide ID' do

    it 'finds a documentable by the ID that is also used for its page' do
      feature = subject.find_by_name!('[up-follow]')

      expect(subject.find_by_guide_id!(feature.guide_id)).to eq(feature)
    end

    it 'raises for an unknown guide ID' do
      expect { subject.find_by_guide_id!('does-not-exist') }.to raise_error(Unpoly::Guide::Unknown)
    end

    it 'answers whether a guide ID exists' do
      expect(subject.guide_id_exists?('up.render')).to be(true)
      expect(subject.guide_id_exists?('does-not-exist')).to be(false)
    end

  end

  describe '#promoted_interfaces' do

    it 'returns the interfaces that make up the top level of the menu' do
      names = subject.promoted_interfaces.map(&:name)

      expect(names).to eq(described_class::PROMOTED_INTERFACE_NAMES)
    end

    it 'returns interfaces, not features' do
      expect(subject.promoted_interfaces).to all(be_a(Unpoly::Guide::Interface))
    end

  end

  describe 'versions' do

    it 'reads the version from the package.json of the Unpoly repository' do
      expect(subject.version).to match(/^\d+\.\d+\.\d+/)
    end

    it 'strips a pre-release suffix for the stable version' do
      expect(subject.stable_version).to eq(subject.version.sub(/-.+$/, ''))
    end

    it 'shortens the version to its feature version' do
      expect(subject.short_version).to eq(subject.version.scan(/^\d+\.\d+/).first)
    end

    it 'builds the git tag for the current version' do
      expect(subject.git_version_tag).to eq("v#{subject.version}")
    end

  end

  describe '#documentables' do

    it 'includes both interfaces and features' do
      expect(subject.documentables).to include(subject.find_by_name!('up.fragment'))
      expect(subject.documentables).to include(subject.find_by_name!('up.render'))
    end

    it 'gives every documentable a unique guide ID, so no page overwrites another' do
      guide_ids = subject.documentables.select(&:guide_page?).map(&:guide_id)

      expect(guide_ids.uniq).to eq(guide_ids)
    end

  end

end
