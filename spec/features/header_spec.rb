# The global header, per the header spec in docs/rework-2026/plan.md: one color with
# everything on it in white; logo and version on the left, the search in the middle,
# every section on the right; sentence case; a visible ring on every keyboard stop.
describe 'the header', type: :feature, js: true do

  SECTIONS = %w[Learn API Demo Changes Support GitHub].freeze

  # Each section's accessible name: its words, or the label of an icon-only link.
  def header_sections
    all('.guide--head .top-nav--section').map { |link| link['aria-label'] || link.text.strip }
  end

  def box(selector)
    page.evaluate_script("(function() { let r = document.querySelector(#{selector.to_json}).getBoundingClientRect(); return [r.left, r.right] })()")
  end

  it 'has one background color, with nothing on it drawing a ground of its own' do
    visit '/targeting-fragments'

    opaque = page.evaluate_script(<<~JS)
      (function() {
        let head = document.querySelector('.guide--head')
        return [...head.querySelectorAll('*')]
          .map((element) => getComputedStyle(element).backgroundColor)
          .filter((color) => /^rgb\\(/.test(color))
      })()
    JS

    expect(opaque).to eq([])
  end

  it 'is 53px tall and indigo' do
    visit '/targeting-fragments'

    bar = page.evaluate_script(<<~JS)
      (function() {
        let head = document.querySelector('.guide--head')
        let probe = document.createElement('div')
        probe.style.color = 'hsl(233, 24%, 33%)'
        document.body.append(probe)
        let indigo = getComputedStyle(probe).color
        probe.remove()
        return [head.getBoundingClientRect().height, getComputedStyle(head).backgroundColor, indigo]
      })()
    JS

    expect(bar[0]).to eq(53)
    expect(bar[1]).to eq(bar[2])
  end

  it 'lists every section in sentence case, Support among them like any other' do
    visit '/targeting-fragments'

    expect(header_sections).to eq(SECTIONS)
    expect(page).to have_no_css('.guide--head .-support')
    transforms = page.evaluate_script("[...document.querySelectorAll('.guide--head .top-nav--section')].map((e) => getComputedStyle(e).textTransform)")
    expect(transforms.uniq).to eq(['none'])
  end

  it 'shows GitHub as its icon alone, named for assistive tech and level with the words' do
    visit '/targeting-fragments'

    github = find('.guide--head .top-nav--section[href="https://github.com/unpoly/unpoly"]')
    expect(github.text.strip).to eq('')
    expect(github['aria-label']).to eq('GitHub')
    expect(github).to have_css('.fa-github[aria-hidden="true"]')

    # Same box as a word, so hover and current underlines line up across the row.
    tops_and_bottoms = page.evaluate_script(<<~JS)
      [...document.querySelectorAll('.guide--head .top-nav--section')].map((link) => {
        let r = link.getBoundingClientRect()
        return [Math.round(r.top), Math.round(r.bottom), getComputedStyle(link).color]
      })
    JS
    expect(tops_and_bottoms.uniq.size).to eq(1)
  end

  it 'puts the brand on the left, the search in the middle and the sections on the right' do
    visit '/targeting-fragments'

    logo = box('.guide--head .logo')
    version = box('.guide--head .version-nav')
    search = box('.guide--head .search-pill')
    sections = box('.guide--head .top-nav')

    expect(logo.last).to be < version.first
    expect(version.last).to be < search.first
    expect(search.last).to be < sections.first

    window_width = page.evaluate_script('window.innerWidth')
    expect(((search.first + search.last) / 2 - window_width / 2).abs).to be <= 2
  end

  it 'marks Learn as current on a Learn page' do
    visit '/targeting-fragments'

    expect(page).to have_css('.guide--head .top-nav--section.up-current', text: 'Learn')
    expect(page).to have_css('.guide--head .top-nav--section.up-current', count: 1)
  end

  it 'marks API as current on a reference page' do
    visit '/up.render'

    expect(page).to have_css('.guide--head .top-nav--section.up-current', text: 'API')
    expect(page).to have_css('.guide--head .top-nav--section.up-current', count: 1)
  end

  %w[/formats /url-patterns /relaxed-json].each do |path|
    it "marks API as current on #{path}, which no symbol pattern matches" do
      visit path

      expect(page).to have_css('.guide--head .top-nav--section.up-current', text: 'API')
      expect(page).to have_css('.guide--head .top-nav--section.up-current', count: 1)
    end
  end

  it 'moves the current mark when the reader moves into another section' do
    visit '/up.render'
    within('.guide--head') { click_link 'Learn' }

    expect(page).to have_current_path('/learn')
    expect(page).to have_css('.guide--head .top-nav--section.up-current', text: 'Learn')
    expect(page).to have_css('.guide--head .top-nav--section.up-current', count: 1)
  end

  it 'shows a focus ring on the logo, the version switch and the search' do
    visit '/'

    rings = 3.times.map do
      page.send_keys(:tab)
      page.evaluate_script(<<~JS)
        (function() {
          let element = document.activeElement
          let style = getComputedStyle(element)
          return [element.className.split(' ')[0], style.outlineStyle, style.outlineWidth]
        })()
      JS
    end

    expect(rings.map(&:first)).to eq(%w[logo version-nav search-pill])
    rings.each do |name, style, width|
      expect(style).to eq('solid'), "#{name} has no visible focus ring"
      expect(width).to eq('2px')
    end
  end

  it 'marks the version these docs belong to in the version switch' do
    visit '/targeting-fragments'
    find('.guide--head .version-nav').click

    within('up-popup') do
      expect(page).to have_css('.choice--item.up-current[aria-current]', text: 'Unpoly 3.')
      expect(page).to have_css('.choice--item.up-current', count: 1)
    end
  end

  describe 'just above the sidebar breakpoint', driver: :selenium_small_desktop do
    it 'shows the whole logo and every section' do
      visit '/targeting-fragments'

      clipped = page.evaluate_script(<<~JS)
        (function() {
          let logo = document.querySelector('.guide--head .logo')
          let image = logo.querySelector('img').getBoundingClientRect()
          return image.right > logo.getBoundingClientRect().right + 1 || logo.scrollWidth > logo.clientWidth + 1
        })()
      JS

      expect(clipped).to be(false)
      expect(header_sections).to eq(SECTIONS)
      expect(page.evaluate_script("document.querySelector('.guide--head').scrollWidth <= window.innerWidth")).to be(true)
    end
  end

  describe 'on a phone', driver: :selenium_phone do
    it 'keeps the logo, the search and the burger, and nothing else' do
      visit '/targeting-fragments'

      expect(page).to have_css('.guide--head .logo')
      expect(page).to have_css('.guide--head .search-pill')
      expect(page).to have_css('.guide--head a[href="/menu/narrow"]')
      expect(page).to have_no_css('.guide--head .top-nav--section')
      expect(page).to have_no_css('.guide--head .version-nav')
    end

    it 'gives the search icon a target a finger can hit' do
      visit '/targeting-fragments'

      # A tap 20px beside the icon's centre, in either direction, still lands on it.
      hits = page.evaluate_script(<<~JS)
        (function() {
          let pill = document.querySelector('.guide--head .search-pill')
          let r = pill.getBoundingClientRect()
          let x = r.left + r.width / 2, y = r.top + r.height / 2
          return [[-20, 0], [20, 0], [0, -18], [0, 18]].map(([dx, dy]) =>
            pill.contains(document.elementFromPoint(x + dx, y + dy)))
        })()
      JS

      expect(hits).to eq([true, true, true, true])
    end
  end

end
