describe Unpoly::Guide::Skill do

  def twins(&block)
    Unpoly::Guide::MarkdownTwins.new.tap(&block)
  end

  def twin(path, **subject)
    Unpoly::Guide::MarkdownTwins::Twin.new(path, subject)
  end

  describe '.filename' do
    it 'appends the kind of an API symbol and spells out $' do
      expect(described_class.filename(twin('/up.render', documentable: 'up.render'))).to eq('up-render-function')
      expect(described_class.filename(twin('/up.$compiler', documentable: 'up.$compiler'))).to eq('up-dollar-compiler-function')
      expect(described_class.filename(twin('/up:link:follow', documentable: 'up:link:follow'))).to eq('up-link-follow-event')
      expect(described_class.filename(twin('/up-follow', documentable: 'up-follow'))).to eq('up-follow-selector')
      expect(described_class.filename(twin('/X-Up-Target', documentable: 'X-Up-Target'))).to eq('x-up-target-header')
    end

    it 'tells a module from the class of the same name' do
      expect(described_class.filename(twin('/up.layer', documentable: 'up.layer'))).to eq('up-layer-module')
      expect(described_class.filename(twin('/up.Layer', documentable: 'up.Layer'))).to eq('up-layer-class')
    end

    it 'gives pages no suffix' do
      expect(described_class.filename(twin('/start/links', documentable: 'start/links'))).to eq('start-links')
      expect(described_class.filename(twin('/changes/3.11.0', release: '3.11.0'))).to eq('3-11-0')
      expect(described_class.filename(twin('/changes/upgrading', page: :upgrading))).to eq('upgrading')
      expect(described_class.filename(twin('/learn', page: :learn))).to eq('index')
    end
  end

  describe '.stamp' do
    it 'is a calendar version that is valid semver and grows over time' do
      expect(described_class.stamp(Time.utc(2026, 10, 7, 14, 30))).to eq('2026.1007.1430')
      expect(described_class.stamp(Time.utc(2027, 1, 5, 0, 5))).to eq('2027.105.5')

      times = [Time.utc(2026, 9, 30, 23, 59), Time.utc(2026, 10, 1, 0, 0), Time.utc(2026, 10, 1, 0, 1), Time.utc(2027, 1, 1, 0, 0)]
      versions = times.map { |time| described_class.stamp(time).split('.').map(&:to_i) }
      expect(versions).to eq(versions.sort)
      versions.flatten.map(&:to_s).each { |part| expect(part).to match(/\A(0|[1-9]\d*)\z/) }
    end
  end

  describe '#files' do
    subject(:skill) do
      described_class.new(twins do |list|
        list.add('/up.render', documentable: 'up.render')
        list.add('/start/links', documentable: 'start/links')
        list.add('/test.module', documentable: 'test.module')
        list.add('/learn', page: :learn)
        list.add('/support', page: :support)
        list.add('/changes', page: :changes)
        list.add('/changes/3.11.0', release: '3.11.0')
        list.add('/changes/1.0.0', release: '1.0.0')
      end)
    end

    it 'files pages by area, and leaves out fixtures, /support and release notes before 2.0' do
      expect(skill.files).to eq(
        '/up.render' => 'references/api/up-render-function.md',
        '/start/links' => 'references/learn/start-links.md',
        '/learn' => 'references/learn/index.md',
        '/changes' => 'references/changes/index.md',
        '/changes/3.11.0' => 'references/changes/3-11-0.md',
      )
    end
  end

  it 'fails when two pages would be written to one file' do
    list = twins do |twins|
      twins.add('/changes', page: :changes)
      twins.add('/changes/index', page: :upgrading) # also "index"
    end
    expect { described_class.new(list) }.to raise_error(described_class::Invalid, %r{references/changes/index.md})
  end

end
