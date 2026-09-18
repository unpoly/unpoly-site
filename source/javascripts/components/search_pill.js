// The header's search pill is a link to the reference, where the site's search
// lives. When the page it sits on already has that search field, focus it instead
// of navigating — the pill then acts on the spot rather than sending the reader
// somewhere to do the same thing.
//
// Without JavaScript, or on a page with no search field, the link still works.
up.compiler('.search-pill', function(pill) {
  pill.addEventListener('click', function(event) {
    const input = document.querySelector('.search--input')
    if (!input) return

    event.preventDefault()
    input.focus()
    input.select()
  })
})
