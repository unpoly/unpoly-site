# The two area hubs, per "HUB DESIGN SETTLED" in docs/rework-2026/plan.md. /learn is a
# path into the course: Getting started on a tinted block, then the chapters as a
# numbered path, each with its overview and all of its pages. /api is a catalog: one
# row per sidebar topic, the module name as the row's link, and its signature features.
describe 'the hubs', type: :feature, js: true do

  let(:toc) { Unpoly::Guide.current.toc }

  # Whether a link reads as one: underlined, in a lighter tone of its own color.
  def light_underline(selector)
    page.evaluate_script(<<~JS)
      [...document.querySelectorAll(#{selector.to_json})].map((link) => {
        let style = getComputedStyle(link)
        let alpha = (style.textDecorationColor.match(/rgba\\(.*,\\s*([\\d.]+)\\)/) || [])[1]
        return { line: style.textDecorationLine, alpha: alpha && Number(alpha), color: style.color }
      })
    JS
  end

  def red
    page.evaluate_script("(() => { let a = document.createElement('a'); a.className = 'hub-link'; document.body.append(a); let c = getComputedStyle(a).color; a.remove(); return c })()")
  end

  describe '/learn' do

    it 'starts with Getting started on a tinted block, leading to its overview' do
      visit '/learn'

      start = find('.learn-start')
      expect(start).to have_css('.learn-start--caption', text: /start here/i)
      expect(start).to have_css('a[href="/start/overview"]', text: 'Getting started')
      expect(start).to have_css('a.chapter-pages--overview[href="/start/overview"]', text: 'How Unpoly works')
      expect(page.evaluate_script("getComputedStyle(document.querySelector('.learn-start')).backgroundColor")).not_to eq('rgba(0, 0, 0, 0)')
    end

    it 'lists every other chapter as a numbered step with its overview and all its pages' do
      visit '/learn'

      chapters = toc.learn.topics.drop(1)
      expect(all('.learn-chapter--number').map(&:text)).to eq((1..chapters.size).map(&:to_s))

      rows = all('.learn-chapter')
      expect(rows.size).to eq(chapters.size)

      chapters.zip(rows).each do |chapter, row|
        expect(row).to have_css(".learn-chapter--title a[href='#{chapter.menu_path}']", text: chapter.title)
        expect(row).to have_css("a.chapter-pages--overview[href='#{chapter.menu_path}']", text: 'Overview')
        expect(row.all('.chapter-pages .hub-link').map { |link| link[:href].sub(%r{\Ahttps?://[^/]+}, '') }).to eq(chapter.children.map(&:guide_path))
      end
    end

    it 'leaves out an overview summary that is still a placeholder' do
      visit '/learn'

      expect(page).to have_no_text('This page is being written.')
    end

    it 'draws its links red with a light underline, and the overview links bold with a grid icon' do
      visit '/learn'

      links = light_underline('.chapter-pages .hub-link, .chapter-pages--overview')
      expect(links).to all(include('line' => 'underline', 'color' => red))
      expect(links.map { |link| link['alpha'] }).to all(be_between(0.2, 0.6))

      weight = page.evaluate_script("getComputedStyle(document.querySelector('.learn-chapter .chapter-pages--overview')).fontWeight")
      expect(weight.to_i).to be >= 700
      expect(page).to have_css('.learn-chapter .chapter-pages--overview svg', count: toc.learn.topics.size - 1, visible: :all)
    end

    it 'joins the numbers with a line that ends at the last one' do
      visit '/learn'

      lines = page.evaluate_script(<<~JS)
        [...document.querySelectorAll('.learn-chapter')].map((chapter, index, all) => {
          let before = getComputedStyle(chapter, '::before')
          let box = chapter.getBoundingClientRect()
          let next = all[index + 1]?.querySelector('.learn-chapter--number').getBoundingClientRect()
          let bottom = box.bottom - parseFloat(before.bottom)
          return { drawn: before.content !== 'none', reachesNext: next ? bottom >= next.top : null }
        })
      JS

      expect(lines[0...-1]).to all(include('drawn' => true, 'reachesNext' => true))
      expect(lines.last['drawn']).to be(false)
    end

  end

  describe '/api' do

    it 'has a row per sidebar topic, each named by its link' do
      visit '/api'

      names = all('.api-row--name')
      expect(names.map { |name| name.find('.api-row--title').text }).to eq(toc.api.topics.map(&:title))
      expect(names.map { |name| name[:href].sub(%r{\Ahttps?://[^/]+}, '') }).to eq(toc.api.topics.map(&:menu_path))
    end

    it 'underlines the module name lightly as the row link, with no separate overview link' do
      visit '/api'

      titles = light_underline('.api-row--title')
      expect(titles).to all(include('line' => 'underline'))
      expect(titles.map { |title| title['alpha'] }).to all(be_between(0.2, 0.6))
      expect(page).to have_no_css('.api-row a', text: /\AOverview\z/)
      expect(page).to have_no_css('.search-prompt')
    end

    it "lists up to six signature features in red, and counts the module's other features" do
      visit '/api'

      toc.api.topics.select { |topic| topic.respond_to?(:interface) }.each do |topic|
        features = topic.children.flat_map(&:children)
        shown = features.select(&:signature_tier?).first(6)
        row = find(".api-row--name[href='#{topic.menu_path}']").find(:xpath, '..')

        expect(row.all('.api-row--feature').map { |link| link[:href].sub(%r{\Ahttps?://[^/]+}, '') }).to eq(shown.map(&:guide_path))
        rest = features.size - shown.size
        if rest > 0
          expect(row).to have_css(".api-row--more[href='#{topic.menu_path}']", text: "+ #{rest} more")
        else
          expect(row).to have_no_css('.api-row--more')
        end
      end

      features = light_underline('.api-row--feature')
      expect(features).to all(include('line' => 'underline', 'color' => red))
    end

    it 'lists the formats by their pages' do
      visit '/api'

      row = find('.api-row--name', text: 'Formats').find(:xpath, '..')
      expect(row.all('.api-row--feature').map(&:text)).to eq(['URL patterns', 'Relaxed JSON'])
    end

  end

end
