describe Unpoly::Guide do

  subject do
    Unpoly::Guide.current
  end

  describe 'parsing of doc comments' do

    def find(name)
      subject.find_by_name!(name)
    end

    describe 'modules (e.g. up.fragment)' do

      it 'parses a module' do
        interface = find('test.module')
        expect(interface.kind).to eq('module')
      end

      it 'parses the module title from its Markdown' do
        interface = find('test.module')
        expect(interface.title).to eq('Test module')
      end

      describe 'functions' do

        it 'associates them with the last declared module' do
          interface = find('test.module')
          function = find('test.module.function')
          expect(interface.functions).to include(function)
        end

        it 'parses the signature' do
          function = find('test.module.function')
          expect(function.name).to eq('test.module.function')
          expect(function.kind).to eq('function')
          expect(function.params[0].name).to eq('target')
          expect(function.params[0].types).to contain_exactly('string', 'Element')
          expect(function.params[0]).not_to be_optional
          expect(function.params[1].name).to eq('options')
          expect(function.params[1].types).to contain_exactly('Object')
          expect(function.params[1]).to be_optional
          expect(function.signature).to eq('test.module.function(target, [options])')
        end

        it 'parses the return value' do
          function = find('test.module.function')
          expect(function.response.types).to contain_exactly('boolean')
        end

        it 'parses a default argument' do
          function = find('test.module.functionWithDefault')
          expect(function.params.first).to be_optional
          expect(function.params.first.default).to eq("'default value'")
        end

        it 'parses an @essential tag' do
          essential_function = find('test.module.essentialFunction')
          nonessential_function = find('test.module.nonessentialFunction')

          expect(essential_function).to be_essential
          expect(nonessential_function).to_not be_essential
        end

      end

      describe 'selectors' do

        it 'parses a selector' do
          selector = find('[test-module-selector]')
          expect(selector.name).to eq('[test-module-selector]')
          expect(selector.kind).to eq('selector')
          expect(selector.signature).to eq('[test-module-selector]')
        end

      end

      describe 'properties' do

        it 'parses a property' do
          property = find('test.module.property')
          expect(property.name).to eq('test.module.property')
          expect(property.kind).to eq('property')
          expect(property.signature).to eq('test.module.property')
          expect(property.params[0].name).to eq('value')
        end

        it 'parses a property with a structured object value' do
          property = find('test.module.objectProperty')
          expect(property.name).to eq('test.module.objectProperty')
          expect(property.kind).to eq('property')
          expect(property.signature).to eq('test.module.objectProperty')
          expect(property.params.size).to eq(2)
          expect(property.params[0].name).to eq('objectProperty.key1')
          expect(property.params[0].types).to contain_exactly('string')
          expect(property.params[0].guide_anchor).to eq('objectProperty.key1')
          expect(property.params[1].name).to eq('objectProperty.key2')
          expect(property.params[1].types).to contain_exactly('number')
          expect(property.params[1].guide_anchor).to eq('objectProperty.key2')
        end

        it 'parses a property with an array default value' do
          property = find('test.module.propertyWithArrayDefault')
          expect(property.params[0].name).to eq('propertyWithArrayDefault')
          expect(property.params[0].types).to contain_exactly('Array<string>')
          expect(property.params[0].default).to eq("['foo', 'bar']")
        end

      end

      describe 'visibilities' do

        it 'parses a stable visibility' do
          function = find('test.module.stableFunction')
          expect(function.visibility).to eq('stable')
        end

        it 'parses an experimental visibility' do
          function = find('test.module.experimentalFunction')
          expect(function.visibility).to eq('experimental')
        end

        it 'parses a deprecated visibility' do
          function = find('test.module.deprecatedFunction')
          expect(function.visibility).to eq('deprecated')
        end

        it 'parses deprecation reasons' do
          function = find('test.module.deprecatedFunction')
          expect(function.visibility_comment).to match(/use something else/i)
        end

        it 'returns a default visibility comment for experimental features' do
          function = find('test.module.experimentalFunction')
          expect(function.visibility_comment).to match(/feature is experimental/i)
        end

        it 'returns no default visibility comment for stable features' do
          function = find('test.module.stableFunction')
          expect(function.visibility_comment).to be_nil
        end

      end

      describe 'params note' do

        it 'parses a params note' do
          function = find('test.module.functionWithParamsNote')
          expect(function.params_note).to match(/all options from other function may be used/i)
        end

      end

      it 'remembers the file and line range from which a module was loaded' do
        interface = find('test.module')
        expect(interface.text_source.path).to end_with('spec/fixtures/parser/module.coffee')
        expect(interface.text_source.start_line).to eq(1)
        expect(interface.text_source.end_line).to eq(6)
      end

    end

    describe 'references' do

      it 'parses a reference to another guide entry' do
        function = find('test.module.referencingFunction')
        expect(function.references?).to eq(true)
        expect(function.references.size).to eq(1)

        first_reference = function.references.first
        expect(first_reference).to be_a(Unpoly::Guide::Feature)
        expect(first_reference.name).to eq('test.module.function')
      end

    end

    describe 'classes (like up.Response)' do

      it 'parses classes' do
        interface = find('test.Class')
        expect(interface.kind).to eq('class')
      end

      it 'parses constructors, but gives it a guide ID that does not conflict with the class itself' do
        klass = find('test.Class')
        constructor = klass.constructor
        expect(constructor).to_not be_nil
        expect(constructor.guide_id).to_not eq(klass.guide_id)
        expect(constructor.guide_id).to eq('test.Class.new')
        expect(constructor.params[0].types).to contain_exactly('string')
      end

    end

    describe 'pages' do

      it 'parses a content page' do
        interface = find('test.page')
        expect(interface.title).to eq('Test Page')
      end

    end

  end

end