/**
 * One-shot: fill web-mock desktop pages. Run: node web-mock/scripts/gen-pages.js
 */
const fs = require('fs');
const path = require('path');

const root = path.join(__dirname, '..');
const seal = '../../assets/brand/urbiztondo_seal.png';
const fonts =
  'https://fonts.googleapis.com/css2?family=Source+Sans+3:wght@400;600;700;800&family=Source+Serif+4:opsz,wght@8..60,700&display=swap';

function doc(title, body) {
  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=1280" />
  <title>${title}</title>
  <link href="${fonts}" rel="stylesheet" />
  <link rel="stylesheet" href="../../css/tokens.css" />
  <link rel="stylesheet" href="../../css/layout.css" />
</head>
<body class="sf-web-page">
${body}
</body>
</html>
`;
}

function shell({ office, code, nav, active, title, sub, main }) {
  const links = nav
    .map((n) => `<a class="${n === active ? 'is-active' : ''}" href="#">${n}</a>`)
    .join('');
  return doc(
    'SmartFlow Web — ' + title,
    `
  <div class="sf-web-canvas" id="figma-export">
    <header class="sf-web-topbar">
      <img src="${seal}" width="34" height="34" alt="" />
      <div><div class="sf-web-topbar__office">${office}</div><div class="sf-web-topbar__brand"><span>Smart</span><span>Flow</span></div></div>
      <div class="sf-web-topbar__spacer"></div><span class="sf-web-badge">${code}</span>
    </header>
    <div class="sf-web-body">
      <nav class="sf-web-nav">${links}</nav>
      <main class="sf-web-main">
        <h1 class="sf-web-title">${title}</h1>
        <p class="sf-web-sub">${sub}</p>
        ${main}
      </main>
    </div>
  </div>`,
  );
}

const staffNav = ['Home', 'Scan', 'Register', 'Requests', 'History', 'Alerts', 'Profile'];
const headNav = ['Home', 'Queue', 'Alerts', 'Analytics', 'Register', 'History', 'Profile'];
const adminNav = [
  'Home',
  'Scan',
  'COA',
  'Users',
  'Offices',
  'Thresholds',
  'QR monitor',
  'System',
  'Profile',
];

function put(rel, html) {
  const p = path.join(root, rel);
  fs.mkdirSync(path.dirname(p), { recursive: true });
  fs.writeFileSync(p, html);
  console.log('wrote', rel);
}

const authHero = (extra = '') => `
  <div class="sf-web-canvas" id="figma-export">
    <div class="sf-web-auth">
      <div class="sf-web-auth__hero">
        <img src="${seal}" width="56" height="56" alt="" style="margin-bottom:16px;" />
        <div style="font-family:var(--sf-display);font-size:28px;font-weight:700;">Smart<span style="color:#93c5fd;">Flow</span></div>
        <p style="margin-top:12px;opacity:0.85;font-size:14px;max-width:34ch;">QR custody tracking for the Municipality of Urbiztondo.</p>
        ${extra}
      </div>`;

put(
  'pages/auth/get-started.html',
  doc(
    'SmartFlow Web — Get Started',
    authHero() +
      `
      <div class="sf-web-auth__form-wrap">
        <h1 class="sf-web-title">Get started</h1>
        <p class="sf-web-sub">Sign in with your municipal account, or request access.</p>
        <button class="sf-web-btn" type="button" style="width:100%;margin-bottom:10px;">Sign in</button>
        <button class="sf-web-btn sf-web-btn--outline" type="button" style="width:100%;">Request access</button>
      </div>
    </div>
  </div>`,
  ),
);

put(
  'pages/auth/signup.html',
  doc(
    'SmartFlow Web — Sign up',
    authHero() +
      `
      <div class="sf-web-auth__form-wrap">
        <h1 class="sf-web-title">Request access</h1>
        <p class="sf-web-sub">Step 1 of 2 · Your details</p>
        <div class="sf-web-field"><label>Full name</label><input value="Juan Dela Cruz" /></div>
        <div class="sf-web-field"><label>Email</label><input value="jdelacruz@urbiztondo.gov.ph" /></div>
        <div class="sf-web-field"><label>Username</label><input value="jdelacruz" /></div>
        <button class="sf-web-btn" type="button" style="width:100%;">Continue</button>
      </div>
    </div>
  </div>`,
  ),
);

put(
  'pages/auth/signup-step2.html',
  doc(
    'SmartFlow Web — Sign up · Office',
    authHero() +
      `
      <div class="sf-web-auth__form-wrap">
        <h1 class="sf-web-title">Office &amp; role</h1>
        <p class="sf-web-sub">Step 2 of 2</p>
        <div class="sf-web-field"><label>Office</label><select><option>Budget Office (BUD)</option><option>Engineering (ENG)</option></select></div>
        <div class="sf-web-field"><label>Role</label><select><option>Clerk</option><option>Head</option></select></div>
        <div class="sf-web-field"><label>Password</label><input type="password" value="password" /></div>
        <button class="sf-web-btn sf-web-btn--navy" type="button" style="width:100%;">Submit for approval</button>
      </div>
    </div>
  </div>`,
  ),
);

put(
  'pages/auth/signup-pending.html',
  doc(
    'SmartFlow Web — Pending',
    authHero() +
      `
      <div class="sf-web-auth__form-wrap">
        <h1 class="sf-web-title">Pending approval</h1>
        <p class="sf-web-sub">Sent to the municipal accountant. Sign in after approval.</p>
        <div class="sf-web-card"><strong>Juan Dela Cruz</strong><div style="font-size:12px;color:var(--sf-muted);margin-top:4px;">@jdelacruz · Clerk · BUD</div></div>
        <button class="sf-web-btn sf-web-btn--outline" type="button" style="width:100%;margin-top:12px;">Back to sign in</button>
      </div>
    </div>
  </div>`,
  ),
);

put(
  'pages/auth/forgot-password.html',
  doc(
    'SmartFlow Web — Forgot password',
    authHero() +
      `
      <div class="sf-web-auth__form-wrap">
        <h1 class="sf-web-title">Forgot password</h1>
        <p class="sf-web-sub">Enter username or email.</p>
        <div class="sf-web-field"><label>Username or email</label><input placeholder="engineering.staff" /></div>
        <button class="sf-web-btn" type="button" style="width:100%;">Send reset link</button>
      </div>
    </div>
  </div>`,
  ),
);

put(
  'pages/staff/staff-scan-mark-in.html',
  shell({
    office: 'Engineering Office',
    code: 'ENG',
    nav: staffNav,
    active: 'Scan',
    title: 'Scan · Mark IN',
    sub: 'Folder arrived at your desk.',
    main: `<div class="sf-web-card" style="max-width:560px;">
    <div style="font-size:11px;font-weight:800;color:var(--sf-blue);margin-bottom:8px;">DOCUMENT LOADED</div>
    <div style="font-weight:800;">DOC-2026-000003</div>
    <div style="font-size:12px;color:var(--sf-muted);margin:4px 0 12px;">DV — Barangay San Gregorio road repair</div>
    <div style="font-size:12px;margin-bottom:12px;padding:10px;background:rgba(29,78,216,0.08);border-radius:10px;">Secured QR verified · HMAC OK</div>
    <button class="sf-web-btn" type="button" style="width:100%;">Mark IN</button>
  </div>`,
  }),
);

put(
  'pages/staff/staff-scan-mark-out.html',
  shell({
    office: 'Engineering Office',
    code: 'ENG',
    nav: staffNav,
    active: 'Scan',
    title: 'Scan · Mark OUT',
    sub: 'Send folder to the next office.',
    main: `<div class="sf-web-card" style="max-width:560px;">
    <div style="font-weight:800;">DOC-2026-000003</div>
    <div style="font-size:12px;color:var(--sf-muted);margin:4px 0 12px;">Currently IN at Engineering</div>
    <div class="sf-web-field"><label>Next office</label><select><option selected>Budget Office (BUD) — suggested</option><option>Accounting (ACC)</option></select></div>
    <button class="sf-web-btn" type="button" style="width:100%;">Mark OUT</button>
  </div>`,
  }),
);

put(
  'pages/staff/staff-scan-blocked.html',
  shell({
    office: 'Engineering Office',
    code: 'ENG',
    nav: staffNav,
    active: 'Scan',
    title: 'Scan · Blocked',
    sub: 'This folder is not actionable at ENG right now.',
    main: `<div class="sf-web-card" style="max-width:560px;border-left:4px solid var(--sf-gold);">
    <strong>Forwarded · awaiting receive</strong>
    <p style="font-size:12px;color:var(--sf-muted);margin:8px 0 0;line-height:1.45;">DOC-2026-000001 was sent to Budget. Wait for BUD to Mark IN.</p>
    <button class="sf-web-btn sf-web-btn--outline" type="button" style="margin-top:12px;">Back to scanner</button>
  </div>`,
  }),
);

put(
  'pages/staff/staff-register-success.html',
  shell({
    office: 'Engineering Office',
    code: 'ENG',
    nav: staffNav,
    active: 'Register',
    title: 'DOC-2026-000012',
    sub: 'Print the QR label and attach it to the folder.',
    main: `<div style="display:grid;grid-template-columns:220px 1fr;gap:16px;max-width:640px;">
    <div class="sf-web-card" style="text-align:center;padding:24px;">
      <div style="width:140px;height:140px;margin:0 auto;background:#0f172a;border-radius:8px;"></div>
      <div style="font-size:11px;margin-top:10px;color:var(--sf-muted);">Secured QR · 180-day expiry</div>
    </div>
    <div class="sf-web-card">
      <div style="font-size:12px;"><strong>Type</strong> · Disbursement Voucher</div>
      <div style="font-size:12px;margin-top:6px;"><strong>Title</strong> · Covered court expansion</div>
      <button class="sf-web-btn" type="button" style="margin-top:14px;width:100%;">Print / Save QR</button>
      <button class="sf-web-btn sf-web-btn--outline" type="button" style="margin-top:8px;width:100%;">Register another</button>
    </div>
  </div>`,
  }),
);

put(
  'pages/staff/staff-requests.html',
  shell({
    office: 'Budget Office',
    code: 'BUD',
    nav: staffNav,
    active: 'Requests',
    title: 'Requests',
    sub: 'Accepting does not move the folder — register or scan when it arrives.',
    main: `<div class="sf-web-card">
    <div style="display:flex;gap:8px;margin-bottom:12px;font-size:12px;font-weight:700;">
      <span style="padding:6px 10px;background:rgba(29,78,216,0.12);border-radius:8px;color:var(--sf-blue);">Inbox (1)</span>
      <span style="padding:6px 10px;border-radius:8px;border:1px solid var(--sf-border);">My requests</span>
    </div>
    <strong style="font-size:13px;">Need approved budget allocation for Barangay San Gregorio road repair</strong>
    <div style="font-size:11px;color:var(--sf-muted);margin:6px 0 10px;">#REQ-2026-0018 · From ENG · Budget (access)</div>
    <div style="padding:8px 10px;background:rgba(29,78,216,0.06);border-radius:8px;font-size:11px;font-weight:700;margin-bottom:10px;">Required by Jun 10, 2026</div>
    <button class="sf-web-btn" type="button">Accept</button>
    <button class="sf-web-btn sf-web-btn--outline" type="button">Decline</button>
  </div>`,
  }),
);

put(
  'pages/staff/staff-requests-mine.html',
  shell({
    office: 'Engineering Office',
    code: 'ENG',
    nav: staffNav,
    active: 'Requests',
    title: 'My requests',
    sub: 'Tickets you opened for other offices.',
    main: `<div class="sf-web-card"><table class="sf-web-table">
    <thead><tr><th>ID</th><th>To</th><th>Title</th><th>Status</th></tr></thead>
    <tbody>
      <tr><td>#REQ-2026-0018</td><td>BUD</td><td>Budget allocation</td><td><span class="sf-web-pill sf-web-pill--warn">Pending</span></td></tr>
      <tr><td>#REQ-2026-0012</td><td>ACC</td><td>DV review</td><td><span class="sf-web-pill sf-web-pill--in">Accepted</span></td></tr>
    </tbody></table></div>`,
  }),
);

put(
  'pages/staff/staff-requests-create.html',
  shell({
    office: 'Engineering Office',
    code: 'ENG',
    nav: staffNav,
    active: 'Requests',
    title: 'New request',
    sub: 'Ask another office for a document or action. Does not move custody.',
    main: `<div class="sf-web-card" style="max-width:520px;">
    <div class="sf-web-field"><label>Category</label><select><option>Budget</option><option>Disbursement Voucher</option><option>Others</option></select></div>
    <div class="sf-web-field"><label>To office</label><select><option>Budget (BUD)</option><option>Accounting (ACC)</option></select></div>
    <div class="sf-web-field"><label>Title / need</label><input value="Need approved budget allocation" /></div>
    <div class="sf-web-field"><label>Required by</label><input type="date" value="2026-06-10" /></div>
    <button class="sf-web-btn sf-web-btn--navy" type="button" style="width:100%;">Submit request</button>
  </div>`,
  }),
);

put(
  'pages/staff/staff-history-trail.html',
  shell({
    office: 'Engineering Office',
    code: 'ENG',
    nav: staffNav,
    active: 'History',
    title: 'Custody trail',
    sub: 'DOC-2026-000003 · DV — Barangay San Gregorio',
    main: `<div class="sf-web-card"><table class="sf-web-table">
    <thead><tr><th>Action</th><th>Office</th><th>By</th><th>When</th></tr></thead>
    <tbody>
      <tr><td><span class="sf-web-pill sf-web-pill--in">IN</span></td><td>Engineering</td><td>A. Cruz</td><td>Today 9:12 AM</td></tr>
      <tr><td><span class="sf-web-pill sf-web-pill--out">OUT</span></td><td>to Budget</td><td>A. Cruz</td><td>Yesterday 4:20 PM</td></tr>
      <tr><td><span class="sf-web-pill sf-web-pill--in">IN</span></td><td>Budget</td><td>M. Santos</td><td>Yesterday 2:05 PM</td></tr>
      <tr><td><span class="sf-web-pill sf-web-pill--out">OUT</span></td><td>to Engineering</td><td>Registered</td><td>Sep 24 11:40 AM</td></tr>
    </tbody></table></div>`,
  }),
);

put(
  'pages/staff/staff-profile.html',
  shell({
    office: 'Engineering Office',
    code: 'ENG',
    nav: staffNav,
    active: 'Profile',
    title: 'Profile',
    sub: 'Your office account and desk stats.',
    main: `<div class="sf-web-card" style="max-width:520px;">
    <div style="display:flex;gap:14px;align-items:center;">
      <div style="width:64px;height:64px;border-radius:14px;background:linear-gradient(135deg,var(--sf-gold),var(--sf-blue));color:#fff;display:flex;align-items:center;justify-content:center;font-weight:800;">AC</div>
      <div><div style="font-weight:800;font-size:16px;">Ana Cruz</div><div style="font-size:12px;">Clerk · Engineering (ENG)</div><div style="font-size:12px;color:var(--sf-muted);">@acruz</div></div>
    </div>
    <div class="sf-web-stat-row" style="margin-top:14px;">
      <div class="sf-web-stat"><div class="sf-web-stat__value sf-web-stat__value--green">4</div><div class="sf-web-stat__label">Received</div></div>
      <div class="sf-web-stat"><div class="sf-web-stat__value">2</div><div class="sf-web-stat__label">Sent</div></div>
      <div class="sf-web-stat"><div class="sf-web-stat__value sf-web-stat__value--blue">3</div><div class="sf-web-stat__label">On desk</div></div>
    </div>
    <button class="sf-web-btn sf-web-btn--navy" type="button" style="width:100%;margin-top:8px;">Account &amp; security</button>
  </div>`,
  }),
);

put(
  'pages/staff/staff-profile-security.html',
  shell({
    office: 'Engineering Office',
    code: 'ENG',
    nav: staffNav,
    active: 'Profile',
    title: 'Account &amp; security',
    sub: 'Photo, name, email, password, or sign out.',
    main: `<div class="sf-web-card" style="max-width:520px;">
    <div class="sf-web-field"><label>Name</label><input value="Ana Cruz" /></div>
    <div class="sf-web-field"><label>Email</label><input value="acruz@urbiztondo.gov.ph" /></div>
    <button class="sf-web-btn sf-web-btn--outline" type="button" style="width:100%;margin-bottom:8px;">Change password</button>
    <button class="sf-web-btn sf-web-btn--outline" type="button" style="width:100%;color:var(--sf-red);">Sign out</button>
  </div>`,
  }),
);

put(
  'pages/head/head-alerts.html',
  shell({
    office: 'Engineering Office',
    code: 'ENG',
    nav: headNav,
    active: 'Alerts',
    title: 'Alerts',
    sub: 'Overdue folders, or OUT from ENG with no receive yet.',
    main: `<div class="sf-web-stat-row">
    <div class="sf-web-stat"><div class="sf-web-stat__value sf-web-stat__value--red">1</div><div class="sf-web-stat__label">Delayed</div></div>
    <div class="sf-web-stat"><div class="sf-web-stat__value">0</div><div class="sf-web-stat__label">Due soon</div></div>
    <div class="sf-web-stat"><div class="sf-web-stat__value sf-web-stat__value--blue">1</div><div class="sf-web-stat__label">Unconfirmed</div></div>
  </div>
  <div class="sf-web-card" style="border-left:4px solid var(--sf-red);">
    <strong>DV — San Gregorio</strong> · DOC-2026-000003 · 52h
    <div style="margin-top:10px;"><button class="sf-web-btn" type="button">Open</button> <button class="sf-web-btn sf-web-btn--outline" type="button">Later</button></div>
  </div>`,
  }),
);

put(
  'pages/head/head-analytics.html',
  shell({
    office: 'Engineering Office',
    code: 'ENG',
    nav: headNav,
    active: 'Analytics',
    title: 'Analytics',
    sub: 'On-time rate and slow documents for your office.',
    main: `<div class="sf-web-stat-row">
    <div class="sf-web-stat"><div class="sf-web-stat__value sf-web-stat__value--green">78%</div><div class="sf-web-stat__label">On time</div></div>
    <div class="sf-web-stat"><div class="sf-web-stat__value sf-web-stat__value--blue">12%</div><div class="sf-web-stat__label">Unforwarded</div></div>
    <div class="sf-web-stat"><div class="sf-web-stat__value sf-web-stat__value--red">10%</div><div class="sf-web-stat__label">Delayed</div></div>
  </div>
  <div class="sf-web-card">
    <h3 style="margin:0 0 8px;font-size:13px;">Slow documents · September 2026</h3>
    <table class="sf-web-table"><thead><tr><th>ID</th><th>Type</th><th>Hours</th></tr></thead>
    <tbody><tr><td>DOC-2026-000003</td><td>DV</td><td>52h</td></tr><tr><td>DOC-2026-000009</td><td>POW</td><td>40h</td></tr></tbody></table>
  </div>`,
  }),
);

put(
  'pages/head/head-register.html',
  shell({
    office: 'Engineering Office',
    code: 'ENG',
    nav: headNav,
    active: 'Register',
    title: 'Register',
    sub: 'New folder for your office. Print the QR and attach it.',
    main: `<div class="sf-web-card" style="max-width:520px;">
    <div class="sf-web-field"><label>Document type</label><select><option>Disbursement Voucher</option><option>Others</option></select></div>
    <div class="sf-web-field"><label>Title</label><input /></div>
    <button class="sf-web-btn sf-web-btn--navy" type="button" style="width:100%;">Register &amp; get QR</button>
  </div>`,
  }),
);

put(
  'pages/admin/admin-offices.html',
  shell({
    office: 'Accounting Office',
    code: 'ACC',
    nav: adminNav,
    active: 'Offices',
    title: 'Offices',
    sub: 'Municipal offices in the SmartFlow deployment.',
    main: `<div class="sf-web-card"><table class="sf-web-table">
    <thead><tr><th>Office</th><th>Code</th><th>Processed</th><th>In office</th><th>Overdue</th></tr></thead>
    <tbody>
      <tr><td>Engineering</td><td>ENG</td><td>14</td><td>3</td><td>2</td></tr>
      <tr><td>Budget</td><td>BUD</td><td>11</td><td>2</td><td>0</td></tr>
      <tr><td>Accounting</td><td>ACC</td><td>9</td><td>4</td><td>1</td></tr>
      <tr><td>Treasury</td><td>TRE</td><td>7</td><td>1</td><td>0</td></tr>
      <tr><td>Mayor's Office</td><td>MAY</td><td>5</td><td>2</td><td>2</td></tr>
      <tr><td>HR</td><td>HR</td><td>2</td><td>0</td><td>0</td></tr>
    </tbody></table></div>`,
  }),
);

put(
  'pages/admin/admin-thresholds.html',
  shell({
    office: 'Accounting Office',
    code: 'ACC',
    nav: adminNav,
    active: 'Thresholds',
    title: 'Thresholds',
    sub: 'Max hours per office and document type.',
    main: `<div class="sf-web-card" style="max-width:520px;">
    <div class="sf-web-field"><label>Office</label><select><option>Engineering (ENG)</option></select></div>
    <div class="sf-web-field"><label>Document type</label><input value="Disbursement Voucher" /></div>
    <div class="sf-web-field"><label>Max processing hours</label><input value="48" /></div>
    <button class="sf-web-btn sf-web-btn--navy" type="button" style="width:100%;">Save threshold</button>
  </div>`,
  }),
);

put(
  'pages/admin/admin-qr-monitor.html',
  shell({
    office: 'Accounting Office',
    code: 'ACC',
    nav: adminNav,
    active: 'QR monitor',
    title: 'QR monitor',
    sub: 'Accepted and rejected scans (last 48 hours).',
    main: `<div class="sf-web-stat-row">
    <div class="sf-web-stat"><div class="sf-web-stat__value sf-web-stat__value--green">86</div><div class="sf-web-stat__label">Accepted</div></div>
    <div class="sf-web-stat"><div class="sf-web-stat__value sf-web-stat__value--red">7</div><div class="sf-web-stat__label">Rejected</div></div>
    <div class="sf-web-stat"><div class="sf-web-stat__value">93</div><div class="sf-web-stat__label">Total</div></div>
  </div>
  <div class="sf-web-card"><table class="sf-web-table">
    <thead><tr><th>Outcome</th><th>Document</th><th>Office</th><th>Reason</th></tr></thead>
    <tbody>
      <tr><td><span class="sf-web-pill sf-web-pill--in">OK</span></td><td>DOC-2026-000003</td><td>ENG</td><td>—</td></tr>
      <tr><td><span class="sf-web-pill sf-web-pill--out">Reject</span></td><td>DOC-2026-000011</td><td>ENG</td><td>HMAC expired</td></tr>
    </tbody></table></div>`,
  }),
);

put(
  'pages/admin/admin-system.html',
  shell({
    office: 'Accounting Office',
    code: 'ACC',
    nav: adminNav,
    active: 'System',
    title: 'System',
    sub: 'API and database health.',
    main: `<div class="sf-web-card" style="display:flex;justify-content:space-between;align-items:center;">
    <div><strong>API / PHP</strong><div style="font-size:12px;color:var(--sf-muted);">Online · PHP 8.2.12</div></div>
    <span class="sf-web-pill sf-web-pill--in">online</span>
  </div>
  <div class="sf-web-card"><div class="sf-web-stat-row" style="margin:0;">
    <div class="sf-web-stat"><div class="sf-web-stat__value">18</div><div class="sf-web-stat__label">Active users</div></div>
    <div class="sf-web-stat"><div class="sf-web-stat__value">42</div><div class="sf-web-stat__label">Scans today</div></div>
    <div class="sf-web-stat"><div class="sf-web-stat__value">2</div><div class="sf-web-stat__label">Pending</div></div>
  </div></div>`,
  }),
);

put(
  'pages/admin/admin-profile.html',
  shell({
    office: 'Accounting Office',
    code: 'ACC',
    nav: adminNav,
    active: 'Profile',
    title: 'Profile',
    sub: 'Your municipal account.',
    main: `<div class="sf-web-card" style="max-width:520px;">
    <div style="font-weight:800;font-size:16px;">Liza Mendoza</div>
    <div style="font-size:12px;margin-top:4px;">Admin · Accounting (ACC) · @lmendoza</div>
    <div class="sf-web-stat-row" style="margin-top:14px;">
      <div class="sf-web-stat"><div class="sf-web-stat__value sf-web-stat__value--blue">48</div><div class="sf-web-stat__label">Active</div></div>
      <div class="sf-web-stat"><div class="sf-web-stat__value sf-web-stat__value--red">5</div><div class="sf-web-stat__label">Overdue</div></div>
      <div class="sf-web-stat"><div class="sf-web-stat__value">2</div><div class="sf-web-stat__label">Pending</div></div>
    </div>
  </div>`,
  }),
);

console.log('done');
