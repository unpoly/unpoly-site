# An image or video in the docs is a <figure> whose <figcaption> holds a long
# description for screen readers and the Markdown twins. Sighted readers see the
# medium as if it stood alone.
describe 'figures', type: :feature, js: true do

  def caption_state
    page.evaluate_script(<<~JS)
      (function() {
        let caption = document.querySelector('.prose figure > figcaption')
        let style = getComputedStyle(caption)
        let box = caption.getBoundingClientRect()
        return {
          text: caption.textContent.trim(),
          hidden: caption.hidden || caption.closest('[hidden], [aria-hidden=true]') !== null,
          display: style.display,
          visibility: style.visibility,
          width: box.width,
          height: box.height,
        }
      })()
    JS
  end

  # The gaps between the medium and the text around the figure, and the figure's own margins.
  def medium_layout(medium_selector)
    page.evaluate_script(<<~JS)
      (function() {
        let figure = document.querySelector('.prose figure')
        let medium = figure.querySelector(#{medium_selector.to_json}).getBoundingClientRect()
        let style = getComputedStyle(figure)
        return {
          above: Math.round(medium.top - figure.previousElementSibling.getBoundingClientRect().bottom),
          below: Math.round(figure.nextElementSibling.getBoundingClientRect().top - medium.bottom),
          margins: [style.marginTop, style.marginRight, style.marginBottom, style.marginLeft],
        }
      })()
    JS
  end

  {
    '/learn/render-lifecycle' => 'img',
    '/learn/previews' => '.video-player',
  }.each do |path, medium|
    describe "on #{path}" do
      before do
        visit path
        expect(page).to have_css('.prose figure > figcaption', visible: :all)
      end

      it 'keeps the caption for screen readers, but out of sight' do
        state = caption_state

        expect(state['text']).not_to be_empty
        expect(state['hidden']).to eq(false)
        expect(state['display']).not_to eq('none')
        expect(state['visibility']).to eq('visible')
        expect(state['width']).to be <= 1
        expect(state['height']).to be <= 1
      end

      it 'spaces the medium like a bare one, with no margins of the figure' do
        layout = medium_layout(medium)

        expect(layout['margins']).to eq(%w[0px 0px 0px 0px])
        expect(layout['above']).to eq(layout['below'])
        expect(layout['above']).to be > 0
      end
    end
  end

end
