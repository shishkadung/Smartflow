(function () {
  function resizeIframe(iframe) {
    try {
      var doc = iframe.contentDocument;
      if (!doc) return;
      var root = doc.getElementById('figma-export');
      var h = root ? root.offsetHeight : doc.documentElement.scrollHeight;
      if (h > 0) iframe.style.height = h + 'px';
    } catch (_) {}
  }

  document.querySelectorAll('.sf-gallery__frame iframe').forEach(function (iframe) {
    iframe.setAttribute('scrolling', 'no');
    iframe.addEventListener('load', function () { resizeIframe(iframe); });
  });

  window.addEventListener('message', function (e) {
    if (!e.data || e.data.type !== 'sf-mock-height') return;
    document.querySelectorAll('.sf-gallery__frame iframe').forEach(function (iframe) {
      if (iframe.contentWindow === e.source) {
        iframe.style.height = e.data.height + 'px';
      }
    });
  });
})();
