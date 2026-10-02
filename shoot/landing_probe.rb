# Computed styles of the landing's sections, code, cards and diagram, printed as data.
Shoot.suite 'landing-probe', widths: [1280, 390], description: 'landing computed-style probe (prints JSON)' do |b|
  b.visit('/')
  puts JSON.pretty_generate(b.js(<<~JS))
    const out = {}
    out.sections = [...document.querySelectorAll('.landing > *, .landing section')].slice(0, 30).map(s => {
      const cs = getComputedStyle(s), r = s.getBoundingClientRect()
      return [s.tagName + '.' + s.className, cs.paddingTop, cs.paddingBottom, cs.backgroundColor, Math.round(r.top + scrollY), Math.round(r.height)]
    })
    const pre = document.querySelector('.landing--code.-hero')
    if (pre) {
      const cs = getComputedStyle(pre)
      out.pre = [cs.color, cs.backgroundColor, cs.fontWeight, cs.fontSize, cs.overflowX]
      out.preSpans = [...new Set([...pre.querySelectorAll('span, mark')].map(s => s.className + ':' + getComputedStyle(s).color))]
    }
    const card = document.querySelector('.landing--card')
    if (card) out.card = [card.className, getComputedStyle(card).paddingTop, getComputedStyle(card).paddingLeft]
    const fig = document.querySelector('figure.diagram')
    if (fig) out.diagram = [fig.clientWidth, fig.scrollWidth, getComputedStyle(fig).overflowX]
    out.pres = [...document.querySelectorAll('pre')].map(p => [p.className, p.clientWidth, p.scrollWidth])
    out.h2Margins = [...document.querySelectorAll('.landing h2')].map(e => getComputedStyle(e).marginTop)
    return out
  JS
end
