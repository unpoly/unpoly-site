up.compiler('h1[id], h2[id], h3[id], h4[id], h5[id], [anchor-link][id]', function(heading) {
  let hoverArea = up.element.createFromSelector('span.heading-anchor', { 'aria-hidden': true })
  let href = '#' + heading.id
  up.element.affix(hoverArea, 'a.heading-anchor--link', { text: '#', href })
  heading.prepend(hoverArea)
})
