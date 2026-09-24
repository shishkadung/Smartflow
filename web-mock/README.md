# SmartFlow — HTML/CSS UI Mock (for Figma)

Static **414px device frames** for Figma — twin of Flutter mobile chrome:

- Logo: Urbiztondo seal + **Smart**/**Flow** (Source Serif 4, navy/blue)
- Nav: floating pill — staff `Home · Scan↑ · Alerts · Menu` (same pattern for head/admin)

## Quick start

1. Open `index.html` in Chrome.
2. Pick a POV: **Employee**, **Head**, **Admin**, or **Auth**.
3. Open any screen full-size → capture for Figma.

## POV galleries

| Gallery | Folder | Role |
|---------|--------|------|
| [Auth](galleries/auth.html) | `pages/auth/` | Get Started, Login, Sign up, Pending |
| [Employee](galleries/employee.html) | `pages/employee/` | Clerk — scan, register, history, alerts, requests |
| [Head](galleries/head.html) | `pages/head/` | Department Head — queue, alerts, analytics |
| [Admin](galleries/admin.html) | `pages/admin/` | Municipal Accountant — users, offices, COA support |

## Canonical captions (keep in sync)

| Screen | Title | Body |
|--------|-------|------|
| Get Started / Login welcome | Inter-office document tracking | Secure QR handoffs… COA preparation |
| Login form | Sign in | Municipal account · custody logged |
| Desk | Desk | Today’s received, sent, and folders on desk. |
| Scan | Scan folder QR | Look up a folder, then Mark IN or Mark OUT. |
| Register | Register a document folder | Only when the folder is already in your custody. |
| History | History | Look up every IN and OUT scan by tracking ID. |
| Alerts | Alerts | Overdue IN, or OUT from {office} with no receive yet. |
| Requests | Document requests | Accepting does not move the folder — register or scan when it arrives. |

Strap on **auth only**: `Official portal · Authorized users`. Ops screens: **no** cream strap / chip row / nav hint.

Frame size: **414 px wide**, height **grows with content**. No inner scroll.

## Import into Figma

1. Open a screen from a POV gallery in Chrome.
2. **DevTools:** Right-click `#figma-export` → Capture node screenshot.
3. Or use **html.to.design** plugin with the local file URL.

Design tokens: `css/tokens.css`

## Source of truth

- Live web: `web/src/pages/` + `web/src/sf-life.css`
- Flutter captions: `mobile/flutter/lib/utils/format_time.dart`
- Theme: `mobile/flutter/lib/theme/smartflow_theme.dart`
- Vocabulary: `docs/product/POLISH-CHECKLIST.md`
