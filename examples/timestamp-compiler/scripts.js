up.compiler('.timestamp', function($element) {
  var now = new Date();
  $element.text(now);
});
