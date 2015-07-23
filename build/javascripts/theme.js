(function() {
  up.bus.on('fragment:ready', function($fragment) {
    if ($fragment.is('#content')) {
      return $('body').scrollTop(0);
    }
  });

  hljs.configure({
    languages: ['javascript', 'html']
  });

  up.awaken('pre code', function($fragment) {
    return hljs.highlightBlock($fragment.get(0));
  });

}).call(this);
