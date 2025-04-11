module Unpoly
  module Guide
    describe Parser do

      subject do
        described_class.new('.')
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
