describe Unpoly::Guide::Interface do

  subject do
    Unpoly::Guide.current
  end

  # The menu and the interface pages are built from these collections.
  describe 'a module (e.g. up.fragment)' do

    let(:interface) { subject.find_by_name!('up.fragment') }

    it 'has a title from its Markdown, but is named after its symbol in the menu' do
      expect(interface.title).to be_present
      expect(interface.menu_title).to eq('up.fragment')
    end

    describe '#guide_features' do

      it 'returns the features that have a page of their own' do
        expect(interface.guide_features).to be_present
        expect(interface.guide_features).to all(be_guide_page)
      end

      it 'omits internal features' do
        expect(interface.guide_features.select(&:internal?)).to be_empty
      end

      it 'groups features by their kind' do
        expect(interface.functions).to all(be_function)
        expect(interface.properties).to all(be_property)
        expect(interface.selectors).to all(be_selector)
        expect(interface.events).to all(be_event)
      end

    end

    describe '#learn_refs' do

      it 'points at the Learn pages that explain the module' do
        expect(interface.learn_refs).to be_present
        expect(interface.learn_refs.map(&:path)).to all(start_with('/'))
      end

    end

  end

  describe 'a class (e.g. up.Response)' do

    let(:interface) { subject.find_by_name!('up.Response') }

    it 'is a class, not a module' do
      expect(interface).to be_class
      expect(interface).not_to be_module
    end

    it 'lists its instance methods and properties as features' do
      expect(interface.features).to be_present
      expect(interface.features.map(&:interface)).to all(eq(interface))
    end

  end

  describe '#merge!' do

    it 'keeps the signature tier of a repeated declaration' do
      interface = described_class.new('module', 'test.merged')
      repeated = described_class.new('module', 'test.merged')
      repeated.signature_tier = true

      interface.merge!(repeated)

      expect(interface).to be_signature_tier
    end

  end

end
