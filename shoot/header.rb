# The global header at the widths where its arrangement changes, plus a probe of its
# parts: where each one sits, whether anything is clipped, and which section is current.
HEADER_PROBE = <<~JS
  const head = document.querySelector('.guide--head')
  const bar = head.getBoundingClientRect()
  const parts = {}
  const describe = (el) => {
    const r = el.getBoundingClientRect()
    const visible = r.width > 0 && getComputedStyle(el).visibility !== 'hidden'
    return visible ? [Math.round(r.left), Math.round(r.right), el.scrollWidth > el.clientWidth + 1 ? 'CLIPPED' : 'ok'] : 'hidden'
  }
  for (const [name, selector] of Object.entries({
    logo: '.guide--head .logo', version: '.guide--head .version-nav', search: '.guide--head .search-pill',
    burger: '.guide--head a[href="/menu/narrow"]'
  })) {
    const el = document.querySelector(selector)
    parts[name] = el ? describe(el) : 'absent'
  }
  // The logo image itself, against the box it sits in.
  const img = document.querySelector('.guide--head .logo img')
  const box = img && img.parentElement.parentElement.getBoundingClientRect()
  parts.logoImage = img ? [Math.round(img.getBoundingClientRect().right), Math.round(box.right)] : 'absent'
  parts.sections = [...document.querySelectorAll('.guide--head .top-nav--section')].filter(e => e.getBoundingClientRect().width > 0).map(e => (e.getAttribute('aria-label') || e.textContent.trim()) + (e.matches('.up-current') ? '*' : ''))
  parts.backgrounds = [...new Set([head, ...head.querySelectorAll('*')].map(e => getComputedStyle(e).backgroundColor).filter(c => c !== 'rgba(0, 0, 0, 0)'))]
  parts.overflow = head.scrollWidth > bar.width + 1
  return parts
JS

Shoot.suite 'header', widths: [390, 800, 1024, 1100, 1280, 1600], description: 'header arrangement, clipping, current section' do |b|
  [['/', 'landing'], ['/targeting-fragments', 'learnpage'], ['/up.render', 'apifeat']].each do |path, name|
    b.visit(path)
    b.shot("header-#{name}")
    puts '  ' + JSON.generate(b.js(HEADER_PROBE))
  end
end
