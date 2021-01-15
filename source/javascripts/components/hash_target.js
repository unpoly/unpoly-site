// let markedElement = null
//
// window.addEventListener('hashchange', function () {
//   if (var previousElement = e.)
//   if (markedElement) {
//     markedElement.classList.remove('hash-target')
//   }
//
//   if (location.hash && (markedElement = document.querySelector(location.hash))) {
//     markedElement.classList.add('hash-target')
//   }
// });

let markedElement = null

up.compiler('[id]', { batch: true }, function(elements) {
  if (markedElement) {
    markedElement.classList.remove('hash-target')
  }

  var hash = location.hash

  if (!hash) {
    return
  }

  var matchesHash = function(element) { return hash === "#" + element.getAttribute('id') }
  var newElement = up.util.find(elements, matchesHash)

  if (newElement) {
    newElement.classList.add('hash-target')
    markedElement = newElement
  }
})
