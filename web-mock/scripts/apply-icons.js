const fs = require('fs');
const path = require('path');

const PAGES = path.join(__dirname, '..', 'pages');

const REPLACEMENTS = [
  ['<div class="sf-nav-item__icon">⌂</div>', '<div class="sf-nav-item__icon"><span class="sf-icon" data-icon="home"></span></div>'],
  ['<div class="sf-nav-item__icon">▣</div>', '<div class="sf-nav-item__icon"><span class="sf-icon" data-icon="scan"></span></div>'],
  ['<div class="sf-nav-item__icon">＋</div>', '<div class="sf-nav-item__icon"><span class="sf-icon" data-icon="add"></span></div>'],
  ['<div class="sf-nav-item__icon">☰</div>', '<div class="sf-nav-item__icon"><span class="sf-icon" data-icon="history"></span></div>'],
  ['<div class="sf-nav-item__icon">!</div>', '<div class="sf-nav-item__icon"><span class="sf-icon" data-icon="alert"></span></div>'],
  ['<div class="sf-nav-item__icon">📋</div>', '<div class="sf-nav-item__icon"><span class="sf-icon" data-icon="list"></span></div>'],
  ['<div class="sf-nav-item__icon">📊</div>', '<div class="sf-nav-item__icon"><span class="sf-icon" data-icon="chart"></span></div>'],
  ['<div class="sf-nav-item__icon">👤</div>', '<div class="sf-nav-item__icon"><span class="sf-icon" data-icon="user"></span></div>'],
  ['<div class="sf-nav-item__icon">🏢</div>', '<div class="sf-nav-item__icon"><span class="sf-icon" data-icon="building"></span></div>'],
  ['<div class="sf-nav-item__icon">⚙</div>', '<div class="sf-nav-item__icon"><span class="sf-icon" data-icon="tune"></span></div>'],
  ['<div class="sf-tile__icon sf-tile__icon--blue">📁</div>', '<div class="sf-tile__icon sf-tile__icon--blue"><span class="sf-icon" data-icon="folder"></span></div>'],
  ['<div class="sf-tile__icon sf-tile__icon--gold">✉</div>', '<div class="sf-tile__icon sf-tile__icon--gold"><span class="sf-icon" data-icon="mail"></span></div>'],
  ['<div class="sf-tile__icon sf-tile__icon--blue">📋</div>', '<div class="sf-tile__icon sf-tile__icon--blue"><span class="sf-icon" data-icon="list"></span></div>'],
  ['<div class="sf-tile__icon sf-tile__icon--gold">!</div>', '<div class="sf-tile__icon sf-tile__icon--gold"><span class="sf-icon" data-icon="alert"></span></div>'],
  ['<div class="sf-tile__icon sf-tile__icon--green">📊</div>', '<div class="sf-tile__icon sf-tile__icon--green"><span class="sf-icon" data-icon="chart"></span></div>'],
  ['<div class="sf-tile__icon sf-tile__icon--blue">👥</div>', '<div class="sf-tile__icon sf-tile__icon--blue"><span class="sf-icon" data-icon="users"></span></div>'],
  ['<div class="sf-tile__icon sf-tile__icon--green">⚙</div>', '<div class="sf-tile__icon sf-tile__icon--green"><span class="sf-icon" data-icon="tune"></span></div>'],
  ['<div class="sf-tile__icon sf-tile__icon--gold">📊</div>', '<div class="sf-tile__icon sf-tile__icon--gold"><span class="sf-icon" data-icon="report"></span></div>'],
  ['<div class="sf-tile__icon sf-tile__icon--purple">🔒</div>', '<div class="sf-tile__icon sf-tile__icon--purple"><span class="sf-icon" data-icon="lock"></span></div>'],
  ['<span class="sf-tile__chevron">›</span>', '<span class="sf-tile__chevron"><span class="sf-icon" data-icon="chevron-right"></span></span>'],
  ['<div class="sf-success-icon">✓</div>', '<div class="sf-success-icon"><span class="sf-icon" data-icon="check"></span></div>'],
  ['<div class="sf-pending-icon">⏳</div>', '<div class="sf-pending-icon"><span class="sf-icon" data-icon="schedule"></span></div>'],
  ['<div class="sf-launch-symbol__qr">▦</div>', '<div class="sf-launch-symbol__qr"><span class="sf-icon" data-icon="qr"></span></div>'],
  ['<span style="color:var(--sf-blue);font-size:18px;">☰</span>', '<span class="sf-layer-banner__icon"><span class="sf-icon" data-icon="layers"></span></span>'],
];

