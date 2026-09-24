const fs = require('fs');
const path = require('path');

const HEAD = path.join(__dirname, '..', 'pages', 'head');
const ADMIN = path.join(__dirname, '..', 'pages', 'admin');

const STATUS = `        <header class="sf-status-bar">
          <span class="sf-status-bar__time">9:41</span>
          <div class="sf-status-bar__island"></div>
          <div class="sf-status-bar__icons">
            <svg width="16" height="12" viewBox="0 0 16 12" fill="currentColor"><rect x="0" y="7" width="3" height="5" rx="0.5"/><rect x="4.5" y="5" width="3" height="7" rx="0.5"/><rect x="9" y="2.5" width="3" height="9.5" rx="0.5"/><rect x="13.5" y="0" width="2.5" height="12" rx="0.5" opacity="0.35"/></svg>
            <svg width="16" height="12" viewBox="0 0 16 12" fill="currentColor"><path d="M8 2.4C5.4 2.4 3.1 3.6 1.6 5.5L0 3.9C2 1.6 4.8 0 8 0s6 1.6 8 3.9l-1.6 1.6C12.9 3.6 10.6 2.4 8 2.4zm0 3.6c-1.6 0-3 .8-3.9 2l-1.6-1.6C3.7 4.8 5.7 3.6 8 3.6s4.3 1.2 5.5 2.4L11.9 8c-.9-1.2-2.3-2-3.9-2zm0 3.6c-.9 0-1.6.4-2.1 1l2.1 2.1 2.1-2.1c-.5-.6-1.2-1-2.1-1z"/></svg>
            <svg width="26" height="13" viewBox="0 0 26 13" fill="none"><rect x="0.5" y="0.5" width="22" height="12" rx="3.5" stroke="currentColor" stroke-opacity="0.4"/><rect x="2" y="2" width="18" height="9" rx="2" fill="currentColor"/><path d="M24 4.5v4a2 2 0 000-4z" fill="currentColor" opacity="0.4"/></svg>
          </div>
        </header>`;

function headNav(active) {
  const tabs = [
    ['head-home.html', 'home', 'Home'],
    ['head-register.html', 'add', 'New'],
    ['head-queue.html', 'list', 'Queue'],
    ['head-alerts.html', 'alert', 'Alerts', 3],
    ['head-analytics.html', 'chart', 'Analytics'],
  ];
  const items = tabs.map(([href, icon, label, badge]) => {
    const isActive = href === active;
    const iconHtml = badge
      ? `<div class="sf-nav-item__icon-wrap"><div class="sf-nav-item__icon"><span class="sf-icon" data-icon="${icon}"></span></div><span class="sf-nav-item__badge">${badge}</span></div>`
      : `<div class="sf-nav-item__icon"><span class="sf-icon" data-icon="${icon}"></span></div>`;
    return `<a class="sf-nav-item${isActive ? ' sf-nav-item--active' : ''}" href="${href}">${iconHtml}<span class="sf-nav-item__label">${label}</span></a>`;
  });
  return `          <nav class="sf-bottom-nav">\n            ${items.join('\n            ')}\n          </nav>`;
}

function adminNav(active) {
  const tabs = [
    ['admin-home.html', 'home', 'Home'],
    ['admin-users.html', 'user', 'Users', 2],
    ['admin-offices.html', 'building', 'Offices'],
    ['admin-coa-summary.html', 'list', 'COA summary'],
    ['admin-profile.html', 'tune', 'Profile'],
  ];
  const items = tabs.map(([href, icon, label, badge]) => {
    const isActive = href === active;
    const iconHtml = badge
      ? `<div class="sf-nav-item__icon-wrap"><div class="sf-nav-item__icon"><span class="sf-icon" data-icon="${icon}"></span></div><span class="sf-nav-item__badge">${badge}</span></div>`
      : `<div class="sf-nav-item__icon"><span class="sf-icon" data-icon="${icon}"></span></div>`;
    return `<a class="sf-nav-item${isActive ? ' sf-nav-item--active' : ''}" href="${href}">${iconHtml}<span class="sf-nav-item__label">${label}</span></a>`;
  });
  return `          <nav class="sf-bottom-nav">\n            ${items.join('\n            ')}\n          </nav>`;
}

