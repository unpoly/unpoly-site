describe Unpoly::Guide do

  subject do
    Unpoly::Guide.current
  end

  describe 'parsing of doc comments' do

    delegate :find_by_name!, :find_by_guide_id!, to: :subject

    describe 'modules (e.g. up.fragment)' do

      it 'parses a module' do
        interface = find_by_name!('test.module')
        expect(interface.kind).to eq('module')
      end

      it 'parses the module title from its Markdown' do
        interface = find_by_name!('test.module')
        expect(interface.title).to eq('Test module')
      end

      describe 'functions' do

        it 'associates them with the last declared module' do
          interface = find_by_name!('test.module')
          function = find_by_name!('test.module.function')
          expect(interface.functions).to include(function)
        end

        it 'parses the signature' do
          function = find_by_name!('test.module.function')
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
          function = find_by_name!('test.module.function')
          expect(function.response.types).to contain_exactly('boolean')
        end

        it 'parses a default argument' do
          function = find_by_name!('test.module.functionWithDefault')
          expect(function.params.first).to be_optional
          expect(function.params.first.default).to eq("'default value'")
        end

        it 'does not parse curly braces in the description as types' do
          function = find_by_name!('test.module.noTypeButCurlyBracesInDescription')
          expect(function.params.first.name).to eq('foo')
          expect(function.params.first.types).to be_blank
          expect(function.params.first.guide_markdown.chomp).to eq("Curly { braces } in the description are not parsed as types")
          expect(function.response.types).to be_blank
          expect(function.response.guide_markdown.chomp).to eq("Curly { braces } in the description are not parsed as types")
        end

        it 'parses params with a different visibility than the feature' do
          function = find_by_name!('test.module.paramVisibilities')
          expect(function.visibility).to eq('experimental')
          expect(function.params[0].name).to eq('options.foo')
          expect(function.params[0].visibility).to eq('internal')
          expect(function.params[1].name).to eq('options.bar')
          expect(function.params[1].visibility).to eq('experimental')
          expect(function.params[2].name).to eq('options.baz')
          expect(function.params[2].visibility).to eq('internal')
        end

        it 'includes partials in the markdown' do
          function = find_by_name!('test.module.featureIncludingPartial')
          expect(function.guide_markdown).to eq(<<~EOT)
            Line before partial
            Partial line 1
            Partial line 2
            Line after partial
          EOT
        end

        it 'parses param sections' do
          function = find_by_name!('test.module.paramSections')
          expect(function.params[0].name).to eq('options.foo')
          expect(function.params[0].section_title).to eq('First section')
          expect(function.params[1].name).to eq('options.bar')
          expect(function.params[1].section_title).to eq('First section')
          expect(function.params[2].name).to eq('options.baz')
          expect(function.params[2].section_title).to eq('Second section')

          expect(function.param_sections.size).to eq(2)
          expect(function.param_sections[0].title).to eq('First section')
          expect(function.param_sections[0].params).to eq [function.params[0], function.params[1]]
          expect(function.param_sections[1].title).to eq('Second section')
          expect(function.param_sections[1].params).to eq [function.params[2]]
        end

        it 'includes a partial with params' do
          function = find_by_name!('test.module.featureIncludingStructuralPartial')
          expect(function.params[0].name).to eq('fooFromPartial')
          expect(function.params[1].name).to eq('barFromPartial')
        end

        it 'mixes params from a partial, overriding selected params' do
          function = find_by_name!('test.module.featureMixingPartial')
          expect(function.params[0].name).to eq('fooFromPartial')
          expect(function.params[0].guide_markdown.strip).to eq('Foo description from partial')
          expect(function.params[1].name).to eq('barFromPartial')
          expect(function.params[1].guide_markdown.strip).to eq('Foo description override')
        end

        it 'mixes params from a partial within a @section' do
          function = find_by_name!('test.module.featureMixingPartialInSection')
          expect(function.params[0].name).to eq('fooFromPartial')
          expect(function.params[0].guide_markdown.strip).to eq('Foo description from partial')
          expect(function.params[1].name).to eq('barFromPartial')
          expect(function.params[1].guide_markdown.strip).to eq('Foo description override')
        end

      end

      describe 'selectors' do

        it 'parses a selector' do
          selector = find_by_name!('[test-module-selector]')
          expect(selector.name).to eq('[test-module-selector]')
          expect(selector.kind).to eq('selector')
          expect(selector.signature).to eq('[test-module-selector]')
        end

      end

      describe 'properties' do

        it 'parses a property' do
          property = find_by_name!('test.module.property')
          expect(property.name).to eq('test.module.property')
          expect(property.kind).to eq('property')
          expect(property.signature).to eq('test.module.property')
          expect(property.params[0].name).to eq('value')
        end

        it 'parses a property with a structured object value' do
          property = find_by_name!('test.module.objectProperty')
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
          property = find_by_name!('test.module.propertyWithArrayDefault')
          expect(property.params[0].name).to eq('propertyWithArrayDefault')
          expect(property.params[0].types).to contain_exactly('Array<string>')
          expect(property.params[0].default).to eq("['foo', 'bar']")
        end

      end

      describe 'visibilities' do

        it 'parses a stable visibility' do
          function = find_by_name!('test.module.stableFunction')
          expect(function.visibility).to eq('stable')
        end

        it 'parses an experimental visibility' do
          function = find_by_name!('test.module.experimentalFunction')
          expect(function.visibility).to eq('experimental')
        end

        it 'parses a deprecated visibility' do
          function = find_by_name!('test.module.deprecatedFunction')
          expect(function.visibility).to eq('deprecated')
        end

        it 'parses deprecation reasons' do
          function = find_by_name!('test.module.deprecatedFunction')
          expect(function.visibility_comment).to match(/use something else/i)
        end

        it 'returns a default visibility comment for experimental features' do
          function = find_by_name!('test.module.experimentalFunction')
          expect(function.visibility_comment).to match(/feature is experimental/i)
        end

        it 'returns no default visibility comment for stable features' do
          function = find_by_name!('test.module.stableFunction')
          expect(function.visibility_comment).to be_nil
        end

      end

      describe 'params note' do

        it 'parses a params note' do
          function = find_by_name!('test.module.functionWithParamsNote')
          expect(function.params_note).to match(/all options from other function may be used/i)
        end

      end

      it 'remembers the file and line range from which a module was loaded' do
        interface = find_by_name!('test.module')
        expect(interface.text_source.path).to end_with('spec/fixtures/parser/module.coffee')
        expect(interface.text_source.start_line).to eq(1)
        expect(interface.text_source.end_line).to eq(6)
      end

    end

    describe 'references' do

      it 'parses a reference to another guide entry' do
        function = find_by_name!('test.module.referencingFunction')
        expect(function.references?).to eq(true)
        expect(function.references.size).to eq(1)

        first_reference = function.references.first
        expect(first_reference).to be_a(Unpoly::Guide::Feature)
        expect(first_reference.name).to eq('test.module.function')
      end

    end

    describe 'explicit parent' do

      it 'parses a @parent reference and adds the documentable to the children of another' do
        klass = find_by_guide_id!('test.Class')
        expect(klass.explicit_parent_name).to eq('test.module')

        parent = find_by_guide_id!('test.module')
        expect(parent.children).to include(klass)
      end

    end

    describe 'classes (like up.Response)' do

      it 'parses classes' do
        interface = find_by_guide_id!('test.Class')
        expect(interface.kind).to eq('class')
      end

      it 'parses constructors, but gives it a guide ID that does not conflict with the class itself' do
        klass = find_by_guide_id!('test.Class')
        constructor = klass.constructor
        expect(constructor).to_not be_nil
        expect(constructor.guide_id).to_not eq(klass.guide_id)
        expect(constructor.guide_id).to eq('test.Class.new')
        expect(constructor.params[0].types).to contain_exactly('string')
      end

    end

    describe 'pages' do

      it 'parses a content page' do
        interface = find_by_name!('test.page')
        expect(interface.title).to eq('Test Page')
      end

    end

  end

  describe '#code_to_location' do

    it 'matches a selector feature' do
      location = subject.code_to_location('[up-poll]')
      expect(location).to be_present
      expect(location[:full_path]).to eq('/up-poll')
    end

    it 'matches a pseudo-selector' do
      location = subject.code_to_location(':main')
      expect(location).to be_present
      expect(location[:full_path]).to eq('/main')
    end

    it 'does not match `main` (without colon) to `:main`' do
      location = subject.code_to_location('main')
      expect(location).to be_nil
    end

    it 'matches a function feature with parentheses' do
      location = subject.code_to_location('up.render()')
      expect(location).to be_present
      expect(location[:full_path]).to eq('/up.render')
    end

    it 'matches a function feature with parentheses and an argument' do
      location = subject.code_to_location('up.render(target)')
      expect(location).to be_present
      expect(location[:full_path]).to eq('/up.render')
    end

    it 'matches a config property' do
      location = subject.code_to_location('up.fragment.config.mainTargets')
      expect(location).to be_present
      expect(location[:full_path]).to eq('/up.fragment.config#config.mainTargets')
    end

    it 'matches a class' do
      location = subject.code_to_location('List')
      expect(location).to be_present
      expect(location[:full_path]).to eq('/List')
    end

  end

end
