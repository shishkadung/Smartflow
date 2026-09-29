const fs = require("fs");
const path = require("path");

const root = path.join(__dirname);
const outDir = path.join(root, "_figma-batch");
fs.mkdirSync(outDir, { recursive: true });

function minifyCss(s) {
  return s
    .replace(/\/\*[\s\S]*?\*\//g, "")
    .replace(/\s+/g, " ")
    .replace(/\s*([{}:;,])\s*/g, "$1")
    .trim();
}

const css =
  minifyCss(fs.readFileSync(path.join(root, "css/tokens.css"), "utf8")) +
  minifyCss(fs.readFileSync(path.join(root, "css/layout.css"), "utf8")) +
  minifyCss(fs.readFileSync(path.join(root, "css/components.css"), "utf8"));

const boardCss = minifyCss(`
  html, body {
    margin: 0 !important;
    padding: 0 !important;
    background: #eef2f7 !important;
    min-height: 0 !important;
  }
  body.sf-page {
    display: block !important;
    align-items: stretch !important;
    justify-content: flex-start !important;
    padding: 0 !important;
    background: #eef2f7 !important;
    min-height: 0 !important;
  }
  .sf-figma-board {
    display: flex;
    flex-wrap: wrap;
    align-items: flex-start;
    gap: 24px;
    margin: 0;
    padding: 0;
    background: #eef2f7;
  }
  .sf-figma-board__item {
    width: var(--sf-screen-w);
    flex: 0 0 auto;
    margin: 0;
    padding: 0;
  }
  .sf-figma-board__label {
    font: 700 12px/1.2 var(--sf-font);
    color: var(--sf-blue);
    margin: 0 0 8px;
  }
  .sf-device, .sf-device__shell, .sf-device__screen {
    margin: 0;
  }
`);

const sealSvg =
  "data:image/svg+xml," +
  encodeURIComponent(
    '<svg xmlns="http://www.w3.org/2000/svg" width="72" height="72"><circle cx="36" cy="36" r="34" fill="#0b3d5c"/></svg>'
  );

const screens = [
  ["Auth · Get Started", "pages/auth/get-started.html"],
  ["Auth · Login", "pages/auth/login.html"],
  ["Auth · Sign Up", "pages/auth/signup.html"],
  ["Auth · Pending Approval", "pages/auth/signup-pending.html"],
  ["Employee · Desk Home", "pages/employee/staff-home.html"],
  ["Employee · Scan", "pages/employee/staff-scan.html"],
  ["Employee · Mark IN", "pages/employee/staff-scan-mark-in.html"],
  ["Employee · Mark OUT", "pages/employee/staff-scan-mark-out.html"],
  ["Employee · Register", "pages/employee/staff-register.html"],
  ["Employee · Register Success", "pages/employee/staff-register-success.html"],
  ["Employee · History", "pages/employee/staff-history.html"],
  ["Employee · Alerts", "pages/employee/staff-alerts.html"],
  ["Employee · Requests", "pages/employee/staff-requests.html"],
  ["Employee · Profile", "pages/employee/staff-profile.html"],
  ["Head · Office overview", "pages/head/head-home.html"],
  ["Head · Queue", "pages/head/head-queue.html"],
  ["Head · Alerts", "pages/head/head-alerts.html"],
  ["Head · Analytics", "pages/head/head-analytics.html"],
  ["Admin · Dashboard", "pages/admin/admin-home.html"],
  ["Admin · Users", "pages/admin/admin-users.html"],
  ["Admin · Offices", "pages/admin/admin-offices.html"],
  ["Admin · COA summary", "pages/admin/admin-coa-summary.html"],
  ["Admin · Thresholds", "pages/admin/admin-thresholds.html"],
  ["Admin · QR monitor", "pages/admin/admin-qr-monitor.html"],
];

/** Secondary flows — separate Figma HTML so core boards stay under the 32-screen cap */
const extras = [
  ["Extras · Signup step 2", "pages/auth/signup-step2.html"],
  ["Extras · Scan blocked", "pages/employee/staff-scan-lookup-blocked.html"],
  ["Extras · History trail", "pages/employee/staff-history-trail.html"],
  ["Extras · Requests create", "pages/employee/staff-requests-create.html"],
  ["Extras · Requests mine", "pages/employee/staff-requests-mine.html"],
  ["Extras · Account & security", "pages/employee/staff-profile-security.html"],
  ["Extras · Employee menu", "pages/employee/staff-menu.html"],
  ["Extras · Head menu", "pages/head/head-menu.html"],
  ["Extras · Head register", "pages/head/head-register.html"],
  ["Extras · Admin menu", "pages/admin/admin-menu.html"],
  ["Extras · Admin profile", "pages/admin/admin-profile.html"],
  ["Extras · Admin system", "pages/admin/admin-system.html"],
];

const allScreens = screens.concat(extras);

const roles = [
  {
    key: "Auth",
    file: "Auth-board.html",
    title: "SmartFlow — Auth (Figma)",
    items: screens.filter(([n]) => n.startsWith("Auth ·")),
  },
  {
    key: "Employee",
    file: "Employee-board.html",
    title: "SmartFlow — Employee (Figma)",
    items: screens.filter(([n]) => n.startsWith("Employee ·")),
  },
  {
    key: "Head",
    file: "Head-board.html",
    title: "SmartFlow — Head (Figma)",
    items: screens.filter(([n]) => n.startsWith("Head ·")),
  },
  {
    key: "Admin",
    file: "Admin-board.html",
    title: "SmartFlow — Admin (Figma)",
    items: screens.filter(([n]) => n.startsWith("Admin ·")),
  },
  {
    key: "Extras",
    file: "Extras-board.html",
    title: "SmartFlow — Extras (Figma)",
    items: extras,
  },
];

function preparePage(rel) {
  return fs
    .readFileSync(path.join(root, rel), "utf8")
    .replace(/<link rel="stylesheet"[^>]*>/g, "")
    .replace(/<script[\s\S]*?<\/script>/gi, "")
    .replace(/\.\.\/\.\.\/assets\/brand\/urbiztondo_seal\.png/g, sealSvg)
    .replace(/src="\.\.\/\.\.\/assets\/[^"]+"/g, 'src="' + sealSvg + '"');
}

function extractDevice(html) {
  const m = html.match(/<div class="sf-device"[^>]*id="figma-export"[\s\S]*$/);
  if (!m) throw new Error("missing #figma-export");
  // trim trailing scripts already removed; close at last device root by finding matching end before </body>
  const bodyEnd = html.lastIndexOf("</body>");
  const chunk = html.slice(html.indexOf('<div class="sf-device"'), bodyEnd);
  // Remove trailing closing noise — keep through final </div> of sf-device
  const open = chunk.indexOf('<div class="sf-device"');
  let depth = 0;
  let i = open;
  let end = -1;
  while (i < chunk.length) {
    const nextOpen = chunk.indexOf("<div", i);
    const nextClose = chunk.indexOf("</div>", i);
    if (nextClose === -1) break;
    if (nextOpen !== -1 && nextOpen < nextClose) {
      depth++;
      i = nextOpen + 4;
    } else {
      depth--;
      i = nextClose + 6;
      if (depth === 0) {
        end = i;
        break;
      }
    }
  }
  if (end === -1) throw new Error("unbalanced sf-device");
  return chunk.slice(open, end);
}

const manifest = [];

for (const [name, rel] of allScreens) {
  let html = preparePage(rel);
  html = html
    .replace('body class="sf-page"', 'body class="sf-page sf-page--embed"')
    .replace("</head>", "<style>" + css + boardCss + "</style></head>");

  const safe = name.replace(/[^\w]+/g, "-").replace(/^-|-$/g, "");
  const file = path.join(outDir, safe + ".html");
  fs.writeFileSync(file, html);
  manifest.push({ name, file, bytes: Buffer.byteLength(html) });
}

for (const role of roles) {
  const itemsHtml = role.items
    .map(([name, rel]) => {
      const device = extractDevice(preparePage(rel));
      const label = name.replace(/^[^·]+·\s*/, "");
      return (
        '<div class="sf-figma-board__item">' +
        '<p class="sf-figma-board__label">' +
        label +
        "</p>" +
        device +
        "</div>"
      );
    })
    .join("\n");

  const doc =
    "<!DOCTYPE html>\n" +
    '<html lang="en">\n' +
    "<head>\n" +
    '  <meta charset="UTF-8" />\n' +
    '  <meta name="viewport" content="width=device-width, initial-scale=1" />\n' +
    "  <title>" +
    role.title +
    "</title>\n" +
    '  <link rel="preconnect" href="https://fonts.googleapis.com" />\n' +
    '  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />\n' +
    '  <link href="https://fonts.googleapis.com/css2?family=Source+Sans+3:wght@400;500;600;700;800&family=Source+Serif+4:opsz,wght@8..60,600;8..60,700&display=swap" rel="stylesheet" />\n' +
    "  <style>" +
    css +
    boardCss +
    "</style>\n" +
    "</head>\n" +
    '<body class="sf-page sf-page--embed">\n' +
    '  <div class="sf-figma-board" id="figma-export">\n' +
    itemsHtml +
    "\n  </div>\n" +
    "</body>\n" +
    "</html>\n";

  const out = path.join(outDir, role.file);
  fs.writeFileSync(out, doc);
  manifest.push({
    name: role.key + " board",
    file: out,
    bytes: Buffer.byteLength(doc),
    screens: role.items.length,
  });

  // Convenience copies for extension import
  const galleryCopy = path.join(root, "galleries", role.key.toLowerCase() + "-figma.html");
  fs.writeFileSync(galleryCopy, doc);
}

fs.writeFileSync(path.join(outDir, "manifest.json"), JSON.stringify(manifest, null, 2));
console.log(
  "singles",
  allScreens.length,
  "boards",
  roles.map((r) => r.key + "=" + r.items.length).join(" ")
);
console.log(
  "maxBytes",
  Math.max(...manifest.map((x) => x.bytes)),
  "totalKB",
  Math.round(manifest.reduce((a, x) => a + x.bytes, 0) / 1024)
);
