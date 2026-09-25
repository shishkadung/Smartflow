const fs = require('fs');
const path = require('path');

const ROOT = path.join(__dirname, '..');
const PAGES = path.join(ROOT, 'pages');

const MOVES = [
  ['get-started.html', 'auth/get-started.html'],
  ['login.html', 'auth/login.html'],
  ['signup.html', 'auth/signup.html'],
  ['signup-step2.html', 'auth/signup-step2.html'],
  ['signup-pending.html', 'auth/signup-pending.html'],
  ['staff-home.html', 'employee/staff-home.html'],
  ['staff-scan.html', 'employee/staff-scan.html'],
  ['staff-register.html', 'employee/staff-register.html'],
  ['staff-register-success.html', 'employee/staff-register-success.html'],
  ['staff-history.html', 'employee/staff-history.html'],
  ['staff-alerts.html', 'employee/staff-alerts.html'],
  ['staff-profile.html', 'employee/staff-profile.html'],
  ['staff-requests.html', 'employee/staff-requests.html'],
  ['head-home.html', 'head/head-home.html'],
  ['admin-home.html', 'admin/admin-home.html'],
];

function patchHtml(text) {
  return text
    .replace(/href="\.\.\/css\//g, 'href="../../css/')
    .replace(/src="\.\.\/js\//g, 'src="../../js/');
}

for (const [from, to] of MOVES) {
  const src = path.join(PAGES, from);
  const dest = path.join(PAGES, to);
  if (!fs.existsSync(src)) {
    console.log('skip (missing):', from);
    continue;
  }
  fs.mkdirSync(path.dirname(dest), { recursive: true });
  let content = fs.readFileSync(src, 'utf8');
  content = patchHtml(content);
  fs.writeFileSync(dest, content, 'utf8');
  fs.unlinkSync(src);
  console.log('moved:', from, '->', to);
}

console.log('done');