function page(title, body, nav, noNav) {
  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=414, initial-scale=1" />
  <title>SmartFlow — ${title}</title>
  <link rel="preconnect" href="https://fonts.googleapis.com" />
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />
  <link href="https://fonts.googleapis.com/css2?family=Source+Sans+3:wght@400;500;600;700;800&family=Source+Serif+4:opsz,wght@8..60,600;8..60,700&display=swap" rel="stylesheet" />
  <link rel="stylesheet" href="../../css/tokens.css" />
  <link rel="stylesheet" href="../../css/layout.css" />
  <link rel="stylesheet" href="../../css/components.css" />
</head>
<body class="sf-page">
  <div class="sf-device" id="figma-export">
    <div class="sf-device__shell">
      <div class="sf-device__btn sf-device__btn--silent"></div>
      <div class="sf-device__btn sf-device__btn--vol-up"></div>
      <div class="sf-device__btn sf-device__btn--vol-down"></div>
      <div class="sf-device__btn sf-device__btn--power"></div>
      <div class="sf-device__screen">
${STATUS}
        <div class="sf-phone">
          <div class="sf-phone__scroll${noNav ? ' sf-phone__scroll--no-nav' : ''}">
${body}
          </div>
${nav ? `\n${nav}` : ''}
        </div>
        <div class="sf-home-indicator" aria-hidden="true"></div>
      </div>
    </div>
  </div>
  <script src="../../js/icons.js"></script>
  <script src="../../js/figma-fit.js"></script>
</body>
</html>
`;
}

const headHeader = `            <header class="sf-app-header">
              <div class="sf-app-header__left">
                <div class="sf-eyebrow">MUNICIPALITY OF URBIZTONDO</div>
                <div class="sf-wordmark"><span class="sf-wordmark__smart">SMART</span><span class="sf-wordmark__flow">FLOW</span></div>
              </div>
              <div class="sf-office-badge">ENG</div>
            </header>`;

const adminHeader = `            <header class="sf-app-header">
              <div class="sf-app-header__left">
                <div class="sf-eyebrow">MUNICIPALITY OF URBIZTONDO</div>
                <div class="sf-wordmark"><span class="sf-wordmark__smart">SMART</span><span class="sf-wordmark__flow">FLOW</span></div>
              </div>
              <div class="sf-office-badge">ACC</div>
            </header>`;

// Patch head-home tiles + nav
let headHome = fs.readFileSync(path.join(HEAD, 'head-home.html'), 'utf8');
headHome = headHome
  .replace('<div class="sf-tile">', '<a class="sf-tile" href="head-queue.html" style="text-decoration:none;color:inherit;">', 1)
  .replace('</div>\n            <div class="sf-tile">', '</a>\n            <a class="sf-tile" href="head-alerts.html" style="text-decoration:none;color:inherit;">', 1)
  .replace(/href="#"/g, (m, i, s) => {
    // already fixed tiles; fix nav only
    return m;
  });
headHome = headHome.replace(
  `<a class="sf-nav-item" href="#">
              <div class="sf-nav-item__icon"><span class="sf-icon" data-icon="add"></span></div>
              <span class="sf-nav-item__label">New</span>
            </a>
            <a class="sf-nav-item" href="#">
              <div class="sf-nav-item__icon"><span class="sf-icon" data-icon="list"></span></div>
              <span class="sf-nav-item__label">Queue</span>
            </a>
            <a class="sf-nav-item" href="#">
              <div class="sf-nav-item__icon-wrap">
                <div class="sf-nav-item__icon"><span class="sf-icon" data-icon="alert"></span></div>
                <span class="sf-nav-item__badge">3</span>
              </div>
              <span class="sf-nav-item__label">Alerts</span>
            </a>
            <a class="sf-nav-item" href="#">
              <div class="sf-nav-item__icon"><span class="sf-icon" data-icon="chart"></span></div>
              <span class="sf-nav-item__label">Analytics</span>
            </a>`,
  headNav('head-home.html').trim().replace(/^          /, '').split('\n').slice(1).join('\n            ').replace('head-home.html', 'head-home.html').replace(/sf-nav-item--active" href="head-home.html"/, 'sf-nav-item--active" href="head-home.html"')
);
// Simpler: replace nav block entirely
headHome = fs.readFileSync(path.join(HEAD, 'head-home.html'), 'utf8');
headHome = headHome
  .replace(
    `<div class="sf-tile">
              <div class="sf-tile__icon sf-tile__icon--blue"><span class="sf-icon" data-icon="list"></span></div>
              <div style="flex:1">
                <div class="sf-tile__title">Document queue</div>
                <div class="sf-tile__subtitle">12 active · 2 overdue</div>
              </div>
              <span class="sf-tile__chevron"><span class="sf-icon" data-icon="chevron-right"></span></span>
            </div>
            <div class="sf-tile">
              <div class="sf-tile__icon sf-tile__icon--gold"><span class="sf-icon" data-icon="alert"></span></div>`,
    `<a class="sf-tile" href="head-queue.html" style="text-decoration:none;color:inherit;">
              <div class="sf-tile__icon sf-tile__icon--blue"><span class="sf-icon" data-icon="list"></span></div>
              <div style="flex:1">
                <div class="sf-tile__title">Document queue</div>
                <div class="sf-tile__subtitle">12 active · 2 overdue</div>
              </div>
              <span class="sf-tile__chevron"><span class="sf-icon" data-icon="chevron-right"></span></span>
            </a>
            <a class="sf-tile" href="head-alerts.html" style="text-decoration:none;color:inherit;">
              <div class="sf-tile__icon sf-tile__icon--gold"><span class="sf-icon" data-icon="alert"></span></div>`
  )
  .replace(
    `<span class="sf-tile__chevron"><span class="sf-icon" data-icon="chevron-right"></span></span>
            </div>

            <div class="sf-section-header">
              <span>Staff activity today</span>`,
    `<span class="sf-tile__chevron"><span class="sf-icon" data-icon="chevron-right"></span></span>
            </a>

            <div class="sf-section-header">
              <span>Staff activity today</span>`
  )
  .replace(/<nav class="sf-bottom-nav">[\s\S]*?<\/nav>/, headNav('head-home.html'));
fs.writeFileSync(path.join(HEAD, 'head-home.html'), headHome);

// head-queue
fs.writeFileSync(path.join(HEAD, 'head-queue.html'), page('Head Queue', `${headHeader}

            <div class="sf-overview-card">
              <span class="sf-strap">Document queue</span>
              <h2 class="sf-overview-card__title">Engineering Office queue</h2>
              <p class="sf-overview-card__body">All active documents tied to ENG — overdue, awaiting receive, and on desk now. Monitor-only for department heads.</p>
              <div class="sf-chips">
                <span class="sf-chip">Supervisor view</span>
                <span class="sf-chip sf-chip--eng">Engineering Office (ENG)</span>
              </div>
            </div>

            <div class="sf-stat-row">
              <div class="sf-stat-cell"><div class="sf-stat-cell__value sf-stat-cell__value--green">12</div><div class="sf-stat-cell__label">Active</div></div>
              <div class="sf-stat-cell"><div class="sf-stat-cell__value sf-stat-cell__value--red">2</div><div class="sf-stat-cell__label">Overdue</div></div>
              <div class="sf-stat-cell"><div class="sf-stat-cell__value sf-stat-cell__value--blue">3</div><div class="sf-stat-cell__label">Awaiting<br>receive</div></div>
            </div>

            <div class="sf-filter-chips">
              <span class="sf-filter-chip sf-filter-chip--active">All (12)</span>
              <span class="sf-filter-chip">Overdue (2)</span>
              <span class="sf-filter-chip">Awaiting (3)</span>
              <span class="sf-filter-chip">On desk (4)</span>
            </div>
            <p class="sf-sync-label">Updated 2:31 PM · pull to refresh</p>

            <div class="sf-list-row">
              <div style="flex:1">
                <div class="sf-list-row__title">Infrastructure Voucher #2026-0135</div>
                <div class="sf-list-row__subtitle">OUT to BUD · 2 days · No receive scan</div>
              </div>
              <span class="sf-pill sf-pill--sent">OVERDUE</span>
            </div>
            <div class="sf-list-row">
              <div style="flex:1">
                <div class="sf-list-row__title">#DOC-ENG-2026-0142</div>
                <div class="sf-list-row__subtitle">On desk · Marked IN 2:14 PM</div>
              </div>
              <span class="sf-pill sf-pill--in">IN</span>
            </div>
            <div class="sf-list-row sf-list-row--sent">
              <div style="flex:1">
                <div class="sf-list-row__title">Road repair plans</div>
                <div class="sf-list-row__subtitle">Awaiting receive at ACC · Sent yesterday</div>
              </div>
              <span class="sf-pill sf-pill--warning">AWAITING</span>
            </div>`, headNav('head-queue.html')));

// head-alerts
fs.writeFileSync(path.join(HEAD, 'head-alerts.html'), page('Head Alerts', `${headHeader}

            <div class="sf-overview-card">
              <span class="sf-strap">Supervisor alerts</span>
              <h2 class="sf-overview-card__title">Office follow-ups</h2>
              <p class="sf-overview-card__body">Delayed handoffs and threshold warnings for Engineering — assign follow-up to clerks without scanning yourself.</p>
              <div class="sf-chips">
                <span class="sf-chip">Monitor only</span>
                <span class="sf-chip sf-chip--eng">Engineering Office (ENG)</span>
              </div>
            </div>

            <div class="sf-stat-row">
              <div class="sf-stat-cell"><div class="sf-stat-cell__value sf-stat-cell__value--red">2</div><div class="sf-stat-cell__label">Delayed</div></div>
              <div class="sf-stat-cell"><div class="sf-stat-cell__value" style="color:var(--sf-gold);">1</div><div class="sf-stat-cell__label">Due soon</div></div>
              <div class="sf-stat-cell"><div class="sf-stat-cell__value sf-stat-cell__value--blue">3</div><div class="sf-stat-cell__label">Open</div></div>
            </div>

            <div class="sf-filter-chips">
              <span class="sf-filter-chip sf-filter-chip--active">All (3)</span>
              <span class="sf-filter-chip">Delayed (2)</span>
              <span class="sf-filter-chip">Due soon (1)</span>
            </div>

            <div class="sf-alert-card">
              <strong style="font-size:13px;">Infrastructure Voucher #2026-0135</strong>
              <p style="font-size:11.5px;color:var(--sf-muted);line-height:1.4;margin:6px 0 8px;">DOC-ENG-2026-0135 · OUT from ENG, no receive at BUD · engineering.staff last scan</p>
              <div class="sf-pill-row">
                <span class="sf-pill sf-pill--sent">Needs follow-up</span>
                <span class="sf-pill sf-pill--warning">2 days</span>
              </div>
              <div class="sf-alert-card__actions">
                <button type="button">Assign clerk</button>
                <button type="button">Acknowledge</button>
              </div>
            </div>

            <div class="sf-alert-card sf-alert-card--gold">
              <strong style="font-size:13px;">Road repair plans</strong>
              <p style="font-size:11.5px;color:var(--sf-muted);line-height:1.4;margin:6px 0 8px;">DOC-ENG-2026-0138 · Due within processing threshold</p>
              <div class="sf-pill-row">
                <span class="sf-pill sf-pill--warning">Due soon</span>
                <span class="sf-pill sf-pill--warning">18h left</span>
              </div>
            </div>`, headNav('head-alerts.html')));

// head-analytics
fs.writeFileSync(path.join(HEAD, 'head-analytics.html'), page('Head Analytics', `${headHeader}

            <div class="sf-overview-card">
              <span class="sf-strap">Office analytics</span>
              <h2 class="sf-overview-card__title">Engineering compliance</h2>
              <p class="sf-overview-card__body">On-time, unforwarded, and delayed rates for your office — aligned with COA Table 2.2 pilot metrics.</p>
              <div class="sf-chips">
                <span class="sf-chip">May 2026</span>
                <span class="sf-chip sf-chip--eng">Engineering Office (ENG)</span>
              </div>
            </div>

            <div class="sf-rate-row">
              <div class="sf-rate-box">
                <div class="sf-rate-box__value" style="color: var(--sf-green);">91%</div>
                <div class="sf-rate-box__label">On time</div>
              </div>
              <div class="sf-rate-box">
                <div class="sf-rate-box__value" style="color: var(--sf-gold);">6%</div>
                <div class="sf-rate-box__label">Unforwarded</div>
              </div>
              <div class="sf-rate-box">
                <div class="sf-rate-box__value" style="color: var(--sf-red);">3%</div>
                <div class="sf-rate-box__label">Delayed</div>
              </div>
            </div>

            <div class="sf-section-header"><span>By document type</span></div>
            <div class="sf-list-row">
              <div style="flex:1"><div class="sf-list-row__title">Disbursement Voucher</div><div class="sf-list-row__subtitle">18 active · 94% on time</div></div>
            </div>
            <div class="sf-list-row">
              <div style="flex:1"><div class="sf-list-row__title">Infrastructure Plans</div><div class="sf-list-row__subtitle">6 active · 86% on time</div></div>
            </div>

            <div class="sf-section-header"><span>Staff scan volume (today)</span></div>
            <div class="sf-stat-row">
              <div class="sf-stat-cell"><div class="sf-stat-cell__value sf-stat-cell__value--green">14</div><div class="sf-stat-cell__label">Received</div></div>
              <div class="sf-stat-cell"><div class="sf-stat-cell__value sf-stat-cell__value--red">9</div><div class="sf-stat-cell__label">Sent</div></div>
              <div class="sf-stat-cell"><div class="sf-stat-cell__value sf-stat-cell__value--blue">4</div><div class="sf-stat-cell__label">Clerks<br>active</div></div>
            </div>
            <p class="sf-sync-label">Updated 2:31 PM · municipal pilot data</p>`, headNav('head-analytics.html')));

// head-register
fs.writeFileSync(path.join(HEAD, 'head-register.html'), page('Head Register', `${headHeader}

            <div class="sf-overview-card">
              <span class="sf-strap">Register document</span>
              <h2 class="sf-overview-card__title">Register on behalf of office</h2>
              <p class="sf-overview-card__body">Heads can register urgent folders at Engineering when clerks are unavailable — clerks still handle day-to-day scans.</p>
              <div class="sf-chips">
                <span class="sf-chip">Head override</span>
                <span class="sf-chip sf-chip--eng">Engineering Office (ENG)</span>
              </div>
            </div>

            <div class="sf-form-card">
              <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:16px;">
                <span style="font-size:12px;font-weight:600;color:var(--sf-muted);">Origin office</span>
                <span class="sf-dept-badge sf-dept-badge--eng">ENG · Engineering Office</span>
              </div>
              <div class="sf-field">
                <label>DOCUMENT TITLE</label>
                <input type="text" value="Infrastructure Voucher - Barangay San Gregorio" />
              </div>
              <div class="sf-field sf-select-field">
                <label>DOCUMENT TYPE</label>
                <select><option selected>Disbursement Voucher</option></select>
              </div>
              <div class="sf-field">
                <label>REFERENCE / DV NO.</label>
                <input type="text" value="DV-2026-0143" />
              </div>
              <button class="sf-btn-primary" type="button">Register &amp; get QR ID</button>
            </div>`, headNav('head-register.html')));

// Patch admin-home
let adminHome = fs.readFileSync(path.join(ADMIN, 'admin-home.html'), 'utf8');
adminHome = adminHome
  .replace(
    `<div class="sf-tile">
              <div class="sf-tile__icon sf-tile__icon--blue"><span class="sf-icon" data-icon="users"></span></div>
              <div style="flex:1">
                <div class="sf-tile__title">User management</div>
                <div class="sf-tile__subtitle">2 sign-up request(s) awaiting approval.</div>
              </div>
              <span class="sf-tile__chevron"><span class="sf-icon" data-icon="chevron-right"></span></span>
            </div>
            <div class="sf-tile">
              <div class="sf-tile__icon sf-tile__icon--green"><span class="sf-icon" data-icon="tune"></span></div>`,
    `<a class="sf-tile" href="admin-users.html" style="text-decoration:none;color:inherit;">
              <div class="sf-tile__icon sf-tile__icon--blue"><span class="sf-icon" data-icon="users"></span></div>
              <div style="flex:1">
                <div class="sf-tile__title">User management</div>
                <div class="sf-tile__subtitle">2 sign-up request(s) awaiting approval.</div>
              </div>
              <span class="sf-tile__chevron"><span class="sf-icon" data-icon="chevron-right"></span></span>
            </a>
            <a class="sf-tile" href="admin-thresholds.html" style="text-decoration:none;color:inherit;">
              <div class="sf-tile__icon sf-tile__icon--green"><span class="sf-icon" data-icon="tune"></span></div>`
  )
  .replace(
    `<span class="sf-tile__chevron"><span class="sf-icon" data-icon="chevron-right"></span></span>
            </div>

            <div class="sf-section-header">
              <span>Compliance rates — May 2026</span>`,
    `<span class="sf-tile__chevron"><span class="sf-icon" data-icon="chevron-right"></span></span>
            </a>

            <div class="sf-section-header">
              <span>Compliance rates — May 2026</span>`
  )
  .replace(/<nav class="sf-bottom-nav">[\s\S]*?<\/nav>/, adminNav('admin-home.html'));
fs.writeFileSync(path.join(ADMIN, 'admin-home.html'), adminHome);

// admin-users
fs.writeFileSync(path.join(ADMIN, 'admin-users.html'), page('Admin Users', `${adminHeader}

            <div class="sf-overview-card">
              <span class="sf-strap">User management</span>
              <h2 class="sf-overview-card__title">Accounts &amp; sign-ups</h2>
              <p class="sf-overview-card__body">Approve pending LGU sign-ups, assign office and role, and deactivate accounts when staff transfer out.</p>
              <div class="sf-chips">
                <span class="sf-chip sf-chip--gold">2 pending sign-up</span>
                <span class="sf-chip">LGU IT · ACC</span>
              </div>
            </div>

            <div class="sf-section-header"><span>Pending approval</span></div>
            <div class="sf-list-row">
              <div style="flex:1">
                <div class="sf-list-row__title">Engr. Juan Dela Cruz</div>
                <div class="sf-list-row__subtitle">engineering.head · ENG · Head</div>
              </div>
              <span class="sf-pill sf-pill--warning">PENDING</span>
            </div>
            <div class="sf-list-row">
              <div style="flex:1">
                <div class="sf-list-row__title">Maria Reyes</div>
                <div class="sf-list-row__subtitle">budget.staff · BUD · Employee</div>
              </div>
              <span class="sf-pill sf-pill--warning">PENDING</span>
            </div>

            <div class="sf-section-header"><span>Active users (pilot)</span></div>
            <div class="sf-list-row">
              <div style="flex:1">
                <div class="sf-list-row__title">engineering.staff</div>
                <div class="sf-list-row__subtitle">ENG · Employee · Last login today</div>
              </div>
            </div>
            <div class="sf-list-row">
              <div style="flex:1">
                <div class="sf-list-row__title">acc.admin</div>
                <div class="sf-list-row__subtitle">ACC · Admin · Last login today</div>
              </div>
            </div>`, adminNav('admin-users.html')));

// admin-offices
fs.writeFileSync(path.join(ADMIN, 'admin-offices.html'), page('Admin Offices', `${adminHeader}

            <div class="sf-overview-card">
              <span class="sf-strap">Pilot offices</span>
              <h2 class="sf-overview-card__title">Office registry</h2>
              <p class="sf-overview-card__body">COA pilot offices ENG · HR · BUD · ACC — codes, heads, and active document counts.</p>
              <div class="sf-chips">
                <span class="sf-chip">4 pilot offices</span>
                <span class="sf-chip">Municipal admin</span>
              </div>
            </div>

            <div class="sf-list-row">
              <div style="flex:1">
                <div class="sf-list-row__title">Engineering Office</div>
                <div class="sf-list-row__subtitle">ENG · 12 active docs · Head: Engr. Santos</div>
              </div>
              <span class="sf-pill sf-pill--in">ENG</span>
            </div>
            <div class="sf-list-row">
              <div style="flex:1">
                <div class="sf-list-row__title">Budget Office</div>
                <div class="sf-list-row__subtitle">BUD · 9 active docs · Head: Ms. Garcia</div>
              </div>
              <span class="sf-pill sf-pill--in">BUD</span>
            </div>
            <div class="sf-list-row">
              <div style="flex:1">
                <div class="sf-list-row__title">Accounting Office</div>
                <div class="sf-list-row__subtitle">ACC · 14 active docs · COA liaison</div>
              </div>
              <span class="sf-pill sf-pill--in">ACC</span>
            </div>
            <div class="sf-list-row">
              <div style="flex:1">
                <div class="sf-list-row__title">Human Resource Office</div>
                <div class="sf-list-row__subtitle">HR · 7 active docs</div>
              </div>
              <span class="sf-pill sf-pill--in">HR</span>
            </div>`, adminNav('admin-offices.html')));

// admin-coa-summary
fs.writeFileSync(path.join(ADMIN, 'admin-coa-summary.html'), page('Admin COA Summary', `${adminHeader}

            <div class="sf-overview-card">
              <span class="sf-strap">COA summary</span>
              <h2 class="sf-overview-card__title">Municipal compliance report</h2>
              <p class="sf-overview-card__body">Month-end export for Commission on Audit — on-time, unforwarded, and delayed rates across pilot offices.</p>
              <div class="sf-chips">
                <span class="sf-chip">May 2026</span>
                <span class="sf-chip">Table 2.2 metrics</span>
              </div>
            </div>

            <div class="sf-rate-row">
              <div class="sf-rate-box">
                <div class="sf-rate-box__value" style="color: var(--sf-green);">87%</div>
                <div class="sf-rate-box__label">On time</div>
              </div>
              <div class="sf-rate-box">
                <div class="sf-rate-box__value" style="color: var(--sf-gold);">8%</div>
                <div class="sf-rate-box__label">Unforwarded</div>
              </div>
              <div class="sf-rate-box">
                <div class="sf-rate-box__value" style="color: var(--sf-red);">5%</div>
                <div class="sf-rate-box__label">Delayed</div>
              </div>
            </div>

            <div class="sf-section-header"><span>By office</span></div>
            <div class="sf-list-row">
              <div style="flex:1"><div class="sf-list-row__title">Engineering (ENG)</div><div class="sf-list-row__subtitle">91% on time · 12 active</div></div>
            </div>
            <div class="sf-list-row">
              <div style="flex:1"><div class="sf-list-row__title">Budget (BUD)</div><div class="sf-list-row__subtitle">84% on time · 9 active</div></div>
            </div>
            <div class="sf-list-row">
              <div style="flex:1"><div class="sf-list-row__title">Accounting (ACC)</div><div class="sf-list-row__subtitle">88% on time · 14 active</div></div>
            </div>

            <button class="sf-btn-primary" type="button" style="margin-top:14px;">Export PDF summary</button>`, adminNav('admin-coa-summary.html')));

// admin-profile
fs.writeFileSync(path.join(ADMIN, 'admin-profile.html'), page('Admin Profile', `${adminHeader}

            <div class="sf-overview-card">
              <span class="sf-strap">Admin profile</span>
              <h2 class="sf-overview-card__title">Municipal Accountant</h2>
              <p class="sf-overview-card__body">System admin / Accounting Head session — configure thresholds, approve users, and run COA exports.</p>
              <div class="sf-chips">
                <span class="sf-chip">Admin</span>
                <span class="sf-chip">ACC · LGU IT</span>
              </div>
            </div>

            <div class="sf-form-card">
              <div style="display:flex;gap:14px;margin-bottom:14px;">
                <div class="sf-profile-avatar">MA</div>
                <div style="flex:1;">
                  <p style="font-weight:800;font-size:14px;margin-bottom:10px;">Account</p>
                  <div class="sf-summary-row"><span class="sf-summary-row__key">Role</span><span class="sf-summary-row__val">Admin / Accounting Head</span></div>
                  <div class="sf-summary-row"><span class="sf-summary-row__key">Username</span><span class="sf-summary-row__val">acc.admin</span></div>
                </div>
              </div>
            </div>

            <a class="sf-tile" href="admin-thresholds.html" style="text-decoration:none;color:inherit;">
              <div class="sf-tile__icon sf-tile__icon--green"><span class="sf-icon" data-icon="tune"></span></div>
              <div style="flex:1"><div class="sf-tile__title">Processing thresholds</div><div class="sf-tile__subtitle">FR-4 · max hours per office</div></div>
              <span class="sf-tile__chevron"><span class="sf-icon" data-icon="chevron-right"></span></span>
            </a>

            <div class="sf-logout-card">
              <div class="sf-logout-card__title">Log out</div>
              <div class="sf-logout-card__sub">Sign out and clear local session on this device.</div>
            </div>`, adminNav('admin-profile.html')));

// admin-thresholds (no bottom nav — sub-page)
fs.writeFileSync(path.join(ADMIN, 'admin-thresholds.html'), page('Admin Thresholds', `${adminHeader}
            <a class="sf-back" href="admin-home.html"><span class="sf-icon" data-icon="arrow-left"></span> Back</a>

            <div class="sf-overview-card">
              <span class="sf-strap">FR-4 thresholds</span>
              <h2 class="sf-overview-card__title">Processing limits</h2>
              <p class="sf-overview-card__body">Set max hours before a document is flagged unforwarded or delayed — per office and document type.</p>
            </div>

            <div class="sf-form-card">
              <div class="sf-field sf-select-field">
                <label>OFFICE</label>
                <select><option selected>Engineering (ENG)</option><option>Budget (BUD)</option><option>Accounting (ACC)</option><option>HR</option></select>
              </div>
              <div class="sf-field sf-select-field">
                <label>DOCUMENT TYPE</label>
                <select><option selected>Disbursement Voucher</option><option>Infrastructure Plans</option></select>
              </div>
              <div class="sf-field">
                <label>MAX HOURS ON DESK</label>
                <input type="text" value="48" />
              </div>
              <div class="sf-field">
                <label>MAX HOURS UNFORWARDED (OUT)</label>
                <input type="text" value="24" />
              </div>
              <button class="sf-btn-primary" type="button">Save threshold</button>
            </div>`, null, true));

console.log('POV pages generated');
