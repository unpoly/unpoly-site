up.compiler('timestamp', function($element) {
  now = new Date();
  $element.text(now);
});
