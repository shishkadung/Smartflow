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

## Run the app (defense / demo)

For the existing local data, start the protected development API from this workspace with `./scripts/start-api-dev.ps1`. It serves `http://127.0.0.1:8000/backend/backend/api` through the restricted router, without syncing or reseeding records. The Android emulator uses `http://10.0.2.2:8000/backend/backend/api`. Use the current [Architecture](docs/ARCHITECTURE.md#local-runtime-and-addresses) and [Testing](docs/TESTING.md) instructions; older defense/setup commands below can copy code or change data and must be inspected before use. Do not serve this repository with an unguarded PHP document root.

`flutter run` **does not work** in the project root — use `mobile/flutter/`.

**Defense (one command):**

```powershell
cd "C:\Users\nljhn\Downloads\Capstone -Neil"
.\scripts\run-defense-demo.ps1
```

Read first: **[`docs/defense/START-HERE.md`](docs/defense/START-HERE.md)**

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
| **`mobile-mock/`** | Phone HTML twins (Flutter → Figma) |
| **`web-mock/`** | Desktop HTML twins (React → Figma) |
| `mobile/android/` | Jetpack Compose (optional second client) |
| `backend/backend/api/` | PHP API (source) → sync to XAMPP |
| `docs/` | Thesis, defense, client interview, product |
| `docs/thesis/files/` | Paper PDF/Word files, template, highlighted revision PDFs |
| `scripts/` | `run-flutter.ps1`, `sync-backend-to-xampp.ps1`, `smoke-test.ps1`, setup; `scripts/figures/` generates thesis figures |
| **`thesis-work/`** | Dated folders (`YYYY-MM-DD_Topic`) for figures, DFDs, and paper revision outputs |
| `_archive/` | Unused files — ignore |

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
| [`_archive/`](_archive/) | Old copies — ignore |

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
