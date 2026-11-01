// Unpoly makes an overlay's box the dialog (role="dialog", aria-modal), but gives it no
// name, so a screen reader would announce a bare "dialog". A popup has no box: there the
// overlay element itself is the dialog.
//
// We name the dialog after the first <h1> in it: a page's title in a modal, the visually
// hidden "Menu" in the drawer (menu/narrow.html.erb) and "Versions" in the version popup
// (version_choice.html.erb). An overlay that names itself with an aria-label (the search
// dialog) keeps its name.
//
// This is a compiler, not an up:layer:opened handler, so that navigating inside a modal
// names the dialog after the new page's title. The old title and its id are gone by then.
up.compiler(':is(up-modal, up-drawer, up-popup) h1', function(heading) {
  let dialog = heading.closest('up-modal-box, up-drawer-box, up-popup')
  if (!dialog || dialog.hasAttribute('aria-label')) return
  if (dialog.querySelector('h1') !== heading) return

  heading.id ||= `dialog-name-${Math.random().toString(36).slice(2)}`
  dialog.setAttribute('aria-labelledby', heading.id)
})
