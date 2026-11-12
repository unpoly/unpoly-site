module Unpoly
  module Site
    describe Parser do

      subject do
        described_class.new('.')
      end

      # These come from spec/fixtures/parser, which is parsed alongside the Unpoly sources.
      describe '@learn-ref' do

        let(:repository) { Site.current }

        it 'collects every reference in the order they were declared' do
          feature = repository.find_by_name!('test.module.functionWithLearnRefs')

          expect(feature.learn_ref_specs.map { |spec| spec[:spec] }).to eq(['test.page', 'test.page#fixture-section'])
        end

        it 'resolves a reference to a page, deriving its label' do
          feature = repository.find_by_name!('test.module.functionWithLearnRefs')
          learn_ref = feature.learn_refs.first

          expect(learn_ref.path).to eq('/learn/test.page')
          expect(learn_ref.label).to eq('Test Page')
        end

        it 'leads an anchored reference to its heading, labelled with the page title' do
          feature = repository.find_by_name!('test.module.functionWithLearnRefs')
          learn_ref = feature.learn_refs.last

          expect(learn_ref.path).to eq('/learn/test.page#fixture-section')
          expect(learn_ref.label).to eq('Test Page')
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

      describe '@signature' do

        it 'puts a feature in the signature tier' do
          feature = Site.current.find_by_name!('test.module.signatureFunction')

          expect(feature).to be_signature_tier
          expect(feature.guide_markdown).not_to include('@signature')
        end

        it 'puts a page in the signature tier' do
          page = Site.current.find_by_name!('test.signature-page')

          expect(page).to be_signature_tier
          expect(page.guide_markdown).not_to include('@signature')
        end

        it 'leaves an unmarked feature or page in the default tier' do
          expect(Site.current.find_by_name!('test.module.stableFunction')).not_to be_signature_tier
          expect(Site.current.find_by_name!('test.page')).not_to be_signature_tier
        end

      end

      describe '@keywords' do

        it 'gives a page its keywords and removes the directive from the prose' do
          page = Site.current.find_by_name!('test.signature-page')

          expect(page.keywords).to eq(['modal', 'dialog box'])
          expect(page.guide_markdown).not_to include('@keywords')
        end

        it 'gives a feature its keywords and removes the directive from the prose' do
          feature = Site.current.find_by_name!('test.module.signatureFunction')

          expect(feature.keywords).to eq(['spinner'])
          expect(feature.guide_markdown).not_to include('@keywords')
        end

        it 'leaves a page without the directive without keywords' do
          expect(Site.current.find_by_name!('test.page').keywords).to eq([])
        end

      end

      describe 'dynamic tokens' do

        it 'substitutes [[=version]] in doc comment prose' do
          feature = Site.current.find_by_name!('test.module.functionWithDynamicToken')

          expect(feature.guide_markdown).to include("Built for version #{Site.current.version}.")
        end

      end

      describe 'interface visibility' do

        it 'parses @internal on a namespace, removing its page and menu node' do
          interface = Site.current.find_by_name!('up.browser')

          expect(interface).to be_internal
          expect(interface).not_to be_guide_page
        end

        it 'keeps pages for public namespaces' do
          interface = Site.current.find_by_name!('up.form')

          expect(interface).to be_guide_page
        end

        it 'parents up.Layer methods from unpoly-migrate under up.Layer, not the namespace parsed before' do
          feature = Site.current.find_by_name!('up.Layer.prototype.isOpen')

          expect(feature.interface.name).to eq('up.Layer')
        end

      end

      describe 'a title' do

        it 'fails the parse on a namespace, which is titled by its name' do
          Dir.mktmpdir do |dir|
            path = File.join(dir, 'titled.js')
            File.write(path, "/*-\nTitled namespace\n=============\n\n@namespace test.titled\n*/\n")

            expect { subject.parse_all(dir => [path]) }.to raise_error(Parser::CannotParse, /Only a @page takes a title/)
          end
        end

      end

      describe 'a doc file beside a source file' do

        # From spec/fixtures/parser/sibling.md
        it 'parses its entries like doc comments' do
          function = Site.current.find_by_name!('test.sibling.function')

          expect(function.interface.name).to eq('test.sibling')
          expect(function.params.map(&:name)).to eq(['target'])
          expect(function.params.first.types).to eq(['string'])
          expect(function.response.types).to eq(['boolean'])
          expect(function).to be_stable
          expect(function.guide_markdown).to start_with('A function documented in a doc file.')
          expect(function.guide_markdown).not_to include('# test.sibling.function()')
          expect(function.guide_markdown).to include("Setext heading\n--------------")
        end

        it "remembers the file and the entry's line range, from its H1 to its last line" do
          function = Site.current.find_by_name!('test.sibling.function')

          expect(function.text_source.path).to end_with('spec/fixtures/parser/sibling.md')
          expect(function.text_source.start_line).to eq(9)
          expect(function.text_source.end_line).to eq(38)
        end

        it 'accepts the title of an instance method in the menu (up.Class#method())' do
          expect(Site.current.find_by_name!('test.sibling.Thing.prototype.method')).to be_present
        end

        it "fails the parse when an entry's H1 does not match its title" do
          repository = double('repository')
          allow(repository).to receive(:merge_interface) { |interface| interface }
          parser = described_class.new(repository)

          Dir.mktmpdir do |dir|
            path = File.join(dir, 'mismatch.md')
            File.write(path, "# test.mismatch\n\n@namespace test.mismatch\n\n-----\n\n# test.mismatch.other()\n\n@function test.mismatch.function\n@stable\n")

            expect { parser.parse_all(dir => [path]) }.to raise_error(
              Parser::CannotParse,
              /H1 '# test.mismatch.other\(\)' does not match .* expected '# test.mismatch.function\(\)': .*mismatch\.md:7:10/
            )
          end
        end

      end

      describe '@return' do

        it 'strips the prose of every response, not only of the last one parsed' do
          interfaces = []
          repository = double('repository')
          allow(repository).to receive(:merge_interface) { |interface| interfaces << interface; interface }
          parser = described_class.new(repository)

          Dir.mktmpdir do |dir|
            path = File.join(dir, 'returns.js')
            File.write(path, <<~JS)
              /*-
              @namespace test.returns
              */

              /*-
              @function test.returns.one
              @return {boolean}
                The first response.

              @stable
              */

              /*-
              @function test.returns.two
              @return {boolean}
                The second response.

              @stable
              */
            JS
            parser.parse_all(dir => [path])
          end

          proses = interfaces.first.features.map { |feature| feature.response.guide_markdown }
          expect(proses).to eq(["The first response.\n", "The second response.\n"])
        end

      end

      describe '@see' do

        it 'is retired and fails the parse' do
          Dir.mktmpdir do |dir|
            path = File.join(dir, 'retired.js')
            File.write(path, "/*-\n@function test.retired\n@see test.module.function\n@stable\n*/\n")

            expect { subject.parse_all(dir => [path]) }.to raise_error(Parser::CannotParse, /Retired directive @see/)
          end
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
