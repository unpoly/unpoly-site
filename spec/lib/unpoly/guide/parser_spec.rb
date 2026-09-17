module Unpoly
  module Guide
    describe Parser do

      subject do
        described_class.new('.')
      end

      # These come from spec/fixtures/parser, which is parsed alongside the Unpoly sources.
      describe '@learn-ref' do

        let(:repository) { Guide.current }

        it 'collects every reference in the order they were declared' do
          feature = repository.find_by_name!('test.module.functionWithLearnRefs')

          expect(feature.learn_ref_specs.map { |spec| spec[:spec] }).to eq(['test.page', 'test.page#fixture-section'])
        end

        it 'resolves a reference to a page, deriving its label' do
          feature = repository.find_by_name!('test.module.functionWithLearnRefs')
          learn_ref = feature.learn_refs.first

          expect(learn_ref.path).to eq('/test.page')
          expect(learn_ref.label).to eq('Test Page')
        end

        it 'names the heading of an anchored reference' do
          feature = repository.find_by_name!('test.module.functionWithLearnRefs')
          learn_ref = feature.learn_refs.last

          expect(learn_ref.path).to eq('/test.page#fixture-section')
          expect(learn_ref.label).to eq('Test Page › Fixture section')
        end

        it 'takes a label written below the directive' do
          feature = repository.find_by_name!('test.module.functionWithLabelledLearnRef')

          expect(feature.learn_refs.first.label).to eq('A label of our own')
        end

        it 'leaves no trace in the prose' do
          feature = repository.find_by_name!('test.module.functionWithLearnRefs')

          expect(feature.guide_markdown).not_to include('learn-ref')
        end

      end

      describe 'dynamic tokens' do

        it 'substitutes [[=version]] in doc comment prose' do
          feature = Guide.current.find_by_name!('test.module.functionWithDynamicToken')

          expect(feature.guide_markdown).to include("Built for version #{Guide.current.version}.")
        end

      end

      describe 'interface visibility' do

        it 'parses @internal on a module, removing its page and menu node' do
          interface = Guide.current.find_by_name!('up.browser')

          expect(interface).to be_internal
          expect(interface).not_to be_guide_page
        end

        it 'keeps pages for public modules' do
          interface = Guide.current.find_by_name!('up.form')

          expect(interface).to be_guide_page
        end

        it 'parents up.Layer methods from unpoly-migrate under up.Layer, not the module parsed before' do
          feature = Guide.current.find_by_name!('up.Layer.prototype.isOpen')

          expect(feature.interface.name).to eq('up.Layer')
        end

      end

      describe '#split_types_expression' do

        it 'parses a simple type' do
          expect(subject.send(:split_types_expression, 'string')).to eq(['string'])
        end

        it 'parses a parameterized collection type' do
          expect(subject.send(:split_types_expression, 'List<Element>')).to eq(['List<Element>'])
        end

        it 'parses a collection type parameterized with a union type' do
          expect(subject.send(:split_types_expression, 'List<Element|string>')).to eq(['List<Element|string>'])
        end

        it 'parses a collection type parameterized with a union type that contains a function' do
          expect(subject.send(:split_types_expression, 'Array<boolean|string|Function(Element)>')).to eq(['Array<boolean|string|Function(Element)>'])
        end

        it 'parses a collection type parameterized with a union type, in a union with other types' do
          expect(subject.send(:split_types_expression, 'List<Element|string>|number')).to eq(['List<Element|string>', 'number'])
        end

        it 'parses a namespaced type' do
          expect(subject.send(:split_types_expression, 'up.Request')).to eq(['up.Request'])
        end

        it 'parses a union of simple types' do
          expect(subject.send(:split_types_expression, 'string|number')).to eq(['string', 'number'])
        end

        it 'parses a function with parameter and return types' do
          expect(subject.send(:split_types_expression, 'Function(up.Request, up.Response): string')).to eq(['Function(up.Request, up.Response): string'])
        end

        it 'parses a function with union types for parameters and return types' do
          expect(subject.send(:split_types_expression, '(Function(string|number): boolean|null)')).to eq(['Function(string|number): boolean|null'])
        end

        # it 'allows parentheses around a return type union to distinguish from a union of the entire expression' do
        #   expect(subject.send(:split_types_expression, 'Function(string|number): (boolean|null)|number')).to eq(['Function(string|number): boolean|null', 'number'])
        # end

        it 'parses a function with union types in a union with other types' do
          expect(subject.send(:split_types_expression, '(Function(string|number): boolean|null)|string')).to eq(['Function(string|number): boolean|null', 'string'])
        end

      end

    end
  end
end
