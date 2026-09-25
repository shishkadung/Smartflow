function galleryItem(label, src) {
  return `      <a class="sf-gallery__item" href="${src}" target="_blank">
        <div class="sf-gallery__label">${label}</div>
        <div class="sf-gallery__frame">
          <iframe src="${src}" title="${label}" scrolling="no"></iframe>
        </div>
      </a>`;
}

function galleryPage(title, subtitle, backHref, items) {
  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>SmartFlow — ${title}</title>
  <link rel="preconnect" href="https://fonts.googleapis.com" />
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />
  <link href="https://fonts.googleapis.com/css2?family=Source+Sans+3:wght@400;500;600;700;800&family=Source+Serif+4:opsz,wght@8..60,600;8..60,700&display=swap" rel="stylesheet" />
  <link rel="stylesheet" href="../css/tokens.css" />
  <link rel="stylesheet" href="../css/layout.css" />
  <link rel="stylesheet" href="../css/components.css" />
</head>
<body>
  <main class="sf-gallery">
    <a class="sf-gallery__back" href="${backHref}"><span class="sf-icon" data-icon="arrow-left"></span> All POVs</a>
    <p class="sf-gallery__eyebrow">${subtitle}</p>
    <h1>${title}</h1>
    <p>Open any screen full-size for Figma capture. Each frame is 414 px wide and grows with content.</p>

    <div class="sf-gallery__grid">
${items.map(([label, src]) => galleryItem(label, src)).join('\n\n')}
    </div>
  </main>
  <script src="../js/icons.js"></script>
  <script src="../js/gallery.js"></script>
</body>
</html>`;
}

module.exports = { galleryPage, galleryItem };
