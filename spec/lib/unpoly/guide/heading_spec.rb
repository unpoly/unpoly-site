describe Unpoly::Guide::Heading do

  def ids(markdown)
    described_class.parse(markdown).map(&:id)
  end

  it 'indexes ATX headings by their generated ID' do
    expect(ids("## Slow server responses\n")).to eq(['slow-server-responses'])
  end

  it 'indexes Setext headings' do
    expect(ids("Slow server responses\n---------------------\n")).to eq(['slow-server-responses'])
  end

  it 'prefers an explicit anchor over the generated ID' do
    expect(ids("## Slow server responses {#slow}\n")).to eq(['slow'])
  end

  it 'keeps the heading text without its anchor' do
    heading = described_class.parse("## Callback arguments {#callbacks}\n").first

    expect(heading.text).to eq('Callback arguments')
    expect(heading.level).to eq(2)
  end

  it 'indexes headings of every level' do
    expect(ids("# One\n\n## Two\n\n### Three\n")).to eq(%w[one two three])
  end

  it 'does not index a commented-out heading inside a code block' do
    expect(ids("```\n## Not a heading\n```\n")).to be_empty
  end

  it 'has no headings for prose without any' do
    expect(described_class.parse("Just a paragraph.\n")).to be_empty
  end

end
