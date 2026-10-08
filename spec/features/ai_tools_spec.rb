# The corner at the right end of a page title's first line (ai_tools in config.rb):
# [Markdown] [Copy] Skill · [Edit].
describe 'the ai-tools corner', type: :feature, js: true do

  def visible_items
    page.evaluate_script(<<~JS)
      [...document.querySelectorAll('.ai-tools--item')]
        .filter((item) => item.getClientRects().length > 0)
        .map((item) => [...item.classList].find((name) => name.startsWith('-')))
    JS
  end

  it 'offers the skill, the page as Markdown and a copy button, in this order' do
    visit '/targeting-fragments'

    expect(page).to have_css('.ai-tools[data-markdown="ignore"][data-pagefind-ignore]')
    expect(visible_items).to eq(%w[-skill -markdown -copy])

    expect(page).to have_css('.ai-tools--item.-skill[href="/skill"][aria-label="Install the Unpoly docs as an agent skill"]', text: /\Askill\z/i)
    expect(page).to have_css('.ai-tools--item.-markdown[href="/targeting-fragments.md"][aria-label="This page as Markdown — for agents and LLMs"] svg.icon.-markdown')
    expect(page).to have_css('button.ai-tools--item.-copy[aria-label="Copy this page as Markdown — paste it into any AI chat"]')
    expect(page).to have_no_css('.ai-tools a[href*="github.com"]')
  end

  it 'is a quiet row of gray words and icons, without button chrome' do
    visit '/targeting-fragments'

    style = page.evaluate_script(<<~JS)
      (function() {
        let skill = getComputedStyle(document.querySelector('.ai-tools--item.-skill'))
        let copy = getComputedStyle(document.querySelector('.ai-tools--item.-copy'))
        return { border: [skill.borderTopStyle, copy.borderTopStyle], transform: skill.textTransform, decoration: skill.textDecorationLine }
      })()
    JS
    expect(style).to eq('border' => %w[none none], 'transform' => 'uppercase', 'decoration' => 'none')
  end

  it 'marks the skill link as the current page on the skill page' do
    visit '/skill'
    expect(page).to have_css('.ai-tools--item.-skill[aria-current="page"]')
  end

  it 'sits on the title’s first line, at its right end' do
    visit '/targeting-fragments'

    line = page.evaluate_script(<<~JS)
      (function() {
        let corner = document.querySelector('.ai-tools').getBoundingClientRect()
        let title = document.querySelector('.guide--content h1').getBoundingClientRect()
        let column = document.querySelector('.guide--content').getBoundingClientRect()
        return { top: corner.top - title.top, right: column.right - corner.right }
      })()
    JS
    # Centred on the first line, so a small row sits a little below the title's top.
    expect(line['top']).to be_between(0, 16)
    expect(line['right'].abs).to be <= 0.5
  end

  it 'is the same on pages without a source file' do
    %w[/learn /changes/3.0.0].each do |path|
      visit path
      expect(visible_items).to eq(%w[-skill -markdown -copy])
    end
  end

  describe 'the copy button' do
    it 'copies the page’s Markdown and shows a checkmark for a moment' do
      visit '/targeting-fragments'
      page.execute_script(<<~JS)
        window.copied = null
        navigator.clipboard.write = async (items) => { window.copied = await (await items[0].getType('text/plain')).text() }
        navigator.clipboard.writeText = async (text) => { window.copied = text }
      JS

      find('.ai-tools--item.-copy').click

      expect(page).to have_css('.ai-tools--item.-copy.-copied[aria-label="Copied"] .ai-tools--done-icon')
      expect(page.evaluate_script('window.copied')).to include("# Targeting fragments")
      expect(page).to have_css('.ai-tools--item.-copy:not(.-copied)[aria-label^="Copy this page"]', wait: 4)
    end

    it 'stays hidden without a clipboard to write to' do
      visit '/targeting-fragments'

      hidden = page.evaluate_script(<<~JS)
        (function() {
          Object.defineProperty(navigator, 'clipboard', { value: undefined, configurable: true })
          let button = document.querySelector('.ai-tools--item.-copy').cloneNode(true)
          button.hidden = true
          document.body.append(button)
          up.hello(button)
          return button.hidden
        })()
      JS
      expect(hidden).to be(true)
    end
  end

  describe 'on narrower screens' do
    it 'keeps every item on a tablet', driver: :selenium_tablet do
      visit '/targeting-fragments'
      expect(visible_items).to eq(%w[-skill -markdown -copy])
    end

    it 'drops the word on a phone, keeping the icons', driver: :selenium_phone do
      visit '/targeting-fragments'
      expect(visible_items).to eq(%w[-markdown -copy])
    end
  end

end
