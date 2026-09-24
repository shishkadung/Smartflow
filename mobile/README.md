# SmartFlow Mobile (Rebuild)

Flutter + Jetpack Compose apps aligned with **Capstone SmartFlow.pdf** and the PHP API in `backend/backend/api/`.

**Design PDF:** see [`../docs/design/PDF-README.md`](../docs/design/PDF-README.md) — how to view the PDF and extract readable screens for Cursor/AI.

## Quick start (already done on this machine)

```powershell
.\scripts\sync-backend-to-xampp.ps1   # after any backend edit (always use this)
.\scripts\setup-smartflow.ps1         # sync + seed users + test API
.\scripts\run-flutter.ps1             # sync then run Flutter app
```

- **API (browser):** http://localhost/Smartflow/backend/backend/api  
- **Flutter SDK:** `C:\src\flutter` (on user PATH after `install-flutter-path.ps1`)  
- **Backend sync:** project `backend\backend` → `C:\xampp\htdocs\Smartflow\backend\backend` (mirror)  

## Prerequisites

1. **XAMPP** — Apache + MySQL running; schema imported; `setup-smartflow.ps1` seeds demo users.
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

Open `mobile/android` in Android Studio → Sync Gradle → Run on emulator/device.

Configure API: `app/src/main/java/com/urbiztondo/smartflow/data/ApiConfig.kt`

## Capstone team accounts (after `setup-smartflow.ps1` / `dev-replace-team-users.php`)

Default password: `smartflow123` — change before production.

| Username | Who | Office | Role |
|----------|-----|--------|------|
| `kristofer.eng` | Fernandez, Kristofer Cyle | ENG | staff |
| `angel.bud` | Buenaventura, Angel A. | BUD | staff |
| `rainier.hr` | Fallarcuna, Rainier B. | HR | staff |
| `krizandra.tre` | Basit, Krizandra Josephine L. | TRE | staff |
| `neil.acc.staff` | Pascua, Neil John A. | ACC | staff |
| `neil.admin` | Pascua, Neil John A. | ACC | admin |
| `neil.may.staff` | Pascua, Neil John A. | MAY | staff |

(Also: `neil.acc.head`, `neil.may.head`.)

See `docs/defense/START-HERE.md` for the DV demo order.

## Clerk (frontline) test flow

1. Log in with your pilot account
2. **New** — register a document at your office (auto **IN** at origin) → copy tracking ID / print QR link
3. **Scan** — lookup by ID or QR → **Mark IN** / **Mark OUT** when forwarding
4. **Home** — counts and tray; **History** / **Alerts** as needed

Bottom nav: **Home · Scan · New · History · Alerts** — profile via office badge (top-right)

Any **staff** or **head** can register documents for **their own office only**.

To remove old demo documents from an earlier setup:  
`GET http://localhost/Smartflow/backend/backend/api/dev-purge-demo-documents.php`

## Document requests (inter-office)

After any backend change, sync to XAMPP (otherwise the app shows **Invalid server response** / API not found):

```powershell
.\scripts\sync-backend-to-xampp.ps1
```

The `document_requests` table is created automatically on first API call.

Logic guide: `docs/product/DOCUMENT-REQUESTS-LOGIC.md`  
In app: **Home → Document requests** (Inbox / My requests).

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Invalid server response | `.\scripts\sync-backend-to-xampp.ps1` then restart Apache |
| Errors after editing PHP | Sync + `.\scripts\setup-smartflow.ps1` (health check) |
| Could not create document | Sync backend (ID collision fix) |
| Cannot reach API | XAMPP on; emulator → `10.0.2.2` in `api_config.dart` |
| Health check | http://localhost/Smartflow/backend/backend/api/dev-api-health.php |

## Figma screen map

- **Shared:** Login, Sign-up (3 steps), Pending, Approved
- **Clerk:** Dashboard, Scanner, Audit trail, Alerts, Profile
- **Head:** Dashboard, Queue, Alerts, Analytics, Profile
- **Admin:** Dashboard, Offices, Users, System status, Thresholds, COA reports, Profile
