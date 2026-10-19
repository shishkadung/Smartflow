# SmartFlow — Pre-defense checklist (bukas)

**Basahin ito tonight.** Sundin ang order. Password lahat: `smartflow123`

---

## Tonight (30–45 min)

### 1. Start XAMPP
- [ ] Apache **ON** (green)
- [ ] MySQL **ON** (green)

### 2. One command prep
```powershell
cd "C:\Users\nljhn\Downloads\Capstone 1 -Neil"
.\scripts\run-defense-demo.ps1
```
Dapat: **Health OK**, login OK.

Kung fail → buksan XAMPP, ulitin.

### 3. Seed users (kung first time / walang login)
Browser:  
`http://localhost/Smartflow/backend/backend/api/dev-seed-demo-users.php`

Dapat may **`neil.acc.staff`** — ito ang mag-**scan** sa Accounting, **hindi** `neil.admin`.

### 4. Purge old test data (optional pero recommended)
`http://localhost/Smartflow/backend/backend/api/dev-purge-demo-documents.php?all=1`

### 5. Rehearse **full demo** (main + security)

Sundin: **[DEMO-SCENARIOS-COMPLETE.md](DEMO-SCENARIOS-COMPLETE.md)**

| # | Login | Gawin |
|---|--------|--------|
| 1 | `kristofer.eng` | **New** DV → **secured QR** → scan **verified** → **OUT** → BUD |
| 2 | `angel.bud` | **IN** → **OUT** → ACC |
| 3 | `neil.acc.staff` | **IN** → **History** |
| 4 | `kristofer.eng` | Duplicate **IN** → dapat **reject** |
| 5 | `kristofer.eng` | OUT to BUD, ENG try **IN** → **reject** |
| 6 | `kristofer.eng` | Tampered QR paste (1 char) → **reject** |
| 7 | `neil.admin` | **QR scan monitor** + **Copy CSV** |
| 8 | `neil.admin` | **COA report** (optional) |

**Sabihin:** *“DV trail hanggang Treasury at Mayor (TRE → MAY → TRE); payment release is marked by Treasury on the request ticket. Secured QR + audit monitor para sa panel.”*

### 6. Rehearse **budget demo** (backup, 5 min)

| # | Login | Gawin |
|---|--------|--------|
| 1 | `kristofer.eng` | Requests → Budget + **required-by date** |
| 2 | `angel.bud` | Accept → Register Approved Budget → OUT → ACC |
| 3 | `neil.acc.staff` | IN → OUT → ENG |
| 4 | `kristofer.eng` | IN |
| 5 | `angel.bud` | Close request + DOC ID |

### 7. Phone / emulator
```powershell
cd mobile\flutter
flutter run
```
- [ ] Same WiFi / USB debugging OK
- [ ] API URL = localhost (emulator) o laptop IP (physical phone)
- [ ] Rehearse sa **same device** na dadalhin bukas

---

## Bring tomorrow

- [ ] Laptop + charger
- [ ] Phone (kung mobile demo)
- [ ] **[DEMO-SCENARIOS-COMPLETE.md](DEMO-SCENARIOS-COMPLETE.md)** (lahat ng scenario)
- [ ] [START-HERE.md](START-HERE.md) (cheat sheet)
- [ ] `thesis-work/2026-09-29_SmartFlow-Figures/Figure_1.2_Use_Case_Diagram_Updated.png` (backup slide)
- [ ] Client questionnaire answers (Google Doc / print)
- [ ] Optional: printed QR label sample

---

## Accounts (important)

| Role | Username | Scan? | COA admin? |
|------|----------|-------|------------|
| ENG clerk | `kristofer.eng` | Yes | No |
| ENG head | `neil.eng.head` | Yes | No |
| Budget | `angel.bud` | Yes | No |
| **Accounting clerk** | **`neil.acc.staff`** | **Yes** | No |
| Municipal Accountant | `neil.admin` | **No** (admin) | **Yes** |
| HR | `rainier.hr` | No payroll QR in pilot | No |

---

## Panel Q&A (memorize)

| Tanong | Sagot |
|--------|--------|
| Ano ang SmartFlow? | QR **custody log** ng pisikal na folder sa ENG/BUD/ACC — hindi financial audit. |
| Validated ba? | Oo — questionnaire sa Municipal Accountant; DV trail priority. |
| Request vs scan? | Request = ticket; scan = totoong lipat ng folder. |
| Bakit may Treasury/Mayor? | Client asked to include Treasury; full DV path ENG→BUD→ACC→TRE→MAY→TRE. Payment is marked by TRE on the ticket — app still does not approve funds. |
| Payroll? | Payslip access — hindi physical QR sa Phase 1. |
| Limitation? | Kailangan mag-scan ang staff; missed scan = incomplete trail. |
| Secure QR? | Signed + expiry; server verify; rejects sa audit monitor. |
| HTTPS? | Pilot LAN HTTP; HTTPS bago go-live (hindi blocker sa capstone demo). |
| Deploy na? | **Pilot prototype** — MOA/capstone; production needs hardening. |

**One-liner:**  
*SmartFlow supports COA preparation by logging inter-office physical handoffs with timestamps and named personnel. Financial validation stays with the Municipal Accountant.*

---

## Known gaps (sabihin nang honest)

- Walang push/SMS (in-app status lang)
- Treasury / Mayor wala sa app
- Web admin dashboard = future
- `neil.admin` = reports only, clerk ang scanner
- Client hindi complete lahat ng questionnaire items (confidential / pending)

---

## Kung may error bukas

| Error | Fix |
|-------|-----|
| Invalid server response | `.\scripts\sync-backend-to-xampp.ps1` |
| Cannot Mark IN | Previous office **OUT** muna; tamang office lang |
| Admin cannot scan | Gamitin **`neil.acc.staff`** |
| Request failed | Kailangan **required-by date** |
| Apache down | XAMPP start |

```powershell
.\scripts\run-defense-demo.ps1
# Flutter terminal: press R (hot restart)
```

---

## Docs aligned sa client (code done)

See [`../client/CLIENT-DISCOVERY-RESPONSES-SUMMARY.md`](../client/CLIENT-DISCOVERY-RESPONSES-SUMMARY.md)

**Outdated pa (huwag sundan kung DV demo):** `SmartFlow-Flowchart.html` may HR payroll row — sabihin “Phase 1 = DV + budget lang.”

---

Good luck bukas.
