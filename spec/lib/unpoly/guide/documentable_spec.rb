describe Unpoly::Guide::Documentable do

  subject do
    Unpoly::Guide.current
  end

  delegate :find_by_name!, to: :subject

  # Every link on the site is built from #guide_path. When these change silently,
  # the site keeps building, but its links (and inbound links from the web) break.
  describe '#guide_path' do

    it 'builds the path of a function from its name' do
      expect(find_by_name!('up.render').guide_path).to eq('/up.render')
    end

    it 'builds the path of a module from its name' do
      expect(find_by_name!('up.fragment').guide_path).to eq('/up.fragment')
    end

    it 'builds the path of a class from its name' do
      expect(find_by_name!('up.Response').guide_path).to eq('/up.Response')
    end

    it 'builds the path of a property from its name' do
      expect(find_by_name!('up.fragment.config').guide_path).to eq('/up.fragment.config')
    end

    it 'builds the path of a selector by stripping its brackets' do
      expect(find_by_name!('[up-follow]').guide_path).to eq('/up-follow')
    end

    it 'builds the path of an event from its name' do
      expect(find_by_name!('up:form:submit').guide_path).to eq('/up:form:submit')
    end

    it 'appends a given hash' do
      expect(find_by_name!('up.render').guide_path(hash: 'options')).to eq('/up.render#options')
    end

  end

  describe '#guide_url' do

    it 'is the absolute URL for the guide path' do
      expect(find_by_name!('up.render').guide_url).to eq('https://unpoly.com/up.render')
    end

  end

  describe '#kind' do

    it 'knows the kind of each documentable' do
      expect(find_by_name!('up.render').kind).to eq('function')
      expect(find_by_name!('up.fragment').kind).to eq('module')
      expect(find_by_name!('up.Response').kind).to eq('class')
      expect(find_by_name!('up.fragment.config').kind).to eq('property')
      expect(find_by_name!('[up-follow]').kind).to eq('selector')
      expect(find_by_name!('up:form:submit').kind).to eq('event')
    end

    it 'answers predicates for its kind' do
      feature = find_by_name!('up.render')

      expect(feature).to be_function
      expect(feature).to be_kind(:function)
      expect(feature).not_to be_selector
    end

  end

  # Shown as a subtitle on every feature page, and in the menu.
  describe '#long_kind' do

    it 'describes the language a feature belongs to' do
      expect(find_by_name!('up.render').long_kind).to eq('JavaScript function')
      expect(find_by_name!('[up-follow]').long_kind).to eq('HTML selector')
      expect(find_by_name!('up:form:submit').long_kind).to eq('DOM event')
    end

  end

  describe '#summary_markdown' do

    it 'is the first paragraph of the documentation' do
      feature = find_by_name!('up.render')

      expect(feature.summary_markdown).to be_present
      expect(feature.summary_markdown).not_to include("\n\n")
      expect(feature.guide_markdown).to start_with(feature.summary_markdown)
    end

  end

  describe '#published?' do

    it 'is false for an internal feature, which gets no page of its own' do
      internal_feature = subject.features.find(&:internal?)

      expect(internal_feature).to be_present
      expect(internal_feature).not_to be_published
      expect(internal_feature).not_to be_guide_page
    end

    it 'is true for a stable feature' do
      expect(find_by_name!('up.render')).to be_published
      expect(find_by_name!('up.render')).to be_guide_page
    end

  end

end
