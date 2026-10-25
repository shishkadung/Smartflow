# SmartFlow Capstone Project

**Title:** SmartFlow: A QR-Based Inter-Department Document Flow Tracking and COA Compliance System for the Municipality of Urbiztondo

**Researchers:**
- Pascua, Neil John A.
- Basit, Krizandra Josephine L.
- Buenaventura, Angel A.
- Fallarcuna, Rainier B.
- Fernandez, Kristofer Cyle

**Current product context:** [`docs/PRD.md`](docs/PRD.md) — implemented behavior, requirements and open gaps.  
**Eight-document context bundle:** [`docs/README.md`](docs/README.md#smartflow-context-bundle) · **AI project guide:** [`AGENTS.md`](AGENTS.md).  
**Approved academic proposal:** [`docs/thesis/proposal.md`](docs/thesis/proposal.md).  
**Docs map:** [`docs/README.md`](docs/README.md) — pick one folder for the job; do not browse everything.

---

## What SmartFlow does

Tracks **physical** inter-office folders with secured QR labels (Register → Scan IN/OUT). It is **not** a financial approval or payment system.

| Item | Detail |
|------|--------|
| Client | Municipality of Urbiztondo |
| Pilot offices | **ENG, HR, BUD, ACC, TRE, MAY** |
| Primary docs | Disbursement Voucher (DV), Approved Budget |
| Payroll | Payslip **access** only — no payroll folder QR |
| Key path (DV) | **ENG → BUD → ACC → TRE → MAY → TRE** (check release) |
| Requests | Formal tickets; ACC accepts DV tickets → **Treasury** marks payment released |
| Validated with | Municipal Accountant (see [`docs/client/`](docs/client/)) |

**3 rules:** folder not on your desk → **Request**; folder on your desk → **Register + Scan**; holder office registers.

---

## Quick start for teammates (work in progress)

> **Status:** work in progress. Layout and flows were reviewed on sample data and an emulator; they are **not** yet tested with real folders on a real phone, and there is no production hosting. Use demo accounts only in isolated local testing; never reuse demo passwords for real accounts.

**You need:** XAMPP (Apache + MySQL/MariaDB + PHP 8.1 or newer), Node.js (current LTS), Flutter 3.44 or newer with Dart 3.12 or newer, and Android Studio with an emulator (for mobile).

### 1. Backend (PHP API + database)

1. Put this project's `backend/` folder where Apache serves it, so the API answers at
   `http://localhost/Smartflow/backend/backend/api/` (for example copy or link the project to `C:\xampp\htdocs\Smartflow`).
2. In phpMyAdmin, create an empty database named `smartflow` (utf8mb4), then import `backend/backend/api-schema.sql`.
3. In the `backend/backend/api/` directory Apache serves, copy `.env.example` to `.env` and set `DB_*` (XAMPP defaults are `root` with an empty password) and `ALLOW_DEV_TOOLS=true` for step 4. If XAMPP serves a separate copy, configure its `.env` there; the sync script does not copy private configuration. Leave `QR_SIGNING_SECRET` empty locally: the API creates its own private `.qr-secret` file on first use (it is git-ignored). **Never commit `.env` or `.qr-secret`.** Leave `SMTP_*` empty unless you are testing password-reset emails.
4. Create demo accounts once, from a terminal in the served project's root (needs `ALLOW_DEV_TOOLS=true` in `.env`; refuses to run over the web):
   `C:\xampp\php\php.exe backend/backend/api/dev-seed-demo-users.php --allow-maintenance`
   It is safe to repeat (existing usernames are skipped). Do not run any `dev-reset-*` or purge script against data you want to keep.
5. After editing PHP in your working folder, copy it to XAMPP with `scripts/sync-backend-to-xampp.ps1` (add `-WhatIf` first to see what would change). It never copies `.env`.

### 2. Web (React + Vite)

```bash
cd web
npm install
npm run dev
```

Open `http://localhost:5173`. The dev server proxies `/smartflow-api` to `http://127.0.0.1/Smartflow/backend/backend/api`, so step 1 must work first. Sample-data pages (no backend needed, nothing is saved): `http://localhost:5173/ui-review.html?role=staff` (also `head`, `admin`; add `&state=empty`, `error`, `long` or `volume`).

### 3. Mobile (Flutter, Android emulator)

```bash
cd mobile/flutter
flutter pub get
flutter run --dart-define=API_BASE=http://10.0.2.2/Smartflow/backend/backend/api --dart-define=FORCE_LOGIN_ON_START=false
```

`10.0.2.2` is how the emulator reaches your PC. Run Flutter commands from `mobile/flutter/`, not the project root.

### 4. Checks

```bash
cd web && node --test --test-concurrency=1 test/*.test.mjs && npm run build
cd ../mobile/flutter && flutter analyze && flutter test
```

API checks use a disposable database and are described in [`docs/TESTING.md`](docs/TESTING.md). Do **not** run `scripts/smoke-test.ps1` against a database you care about.

### 5. Working together

- Work on a branch, open a pull request, and merge into `main` only after review.
- Never commit `.env`, backups, `.qr-secret`, uploaded avatars or the local `.runtime/` folder (all ignored).
- Start with [`docs/PRD.md`](docs/PRD.md), then [`AGENTS.md`](AGENTS.md) (rules about custody, permissions and what not to change). Layout review notes are in [`docs/product/WEB-UX-OBJECTIVES-2026-10-18.md`](docs/product/WEB-UX-OBJECTIVES-2026-10-18.md); open questions for the client are in [`docs/product/CLIENT-QUESTIONS-2026-10-19.md`](docs/product/CLIENT-QUESTIONS-2026-10-19.md).

---

## Run the app (defense / demo)

For the existing local data, start the protected development API from this workspace with `./scripts/start-api-dev.ps1`. It serves `http://127.0.0.1:8000/backend/backend/api` through the restricted router, without syncing or reseeding records. The Android emulator uses `http://10.0.2.2:8000/backend/backend/api`. Use the current [Architecture](docs/ARCHITECTURE.md#local-runtime-and-addresses) and [Testing](docs/TESTING.md) instructions; older defense/setup commands below can copy code or change data and must be inspected before use. Do not serve this repository with an unguarded PHP document root.

`flutter run` **does not work** in the project root — use `mobile/flutter/`.

**Defense (one command):**

```powershell
cd "C:\Users\nljhn\Downloads\SmartFlow"
.\scripts\run-defense-demo.ps1
```

This only runs the read-only `fix-api.ps1` reachability check and prints reminders.

Read first: **[`docs/defense/DEFENSE-CHECKLIST.md`](docs/defense/DEFENSE-CHECKLIST.md)** and **[`docs/defense/CORRECTIONS-2026-10-25.md`](docs/defense/CORRECTIONS-2026-10-25.md)** (older defense notes contain retired commands and old accounts).

```powershell
.\scripts\run-flutter.ps1
```

Or manually:

```powershell
cd mobile/flutter
flutter pub get
flutter run
```

Use your existing approved account. Password recovery uses the registered email; launch scripts do not create demo logins or reset passwords.

If the app shows **API not found**:

```powershell
.\scripts\fix-api.ps1
```

Then in XAMPP: **Stop → Start** Apache, hot restart Flutter (`R`).

For local use, start the existing services and the protected API without seeding or replacing data:

```powershell
.\scripts\start-api-dev.ps1
```

The legacy automatic setup and HTTP purge helpers are retired. Keep working accounts, sessions, folders and QR material. Use the disposable API harness in [Testing](docs/TESTING.md) for sample workflows; reviewed code deployment is a separate explicit step.

---

## Folder layout

| Folder | Contents |
|--------|----------|
| **`mobile/flutter/`** | Flutter app — **run here** |
| **`web/`** | React web portal |
| `backend/backend/api/` | PHP API (source); deployed to XAMPP or a host only deliberately (`.env.production.example` is the production template) |
| `docs/` | Thesis, defense, client interview, product |
| `docs/thesis/files/` | Paper PDF/Word files, template, highlighted revision PDFs |
| `scripts/` | Launch, build, backup/restore and verification helpers, plus the isolated API test suites (`test-*.php`); inspect a script before running it, some modify data (`smoke-test.ps1`) |
| `backups/` | Local system snapshots and private demo login sheets (never deploy or share) |
| `.runtime/` | Local evidence and reports from earlier work (large; never deploy or commit) |

Older notes mention `mobile-mock/`, `web-mock/`, `mobile/android/`, `thesis-work/` and `_archive/`; those folders are not in this checkout.

Do not reshuffle folders right before defense — paths break easily.

---

## Document map

| Folder | Open when |
|--------|-----------|
| [`docs/defense/`](docs/defense/) | Demo / panel |
| [`docs/thesis/`](docs/thesis/) | Paper / Word |
| [`docs/product/`](docs/product/) | App rules + production deploy |
| [`docs/client/`](docs/client/) | Accountant interview → implementation |
| [`docs/design/`](docs/design/) | Figma PDF, diagrams, use cases |
| [`docs/product/PRODUCTION-DEPLOYMENT.md`](docs/product/PRODUCTION-DEPLOYMENT.md) | Deploying the API, web portal and Android release |

**Figma PDF:** [`docs/design/Capstone SmartFlow.pdf`](docs/design/Capstone%20SmartFlow.pdf) · how-to: [`docs/design/PDF-README.md`](docs/design/PDF-README.md)

---

## Seven specific objectives

1. QR tagging module per financial document at origin
2. Scan-and-forward tracking (audit trail)
3. Real-time dashboard (location, time at office, overdue)
4. Automated delay alerts
5. COA-aligned summary reports (monthly / quarterly / annual)
6. Department performance analytics
7. Usability and effectiveness evaluation (Accounting, heads, frontline)
