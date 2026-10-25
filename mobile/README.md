# SmartFlow Mobile (Rebuild)

Flutter + Jetpack Compose apps aligned with **Capstone SmartFlow.pdf** and the PHP API in `backend/backend/api/`.

**Design PDF:** see [`../docs/design/PDF-README.md`](../docs/design/PDF-README.md) — how to view the PDF and extract readable screens for Cursor/AI.

## Quick start (already done on this machine)

```powershell
.\scripts\fix-api.ps1                 # read-only API reachability check
.\scripts\run-flutter.ps1             # run the Flutter app (inspect the script first)
```

`setup-smartflow.ps1` is retired: it used to replace accounts and purge folders, and now stops with an error. Deploying reviewed PHP to XAMPP is a separate explicit step (`.\scripts\sync-backend-to-xampp.ps1 -WhatIf` first; it never copies `.env`).

- **API (browser):** http://localhost/Smartflow/backend/backend/api  
- **Flutter SDK:** `C:\src\flutter` (on user PATH after `install-flutter-path.ps1`)  
- **Backend sync:** project `backend\backend` → `C:\xampp\htdocs\Smartflow\backend\backend`, only when you deliberately run the sync script  

## Prerequisites

1. **XAMPP** — Apache + MySQL running; schema created by the API's runtime bootstrap or imported from `backend/backend/api-schema.sql`. Use existing accounts; the seed and purge scripts no longer run from a browser.
2. **API URL** — Apps use `http://10.0.2.2/Smartflow/backend/backend/api` on emulator.

| Environment | Base URL (example) |
|-------------|-------------------|
| Android emulator | `http://10.0.2.2/Smartflow/backend/backend/api` |
| Physical phone (same Wi‑Fi) | `http://192.168.x.x/Smartflow/backend/backend/api` |

Edit `ApiConfig` in each app before testing.

## Flutter (`flutter/`)

```bash
cd mobile/flutter
flutter pub get
flutter run
```

Configure API: `lib/config/api_config.dart` or run with:

```bash
flutter run --dart-define=API_BASE=http://10.0.2.2/.../backend/backend/api
```

### iOS

The `ios/` shell is updated for current plugins (camera, photo QR/profile, LAN HTTP). See [`flutter/ios/README.md`](flutter/ios/README.md).

**Requires a Mac + Xcode** to run or ship. From Windows you can edit Dart + `Info.plist` / `Podfile`, but you cannot install on an iPhone from this PC.
## Jetpack Compose (`android/`)

Not part of this checkout: only the Flutter client exists (`mobile/flutter/`).

## Accounts

Use an existing approved account. The older shared `smartflow123` team logins no longer exist in the local demo database, and a shared default password must never exist on a deployed system. Demo credentials are kept in a restricted login sheet and stay out of documents. See [`docs/defense/CORRECTIONS-2026-10-25.md`](../docs/defense/CORRECTIONS-2026-10-25.md) and the [sample-data guide](../docs/client/DEMO-DATA-2026-10-22.md) for the demo.

## Clerk (frontline) test flow

1. Log in with your pilot account
2. **New** — register a document at your office (auto **IN** at origin) → copy tracking ID / print QR link
3. **Scan** — lookup by ID or QR → **Mark IN** / **Mark OUT** when forwarding
4. **Home** — counts and tray; **History** / **Alerts** as needed

Bottom nav: **Home · Scan · New · History · Alerts** — profile via office badge (top-right)

Any **staff** or **head** can register documents for **their own office only**.

Do not purge documents from a browser: `dev-purge-demo-documents.php` is a command-line maintenance script and never runs over HTTP.

## Document requests (inter-office)

If the app shows **Invalid server response** / API not found, first run `.\scripts\fix-api.ps1` (read-only) and check Apache, MySQL and the API address. Only if reviewed PHP changes need to reach XAMPP, run `.\scripts\sync-backend-to-xampp.ps1 -WhatIf` and then, with your approval, the real sync.

The `document_requests` table is created automatically on first API call.

Logic guide: `docs/product/DOCUMENT-REQUESTS-LOGIC.md`  
In app: **Home → Document requests** (Inbox / My requests).

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Invalid server response | `.\scripts\fix-api.ps1`; check Apache, MySQL and the API address; restart Apache if needed |
| Errors after editing PHP | Deploy the reviewed change deliberately (see above), then run `.\scripts\fix-api.ps1` |
| Cannot reach API | XAMPP on; emulator → `10.0.2.2` in `api_config.dart` |
| Health check | `.\scripts\fix-api.ps1` (the old `dev-api-health.php` URL no longer runs over HTTP) |

## Figma screen map

- **Shared:** Login, Sign-up (3 steps), Pending, Approved
- **Clerk:** Dashboard, Scanner, Audit trail, Alerts, Profile
- **Head:** Dashboard, Queue, Alerts, Analytics, Profile
- **Admin:** Dashboard, Offices, Users, System status, Thresholds, COA reports, Profile
