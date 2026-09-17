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

    describe '#essential_features' do

      it 'returns the referenced features that are promoted on the interface page' do
        expect(interface.essential_features).to be_present
        expect(interface.essential_features.map(&:name)).to include('up.render')
      end

      it 'returns no pages, which the learn-refs point to instead' do
        expect(interface.essential_features.select(&:page?)).to be_empty
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

end
