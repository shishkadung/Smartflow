/** Inline SVG icons — Material-style outline (matches Flutter mock tone). */
(function () {
  var NS = 'http://www.w3.org/2000/svg';
  var S = {
    stroke: 'currentColor',
    fill: 'none',
    'stroke-width': '1.75',
    'stroke-linecap': 'round',
    'stroke-linejoin': 'round',
  };

  function svg(paths, viewBox) {
    var el = document.createElementNS(NS, 'svg');
    el.setAttribute('viewBox', viewBox || '0 0 24 24');
    el.setAttribute('aria-hidden', 'true');
    paths.forEach(function (d) {
      var p = document.createElementNS(NS, 'path');
      p.setAttribute('d', d);
      Object.keys(S).forEach(function (k) { p.setAttribute(k, S[k]); });
      el.appendChild(p);
    });
    return el.outerHTML;
  }

  var ICONS = {
    home: svg(['M4 10.5L12 4l8 6.5V20a1 1 0 01-1 1h-5v-6H10v6H5a1 1 0 01-1-1v-9.5z']),
    scan: svg([
      'M4 7V5a1 1 0 011-1h2',
      'M16 4h2a1 1 0 011 1v2',
      'M20 16v2a1 1 0 01-1 1h-2',
      'M8 20H6a1 1 0 01-1-1v-2',
      'M7 12h10',
      'M12 7v10',
    ]),
    add: svg(['M12 5v14', 'M5 12h14']),
    history: svg([
      'M12 8v4l3 2',
      'M3.05 11a9 9 0 101.02-4.36',
      'M3 4v4h4',
    ]),
    alert: svg([
      'M18 8A6 6 0 006 8c0 7-3 9-3 9h18s-3-2-3-9',
      'M13.73 21a2 2 0 01-3.46 0',
    ]),
    more: (function () {
      var el = document.createElementNS(NS, 'svg');
      el.setAttribute('viewBox', '0 0 24 24');
      el.setAttribute('aria-hidden', 'true');
      [[5, 12], [12, 12], [19, 12]].forEach(function (xy) {
        var c = document.createElementNS(NS, 'circle');
        c.setAttribute('cx', xy[0]);
        c.setAttribute('cy', xy[1]);
        c.setAttribute('r', '1.75');
        c.setAttribute('fill', 'currentColor');
        c.setAttribute('stroke', 'none');
        el.appendChild(c);
      });
      return el.outerHTML;
    })(),
    coa: svg([
      'M14 2H6a2 2 0 00-2 2v16a2 2 0 002 2h12a2 2 0 002-2V8z',
      'M14 2v6h6',
      'M9 15h6',
      'M9 11h6',
    ]),
    folder: svg(['M4 7h5l2 2h9a1 1 0 011 1v9a1 1 0 01-1 1H4a1 1 0 01-1-1V8a1 1 0 011-1z']),
    mail: svg([
      'M4 6h16v12H4z',
      'M4 6l8 6 8-6',
    ]),
    list: svg([
      'M9 6h12',
      'M9 12h12',
      'M9 18h12',
      'M5 6h.01',
      'M5 12h.01',
      'M5 18h.01',
    ]),
    lock: svg([
      'M7 11V8a5 5 0 0110 0v3',
      'M6 11h12v10H6z',
    ]),
    users: svg([
      'M16 21v-2a4 4 0 00-4-4H6a4 4 0 00-4 4v2',
      'M9 11a4 4 0 100-8 4 4 0 000 8z',
      'M22 21v-2a4 4 0 00-3-3.87',
      'M16 3.13a4 4 0 010 7.75',
    ]),
    user: svg([
      'M20 21v-2a4 4 0 00-4-4H8a4 4 0 00-4 4v2',
      'M12 11a4 4 0 100-8 4 4 0 000 8z',
    ]),
    tune: svg([
      'M4 21v-7',
      'M4 10V3',
      'M12 21v-9',
      'M12 8V3',
      'M20 21v-5',
      'M20 12V3',
      'M2 14h4',
      'M10 8h4',
      'M18 16h4',
    ]),
    building: svg([
      'M4 21V5a1 1 0 011-1h8a1 1 0 011 1v16',
      'M8 9h.01',
      'M8 13h.01',
      'M12 9h.01',
      'M12 13h.01',
      'M16 21V9h4v12',
    ]),
    chart: svg([
      'M4 20V10',
      'M10 20V4',
      'M16 20v-6',
      'M22 20H2',
    ]),
    layers: svg([
      'M12 3l9 5-9 5-9-5 9-5z',
      'M3 12l9 5 9-5',
      'M3 17l9 5 9-5',
    ]),
    check: svg(['M5 12l4 4L19 6']),
    schedule: svg([
      'M12 8v4l3 2',
      'M21 12a9 9 0 11-18 0 9 9 0 0118 0z',
    ]),
    'chevron-right': svg(['M9 6l6 6-6 6']),
    'arrow-left': svg(['M19 12H5', 'M12 19l-7-7 7-7']),
    'arrow-right': svg(['M5 12h14', 'M12 5l7 7-7 7']),
    'folder-open': svg([
      'M4 7h5l2 2h9a1 1 0 011 1v2',
      'M4 7v11a1 1 0 001 1h14',
      'M4 12h16',
    ]),
    qr: svg([
      'M5 5h4v4H5z',
      'M15 5h4v4h-4z',
      'M5 15h4v4H5z',
      'M15 15h2',
      'M19 15v2',
      'M15 19h4',
    ]),
    report: svg([
      'M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2',
      'M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2',
    ]),
  };

  function render() {
    document.querySelectorAll('[data-icon]').forEach(function (el) {
      var name = el.getAttribute('data-icon');
      if (ICONS[name]) el.innerHTML = ICONS[name];
    });
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', render);
  } else {
    render();
  }
})();
