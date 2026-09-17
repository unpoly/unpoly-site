describe Unpoly::Guide::Toc do

  let(:repository) { Unpoly::Guide.current }

  describe 'the real manifest' do

    let(:toc) { repository.toc }

    it 'has a linear Learn area and a lookup API area' do
      expect(toc.learn).to be_linear
      expect(toc.api).not_to be_linear
    end

    it 'lists every documented page exactly once' do
      listed = toc.areas.flat_map(&:page_slugs)

      expect(listed.sort).to eq(repository.documented_page_slugs.sort)
      expect(listed.tally.values).to all(eq(1))
    end

    it 'lists every module with a guide page exactly once' do
      expect(toc.api.module_names.sort).to eq(repository.documented_module_names.sort)
    end

    it 'does not list internal modules' do
      expect(toc.api.module_names).not_to include('up.browser', 'up.migrate', 'up.tooltip')
    end

    it 'starts a chapter at its first page, which drops out of the children' do
      chapter = toc.learn.topics.detect { |topic| topic.title == 'Loading state' }

      expect(chapter.start_page.guide_id).to eq('loading-state')
      expect(chapter.children).not_to include(chapter.start_page)
    end

    it 'orders the next-page widget by the manifest' do
      install = repository.find_page!('install')

      expect(toc.previous_page(install).guide_id).to eq('start/overview')
      expect(toc.next_page(install).guide_id).to eq('start/links')
    end

    it 'does not walk the lookup area when reading linearly' do
      expect(toc.reading_order).not_to include(repository.find_page!('url-patterns'))
    end

    it 'groups a module topic by feature kind' do
      module_topic = toc.api.topics.detect { |topic| topic.respond_to?(:module_name) && topic.module_name == 'up.link' }

      expect(module_topic.children.map(&:menu_title)).to include('HTML', 'JavaScript')
    end

  end

  describe 'strict shapes' do

    def build(data)
      described_class.new(data, repository)
    end

    def minimal
      {
        'learn' => { 'title' => 'Learn', 'reading' => 'linear', 'topics' => [
          { 'type' => 'page-group', 'title' => 'All pages', 'pages' => repository.documented_page_slugs },
        ] },
        'api' => { 'title' => 'API', 'reading' => 'lookup', 'topics' => repository.documented_module_names.map { |name| { 'type' => 'module', 'module' => name } } },
      }
    end

    it 'accepts a manifest that accounts for everything' do
      expect { build(minimal) }.not_to raise_error
    end

    it 'rejects an unknown topic type' do
      data = minimal
      data['learn']['topics'] << { 'type' => 'carousel', 'title' => 'Nope' }

      expect { build(data) }.to raise_error(described_class::Invalid, /unknown topic type 'carousel'/)
    end

    it 'rejects an unknown key' do
      data = minimal
      data['learn']['topics'].first['color'] = 'red'

      expect { build(data) }.to raise_error(described_class::Invalid, /unknown key\(s\) color/)
    end

    it 'rejects a page listed twice' do
      data = minimal
      data['learn']['topics'] << { 'type' => 'page-group', 'title' => 'Again', 'pages' => ['install'] }

      expect { build(data) }.to raise_error(described_class::Invalid, /listed more than once: install/)
    end

    it 'rejects a missing page' do
      data = minimal
      data['learn']['topics'].first['pages'] -= ['install']

      expect { build(data) }.to raise_error(described_class::Invalid, /not listed: install/)
    end

    it 'rejects a slug that no page declares' do
      data = minimal
      data['learn']['topics'].first['pages'] += ['a-page-we-never-wrote']

      expect { build(data) }.to raise_error(described_class::Invalid, /without an @page directive: a-page-we-never-wrote/)
    end

    it 'rejects a missing module' do
      data = minimal
      data['api']['topics'].shift

      expect { build(data) }.to raise_error(described_class::Invalid, /not listed in 'api'/)
    end

    it 'rejects a start page that is not in the group' do
      data = minimal
      data['learn']['topics'].first['start'] = 'nope'

      expect { build(data) }.to raise_error(described_class::Invalid, /starts at 'nope'/)
    end

  end

end