const EXTRA = [
  ['<a class="sf-back" href="staff-home.html">← Back</a>', '<a class="sf-back" href="staff-home.html"><span class="sf-icon" data-icon="arrow-left"></span> Back</a>'],
  ['<a class="sf-back" href="staff-register.html">← Back</a>', '<a class="sf-back" href="staff-register.html"><span class="sf-icon" data-icon="arrow-left"></span> Back</a>'],
  ['<a class="sf-back" href="login.html">← Back</a>', '<a class="sf-back" href="login.html"><span class="sf-icon" data-icon="arrow-left"></span> Back</a>'],
  ['<a class="sf-back" href="get-started.html">← Back</a>', '<a class="sf-back" href="get-started.html"><span class="sf-icon" data-icon="arrow-left"></span> Back</a>'],
  ['<a class="sf-back" href="signup.html">← Back</a>', '<a class="sf-back" href="signup.html"><span class="sf-icon" data-icon="arrow-left"></span> Back</a>'],
  ['<a class="sf-btn-outline" href="signup.html">← Back</a>', '<a class="sf-btn-outline" href="signup.html"><span class="sf-icon" data-icon="arrow-left"></span> Back</a>'],
  ['<div class="sf-signup-badge">+</div>', '<div class="sf-signup-badge"><span class="sf-icon" data-icon="add"></span></div>'],
  ['<a class="sf-get-started" href="login.html">Get Started →</a>', '<a class="sf-get-started" href="login.html">Get Started <span class="sf-icon" data-icon="arrow-right"></span></a>'],
  ['<a class="sf-btn-primary" href="signup-step2.html" style="text-decoration:none;">Next →</a>', '<a class="sf-btn-primary" href="signup-step2.html" style="text-decoration:none;">Next <span class="sf-icon" data-icon="arrow-right"></span></a>'],
  ['<button type="button" style="width:40px;height:40px;border-radius:12px;border:none;background:rgba(29,78,216,0.12);color:var(--sf-blue);font-size:22px;font-weight:700;">+</button>', '<button type="button" class="sf-icon-btn" aria-label="New request"><span class="sf-icon" data-icon="add"></span></button>'],
  ['<svg width="44" height="44" viewBox="0 0 24 24" fill="none" stroke="#1d4ed8" stroke-width="1.5">\n                  <path d="M3 7v10a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2h-6l-2-2H5a2 2 0 00-2 2z"/>\n                </svg>', '<span class="sf-launch-symbol__folder"><span class="sf-icon" data-icon="folder"></span></span>'],
];

const SCRIPT_BLOCK = '  <script src="../js/icons.js"></script>\n  <script src="../js/figma-fit.js"></script>';

for (const file of fs.readdirSync(PAGES).filter((f) => f.endsWith('.html'))) {
  const filePath = path.join(PAGES, file);
  let text = fs.readFileSync(filePath, 'utf8');
  const original = text;

  for (const [old, neu] of [...REPLACEMENTS, ...EXTRA]) {
    text = text.split(old).join(neu);
  }

  text = text.replace(
    /\n\s*<script src="\.\.\/js\/icons\.js"><\/script>\n\s*<script src="\.\.\/js\/figma-fit\.js"><\/script>/g,
    '\n' + SCRIPT_BLOCK,
  );

  if (!text.includes('../js/icons.js') && text.includes('../js/figma-fit.js')) {
    text = text.replace('  <script src="../js/figma-fit.js"></script>', SCRIPT_BLOCK);
  }

  if (text !== original) {
    fs.writeFileSync(filePath, text, 'utf8');
    console.log('updated:', file);
  } else {
    console.log('unchanged:', file);
  }
}
