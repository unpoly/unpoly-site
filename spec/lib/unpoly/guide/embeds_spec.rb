describe Unpoly::Guide::Embeds do

  it 'replaces an embed with the partial it names' do
    html = "<p>Before</p>\n<div embed=\"fragment-updates-diagram\"></div>\n<p>After</p>"

    spliced = described_class.splice(html) { |partial| "<figure>#{partial}</figure>" }

    expect(spliced).to eq("<p>Before</p>\n<figure>fragment_updates_diagram</figure>\n<p>After</p>")
  end

  it 'leaves other HTML alone' do
    html = '<div class="aside"></div><div data-embed="x"></div>'

    expect(described_class.splice(html) { raise 'not called' }).to eq(html)
  end

  it 'fails on an unknown name, so a misspelled embed never ships empty' do
    expect {
      described_class.splice('<div embed="fragment-update-diagram"></div>', source: '/start/overview') { 'x' }
    }.to raise_error(described_class::Unknown, %r{"fragment-update-diagram" \(in /start/overview\)})
  end

  it 'survives Markdown rendering unchanged' do
    markdown = "Intro.\n\n<div embed=\"fragment-updates-diagram\"></div>\n\nOutro."
    html = Unpoly::Guide::MarkdownRenderer.new(current_path: '/start/overview').to_html(markdown)

    expect(described_class.splice(html) { 'DIAGRAM' }).to include('DIAGRAM')
  end

end
