// Scroll spy for the contents rail: marks the section the reader is in.
//
// The current section is the last one whose heading has scrolled up past a reading
// line just below the fixed header, or the first section while none has. At the bottom
// of the page the last sections can never reach that line, so there the section a
// link has just revealed wins if it is in view, and otherwise the last heading in
// view. Exactly one item is marked at any time, in bold.
//
// Only the rail's copy (.toc.-rail) is a spy; the copy in the text stays plain. The
// rail is part of the page's frame, so every navigation compiles a new one.

const READING_LINE_BELOW_HEADER = 40

function readingLine() {
  let header = document.querySelector('.guide--head')
  return (header ? header.getBoundingClientRect().bottom : 0) + READING_LINE_BELOW_HEADER
}

function currentIndex(headings) {
  let line = readingLine()
  let tops = headings.map((heading) => heading.getBoundingClientRect().top)
  let root = document.scrollingElement

  if (Math.ceil(root.scrollTop + window.innerHeight) >= root.scrollHeight - 2) {
    let visible = (index) => tops[index] < window.innerHeight && headings[index].getBoundingClientRect().bottom > line - READING_LINE_BELOW_HEADER
    let target = headings.findIndex((heading) => location.hash === '#' + heading.id)
    if (target >= 0 && visible(target)) return target

    let lastInView = tops.findLastIndex((top) => top < window.innerHeight)
    if (lastInView >= 0) return lastInView
  }

  return Math.max(tops.findLastIndex((top) => top <= line), 0)
}

up.compiler('.toc.-rail', function(toc) {
  let items = [...toc.querySelectorAll('.toc--item')]
  let entries = items.map((item) => {
    let link = item.querySelector('a[href^="#"]')
    let heading = link && document.getElementById(decodeURIComponent(link.getAttribute('href').slice(1)))
    return heading && { item, link, heading }
  }).filter(Boolean)

  if (!entries.length) return

  let headings = entries.map((entry) => entry.heading)
  let current = null

  function update() {
    let index = currentIndex(headings)
    if (index === current) return
    current = index
    entries.forEach((entry, i) => {
      entry.item.classList.toggle('-current', i === index)
      if (i === index) {
        entry.link.setAttribute('aria-current', 'location')
      } else {
        entry.link.removeAttribute('aria-current')
      }
    })
  }

  let scheduled = false
  function schedule() {
    if (scheduled) return
    scheduled = true
    requestAnimationFrame(() => {
      scheduled = false
      // The rail may have been swapped out in the meantime.
      if (toc.isConnected) update()
    })
  }

  update()

  window.addEventListener('scroll', schedule, { passive: true })
  window.addEventListener('resize', schedule)
  let stopLocation = up.on('up:location:changed', schedule)

  return () => {
    window.removeEventListener('scroll', schedule)
    window.removeEventListener('resize', schedule)
    stopLocation()
  }
})
