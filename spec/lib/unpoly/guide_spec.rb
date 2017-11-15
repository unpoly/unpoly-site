describe Unpoly::Guide do

  subject do
    Unpoly::Guide.current
  end

  describe 'parsing of doc comments' do

    it 'parses modules' do
      expect(subject.klasses).to include(have_attributes(name: 'up.dom'))
      expect(subject.klasses).to include(have_attributes(name: 'up.modal'))
      expect(subject.klasses).to include(have_attributes(name: 'up.util'))
    end

    it 'parses functions' do
      function = subject.features_for_guide_id('up.replace').first
      expect(function.name).to eq('up.replace')
      expect(function.kind).to eq('function')
      expect(function.params[0].name).to eq('selectorOrElement')
      expect(function.params[0].types).to contain_exactly('string', 'Element', 'jQuery')
      expect(function.params[1].name).to eq('url')
      expect(function.params[1].types).to contain_exactly('string')
      expect(function.signature).to eq('up.replace(selectorOrElement, url, [options])')

      transition_param = function.params.detect { |p| p.name == 'options.transition' }
      expect(transition_param.types).to contain_exactly('string')
      expect(transition_param.default).to eq("'none'")
    end

    it 'parses selectors' do
      selector = subject.features_for_guide_id('a-up-target').first
      expect(selector.name).to eq('a[up-target]')
      expect(selector.kind).to eq('selector')
      expect(selector.signature).to eq('a[up-target]')
    end

    it 'parses properties' do
      property = subject.features_for_guide_id('up.motion.config').first
      expect(property.name).to eq('up.motion.config')
      expect(property.kind).to eq('property')
      expect(property.signature).to eq('up.motion.config = config')
    end

  end

end