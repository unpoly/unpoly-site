describe Unpoly::Guide do

  subject do
    Unpoly::Guide.current
  end

  describe 'parsing of doc comments' do

    describe 'API modules (e.g. up.dom)' do

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

    describe 'classes (like up.Response)' do

      it 'parses classes' do
        expect(subject.klasses).to include(have_attributes(name: 'up.Request'))
        expect(subject.klasses).to include(have_attributes(name: 'up.Response'))
      end

      it 'parses constructors, but gives it a guide ID that does not conflict with the class itself' do
        request = subject.klass_for_name('up.Request')
        constructor = request.constructor
        expect(constructor).to_not be_nil
        expect(constructor.guide_id).to_not eq(request.guide_id)
        expect(constructor.guide_id).to eq('up.Request.constructor')
      end

    end

  end

end