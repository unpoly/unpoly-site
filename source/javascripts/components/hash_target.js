function test(elementWithID) {
  let hash = location.hash
  let id = elementWithID.id

  let isTarget = (hash) && (hash !== '#') && (hash === "#" + id)

  elementWithID.classList.toggle('hash-target', isTarget)
}

up.compiler('[id]', function(element) {
  let doTest = () => test(element)
  doTest()
  return up.on('up:location:changed', doTest)
})
