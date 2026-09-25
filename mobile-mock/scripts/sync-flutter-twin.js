/**
 * Sync mobile-mock role pages to Flutter mobile chrome (SfShellTopBar + bottom nav).
 * Run: node mobile-mock/scripts/sync-flutter-twin.js
 */
const fs = require('fs');
const path = require('path');

const ROOT = path.join(__dirname, '..');

const STATUS_ICONS = `          <span class="sf-status-bar__time">9:41</span>
          <div class="sf-status-bar__island"></div>
          <div class="sf-status-bar__icons">
            <svg width="16" height="12" viewBox="0 0 16 12" fill="currentColor"><rect x="0" y="7" width="3" height="5" rx="0.5"/><rect x="4.5" y="5" width="3" height="7" rx="0.5"/><rect x="9" y="2.5" width="3" height="9.5" rx="0.5"/><rect x="13.5" y="0" width="2.5" height="12" rx="0.5" opacity="0.35"/></svg>
            <svg width="16" height="12" viewBox="0 0 16 12" fill="currentColor"><path d="M8 2.4C5.4 2.4 3.1 3.6 1.6 5.5L0 3.9C2 1.6 4.8 0 8 0s6 1.6 8 3.9l-1.6 1.6C12.9 3.6 10.6 2.4 8 2.4zm0 3.6c-1.6 0-3 .8-3.9 2l-1.6-1.6C3.7 4.8 5.7 3.6 8 3.6s4.3 1.2 5.5 2.4L11.9 8c-.9-1.2-2.3-2-3.9-2zm0 3.6c-.9 0-1.6.4-2.1 1l2.1 2.1 2.1-2.1c-.5-.6-1.2-1-2.1-1z"/></svg>
            <svg width="26" height="13" viewBox="0 0 26 13" fill="none"><rect x="0.5" y="0.5" width="22" height="12" rx="3.5" stroke="currentColor" stroke-opacity="0.4"/><rect x="2" y="2" width="18" height="9" rx="2" fill="currentColor"/><path d="M24 4.5v4a2 2 0 000-4z" fill="currentColor" opacity="0.4"/></svg>
          </div>`;

function shellChrome({ officeName, officeCode, profileHref, requestsHref, requestsActive }) {
  return `        <div class="sf-shell-chrome">
          <header class="sf-status-bar sf-status-bar--on-navy">
${STATUS_ICONS}
          </header>
          <header class="sf-shell-topbar">
            <img class="sf-muni-seal sf-muni-seal--on-navy" src="../../assets/brand/urbiztondo_seal.png" width="36" height="36" alt="" />
            <div class="sf-shell-topbar__text">
              <div class="sf-shell-topbar__office">${officeName}</div>
              <div class="sf-wordmark sf-wordmark--on-dark">
                <span class="sf-wordmark__smart">Smart</span><span class="sf-wordmark__flow">Flow</span>
              </div>
            </div>
            <button class="sf-shell-icon" type="button" aria-label="How to use this page" title="How to use this page">
              <span class="sf-icon" data-icon="help"></span>
            </button>
            <a class="sf-shell-icon${requestsActive ? ' is-active' : ''}" href="${requestsHref}" aria-label="Document requests" title="Document requests">
              <span class="sf-icon" data-icon="swap"></span>
            </a>
            <a class="sf-office-badge sf-office-badge--on-navy" href="${profileHref}">${officeCode}</a>
          </header>
        </div>`;
}

function staffNav(active) {
  const tabs = [
    ['staff-home.html', 'home', 'Home', false],
    ['staff-scan.html', 'scan', 'Scan', true],
    ['staff-alerts.html', 'alert', 'Alerts', false, 2],
    ['staff-requests.html', 'more', 'Menu', false],
  ];
  return navHtml(tabs, active);
}

function headNav(active) {
  const tabs = [
    ['head-home.html', 'home', 'Home', false],
    ['head-queue.html', 'list', 'Queue', true],
    ['head-alerts.html', 'alert', 'Alerts', false, 3],
    ['head-home.html#menu', 'more', 'Menu', false],
  ];
  return navHtml(tabs, active);
}

function adminNav(active) {
  const tabs = [
    ['admin-home.html', 'home', 'Home', false],
    ['admin-home.html#scan', 'scan', 'Scan', true],
    ['admin-coa-summary.html', 'coa', 'COA', false],
    ['admin-users.html', 'more', 'Menu', false],
  ];
  return navHtml(tabs, active);
}

