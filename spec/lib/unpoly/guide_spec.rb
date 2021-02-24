describe Unpoly::Guide do

  subject do
    Unpoly::Guide.current
  end

  describe 'parsing of doc comments' do

    describe 'API modules (e.g. up.fragment)' do

      it 'parses modules' do
        expect(subject.interfaces).to include(have_attributes(name: 'up.fragment'))
        expect(subject.interfaces).to include(have_attributes(name: 'up.layer'))
        expect(subject.interfaces).to include(have_attributes(name: 'up.util'))
      end

      describe 'functions' do

        it 'parses the signature' do
          function = subject.feature_for_guide_id('up.reload')
          expect(function.name).to eq('up.reload')
          expect(function.kind).to eq('function')
          expect(function.params[0].name).to eq('target')
          expect(function.params[0].types).to contain_exactly('string', 'Element', 'jQuery')
          expect(function.params[1].name).to eq('options')
          expect(function.signature).to eq('up.reload([target], [options])')
        end

        it 'parses the return value' do
          function = subject.feature_for_guide_id('up.util.every')
          expect(function.response.types).to contain_exactly('boolean')
        end

      end

      it 'parses a function default' do
        function = subject.features_for_guide_id('up.render').first
        layer_param = function.params.detect { |p| p.name == 'options.layer' }
        expect(layer_param.default).to eq("'origin current'")
      end

      describe 'visibilities' do

        it 'parses a stable visibility' do
          replace_function = subject.features_for_guide_id('up.render').first
          expect(replace_function.visibility).to eq('stable')
        end

        it 'parses an experimental visibility' do
          first_function = subject.features_for_guide_id('up.event.onEscape').first
          expect(first_function.visibility).to eq('experimental')
        end

        it 'parses a deprecated visibility' do
          ajax_function = subject.features_for_guide_id('up.ajax').first
          expect(ajax_function.visibility).to eq('deprecated')
        end

        it 'parses deprecation reasons' do
          ajax_function = subject.features_for_guide_id('up.ajax').first
          expect(ajax_function.visibility_comment).to match(/use.+?up\.request/i)
        end

        it 'returns a default visibility comment for experimental features' do
          first_function = subject.features_for_guide_id('up.event.onEscape').first
          expect(first_function.visibility_comment).to match(/feature is experimental/i)
        end

        it 'returns no default visibility comment for stable features' do
          replace_function = subject.features_for_guide_id('up.render').first
          expect(replace_function.visibility_comment).to be_nil
        end

      end

      describe 'params note' do

        it 'parses a params note' do
          submit_function = subject.feature_for_guide_id('up.submit')
          expect(submit_function.params_note).to match(/options from `up.render\(\)` may be used/i)
        end

      end

      it 'parses the text source' do
        interface = subject.interface_for_name!('up.radio')
        expect(interface.text_source.path).to end_with('lib/assets/javascripts/unpoly/radio.coffee')
        expect(interface.text_source.start_line).to eq(1)
        expect(interface.text_source.end_line).to eq(9)
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
        expect(property.signature).to eq('up.motion.config')
      end

    end

    describe 'references' do

      it 'parses a reference to another guide entry' do
        a_up_current = subject.feature_for_name!('a.up-current')
        expect(a_up_current.references?).to eq(true)
        expect(a_up_current.references.size).to eq(1)

        first_reference = a_up_current.references.first
        expect(first_reference).to be_a(Unpoly::Guide::Feature)
        expect(first_reference.name).to eq('[up-nav]')
      end

    end

    describe 'classes (like up.Response)' do

      it 'parses classes' do
        expect(subject.interfaces).to include(have_attributes(name: 'up.Request'))
        expect(subject.interfaces).to include(have_attributes(name: 'up.Response'))
      end

      it 'parses constructors, but gives it a guide ID that does not conflict with the class itself' do
        request = subject.interface_for_name!('up.Request')
        constructor = request.constructor
        expect(constructor).to_not be_nil
        expect(constructor.guide_id).to_not eq(request.guide_id)
        expect(constructor.guide_id).to eq('up.Request.new')
      end

    end

  end

end