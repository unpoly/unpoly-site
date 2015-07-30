(function() {
  up.bus.on('fragment:ready', function($fragment) {
    if ($fragment.is('.content')) {
      return $('body').scrollTop(0);
    }
  });

  hljs.configure({
    languages: ['javascript', 'html']
  });

  up.compiler('pre code', function($fragment) {
    return hljs.highlightBlock($fragment.get(0));
  });

}).call(this);
