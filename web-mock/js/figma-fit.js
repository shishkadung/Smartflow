/** Resize page + gallery iframes to full content height (no inner scroll). */
(function () {
  if (window.self !== window.top) {
    document.body.classList.add('sf-page--embed');
  }

  function fitExport() {
    var root = document.getElementById('figma-export');
    if (!root) return;

    document.documentElement.style.height = 'auto';
    document.documentElement.style.overflow = 'visible';
    document.body.style.height = 'auto';
    document.body.style.overflow = 'visible';

    var h = root.offsetHeight;
    if (window.self !== window.top) {
      document.documentElement.style.minHeight = h + 'px';
      document.body.style.minHeight = h + 'px';
      try {
        window.parent.postMessage({ type: 'sf-mock-height', height: h }, '*');
      } catch (_) {}
    }
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', fitExport);
  } else {
    fitExport();
  }
  window.addEventListener('load', fitExport);
})();
