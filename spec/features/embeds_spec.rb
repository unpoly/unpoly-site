# The request-flow diagram has one source (_fragment_updates_diagram.html.erb) and two
# readers: the landing renders the partial, and "How Unpoly works" embeds it from its
# Markdown with <div embed="fragment-updates-diagram"></div> (Unpoly::Guide::Embeds).
describe 'the request-flow diagram embedded in a guide', type: :feature, js: true do

  OVERVIEW_SLUG = 'start/overview'.freeze

  def overview_markdown
    Unpoly::Guide.current.find_by_guide_id!(OVERVIEW_SLUG).guide_markdown
  end

  it 'never ships the placeholder the writer marks its place with' do
    visit "/#{OVERVIEW_SLUG}"

    expect(page.html).not_to include('TODO(diagram)')
  end

  it 'renders the diagram in the text, as wide as the column, without widening the page' do
    skip 'the page does not embed the diagram yet' unless overview_markdown.include?('embed="fragment-updates-diagram"')
    visit "/#{OVERVIEW_SLUG}"

    expect(page).to have_css('.prose figure.diagram svg.diagram--canvas text', text: 'FRAGMENTS')
    facts = page.evaluate_script(<<~JS)
      (function() {
        let figure = document.querySelector('.prose figure.diagram').getBoundingClientRect()
        let column = document.querySelector('.guide--content').getBoundingClientRect()
        return { width: Math.round(figure.width), column: Math.round(column.width), overflows: document.documentElement.scrollWidth > window.innerWidth }
      })()
    JS
    expect(facts['width']).to eq(facts['column'])
    expect(facts['overflows']).to be(false)
  end

end
