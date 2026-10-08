// The copy button in a page's ai-tools corner (ai_tools in config.rb): copies the page's
// Markdown twin, so a reader can paste the page into any AI chat.
//
// The button is [hidden] in the markup and shows itself only where the clipboard can be
// written (a secure context with navigator.clipboard and ClipboardItem).

const COPY = {
  // How long the checkmark stays after copying.
  doneMs: 2000,
}

up.compiler('.ai-tools--item.-copy', function(button) {
  if (!navigator.clipboard?.write || !window.ClipboardItem) return

  button.hidden = false
  const label = button.getAttribute('aria-label')
  let doneTimer = null

  // Screen readers don't reliably announce a changed name, so a status line says it too
  // (like the search dialog's).
  const status = up.element.affix(button, 'afterend', 'span.ai-tools--status[role=status][aria-live=polite]')

  // The checkmark, a changed name, and the announcement.
  function showDone(done) {
    button.classList.toggle('-copied', done)
    button.setAttribute('aria-label', done ? 'Copied' : label)
    status.textContent = done ? 'Copied' : ''
  }

  async function copy() {
    const markdown = fetch(button.dataset.markdownUrl).then((response) => {
      if (!response.ok) throw new Error(`Could not fetch ${response.url} (${response.status})`)
      return response.text()
    })

    // Safari only allows writing to the clipboard during the click, not after the fetch.
    // A ClipboardItem accepts the text as a promise, which keeps the write within it.
    const blob = markdown.then((text) => new Blob([text], { type: 'text/plain' }))
    await navigator.clipboard.write([new ClipboardItem({ 'text/plain': blob })])

    showDone(true)
    clearTimeout(doneTimer)
    doneTimer = setTimeout(() => showDone(false), COPY.doneMs)
  }

  button.addEventListener('click', () => {
    copy().catch((error) => console.error('Copying the page failed: %o', error))
  })

  return () => {
    clearTimeout(doneTimer)
    status.remove()
  }
})
