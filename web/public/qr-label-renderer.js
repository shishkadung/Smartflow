// Local print-label rendering. Encoding comes from the vendored Nayuki library.
(function (global) {
  'use strict';

  function createQrSvg(payload, size) {
    if (typeof payload !== 'string' || payload.length === 0) {
      throw new TypeError('QR payload is required');
    }
    if (!Number.isInteger(size) || size < 220 || size > 800) {
      throw new RangeError('QR display size must be 220–800 pixels');
    }
    const qr = global.qrcodegen.QrCode.encodeText(payload, global.qrcodegen.QrCode.Ecc.HIGH);
    const margin = 4;
    const dimension = qr.size + margin * 2;
    const modules = [];
    for (let y = 0; y < qr.size; y++) {
      for (let x = 0; x < qr.size; x++) {
        const finder = (x < 7 && y < 7) || (x >= qr.size - 7 && y < 7) || (x < 7 && y >= qr.size - 7);
        if (qr.getModule(x, y) && !finder) modules.push(`<circle cx="${x + margin + .5}" cy="${y + margin + .5}" r=".46"/>`);
      }
    }
    const eyes = [[0, 0], [qr.size - 7, 0], [0, qr.size - 7]].map(([x, y]) =>
      `<rect x="${x + margin}" y="${y + margin}" width="7" height="7" rx="1.2" fill="#1d4ed8"/>`
      + `<rect x="${x + margin + 1}" y="${y + margin + 1}" width="5" height="5" rx=".65" fill="#fff"/>`
      + `<rect x="${x + margin + 2}" y="${y + margin + 2}" width="3" height="3" rx=".55" fill="#122840"/>`).join('');
    return `<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}" viewBox="0 0 ${dimension} ${dimension}" aria-hidden="true">`
      + `<rect width="${dimension}" height="${dimension}" fill="#fff"/>`
      + `<g fill="#122840">${modules.join('')}</g>${eyes}</svg>`;
  }

  function renderLabel(doc) {
    const target = doc.getElementById('label-qr');
    const data = doc.getElementById('qr-label-data');
    if (!target || !data) return;
    try {
      const options = JSON.parse(data.textContent);
      target.innerHTML = createQrSvg(options.payload, options.size);
    } catch {
      target.textContent = 'QR could not be generated. Reload this label before printing.';
      target.setAttribute('role', 'alert');
    }
  }

  global.SmartflowQrLabel = { createQrSvg, renderLabel };
  if (global.document) renderLabel(global.document);
})(globalThis);
