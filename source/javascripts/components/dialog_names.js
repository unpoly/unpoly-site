// Unpoly makes an overlay's box the dialog (role="dialog", aria-modal), but gives it no
// name, so a screen reader would announce a bare "dialog". A popup has no box: there the
// overlay element itself is the dialog.
//
// We name the dialog after the first heading in it: a page's <h1> in a modal, the
// visually hidden "Menu" in the drawer (menu/narrow.html.erb) and "Versions" in the
// version popup (version_choice.html.erb). An overlay that names itself (the search
// dialog) keeps its name.
up.on('up:layer:opened', ({ layer }) => {
  let box = layer.element.querySelector(`up-${layer.mode}-box`) || layer.element
  if (box.hasAttribute('aria-label') || box.hasAttribute('aria-labelledby')) return

  let heading = box.querySelector('h1, h2, h3, h4, h5, h6')
  if (!heading) return

  heading.id ||= `dialog-name-${Math.random().toString(36).slice(2)}`
  box.setAttribute('aria-labelledby', heading.id)
})