function navHtml(tabs, active) {
  const items = tabs.map(([href, icon, label, elevated, badge]) => {
    const hrefFile = href.split('#')[0];
    const match = hrefFile === active;
    const cls = `sf-nav-item${match ? ' sf-nav-item--active' : ''}${elevated ? ' sf-nav-item--elevated' : ''}`;
    const iconBlock = badge
      ? `<div class="sf-nav-item__icon-wrap"><div class="sf-nav-item__icon"><span class="sf-icon" data-icon="${icon}"></span></div><span class="sf-nav-item__badge">${badge}</span></div>`
      : `<div class="sf-nav-item__icon"><span class="sf-icon" data-icon="${icon}"></span></div>`;
    return `            <a class="${cls}" href="${href}">
              ${iconBlock}
              <span class="sf-nav-item__label">${label}</span>
            </a>`;
  });
  return `          <nav class="sf-bottom-nav">\n${items.join('\n')}\n          </nav>`;
}

const CAPTION_FIXES = [
  [/Scan folder QR/g, 'Scan'],
  [/Look up a folder, then Mark IN or Mark OUT\./g, 'Mark IN when a folder arrives · OUT when you send it.'],
  [/Register a document folder/g, 'Register'],
  [/Office queue/g, 'Office overview'],
  [/Folders currently at your office\./g, 'Snapshot of folders at your office.'],
  [/Document requests/g, 'Requests'],
  [/COA summary/g, 'COA reports'],
];

function replaceShell(html, opts) {
  // Remove old status bar + optional old app header; insert shell chrome before .sf-phone
  let out = html;

  // Strip existing shell chrome if re-run
  out = out.replace(/\s*<div class="sf-shell-chrome">[\s\S]*?<\/div>\s*(?=<div class="sf-phone">)/, '\n');

  // Strip standalone status bar (not inside shell)
  out = out.replace(/\s*<header class="sf-status-bar">[\s\S]*?<\/header>\s*(?=<div class="sf-phone">)/, '\n');

  // Strip old light app header inside scroll
  out = out.replace(/\s*<header class="sf-app-header">[\s\S]*?<\/header>\s*/, '\n            ');

  const chrome = shellChrome(opts);
  out = out.replace(
    /(<div class="sf-device__screen">)\s*/,
    `$1\n${chrome}\n`
  );

  return out;
}

function replaceNav(html, role, activeFile) {
  const nav =
    role === 'staff' ? staffNav(activeFile) :
    role === 'head' ? headNav(activeFile) :
    adminNav(activeFile);
  return html.replace(/\s*<nav class="sf-bottom-nav">[\s\S]*?<\/nav>/, `\n${nav}`);
}

function applyCaptions(html) {
  let out = html;
  for (const [re, rep] of CAPTION_FIXES) out = out.replace(re, rep);
  return out;
}

function processFile(filePath, role, meta) {
  let html = fs.readFileSync(filePath, 'utf8');
  const base = path.basename(filePath);
  const requestsActive = /requests/i.test(base);
  html = replaceShell(html, {
    officeName: meta.officeName,
    officeCode: meta.officeCode,
    profileHref: meta.profileHref,
    requestsHref: meta.requestsHref,
    requestsActive,
  });
  if (html.includes('sf-bottom-nav')) {
    html = replaceNav(html, role, base);
  }
  html = applyCaptions(html);
  // Ensure overview card compact class on non-home scan/register/etc
  if (!/staff-home|head-home|admin-home/.test(base)) {
    html = html.replace(
      'class="sf-overview-card"',
      'class="sf-overview-card sf-overview-card--compact"'
    );
  }
  fs.writeFileSync(filePath, html);
  console.log('updated', path.relative(ROOT, filePath));
}

const staffDir = path.join(ROOT, 'pages', 'employee');
const headDir = path.join(ROOT, 'pages', 'head');
const adminDir = path.join(ROOT, 'pages', 'admin');

for (const f of fs.readdirSync(staffDir).filter((x) => x.endsWith('.html'))) {
  processFile(path.join(staffDir, f), 'staff', {
    officeName: 'Engineering Office',
    officeCode: 'ENG',
    profileHref: 'staff-profile.html',
    requestsHref: 'staff-requests.html',
  });
}

for (const f of fs.readdirSync(headDir).filter((x) => x.endsWith('.html'))) {
  processFile(path.join(headDir, f), 'head', {
    officeName: 'Engineering Office',
    officeCode: 'ENG',
    profileHref: 'head-home.html',
    requestsHref: 'head-home.html',
  });
}

for (const f of fs.readdirSync(adminDir).filter((x) => x.endsWith('.html'))) {
  processFile(path.join(adminDir, f), 'admin', {
    officeName: 'Accounting Office',
    officeCode: 'ACC',
    profileHref: 'admin-profile.html',
    requestsHref: 'admin-home.html',
  });
}

console.log('done');
