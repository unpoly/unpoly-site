(function() {
  up.bus.on('fragment:ready', function($fragment) {
    if ($fragment.is('#content')) {
      return $('body').scrollTop(0);
    }
  });

}).call(this);
