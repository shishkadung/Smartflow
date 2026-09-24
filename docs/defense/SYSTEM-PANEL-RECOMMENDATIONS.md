# SmartFlow — Panel Recommendations + Demo Reference

> **Quick links:** [Panel Status](#panel-status) · [What to Say](#what-to-say-sa-panelist) · [Demo Order](#demo-order) · [Demo Script](#demo-script) · [Accounts](#accounts) · [Troubleshooting](#troubleshooting)

---

## Panel Status

### ✅ Implemented — Pwede nang i-present

| # | Recommendation | Date | Notes |
|---|---------------|------|-------|
| 1 | **QR Security** — signed payload `SF1.{payload}.{hmac}` | 2026-05-28 | Verified via `qr-verify.php` + `movements-create.php` |
| 2 | **QR Expiration** — 180-day TTL, fresh token on reprint | 2026-05-28 | Expired/tampered = clear API + app error |
| 3 | **Duplicate Scan Prevention** — state matrix + 8s debounce | 2026-05-28 | All rejections logged with `scan_error` reason codes |
| 4 | **State-Based Scan Rules** — one valid transition per scan | 2026-05-28 | `smartflow_check_movement`; QR reusable per lifecycle |
| 5 | **QR Audit / Monitor Dashboard** — admin scan log | 2026-05-28 | `/admin/qr-monitor` + `audit-scans.php`; CSV export |

### ⏸ Deferred / Pending

| # | Recommendation | Status |
|---|---------------|--------|
| 6 | **HTTPS** | Deferred — municipal LAN demo uses HTTP; enable before go-live |
| 7 | **COA Process Alignment** | Partial — movement trail exists; formal COA mapping ongoing |
| 8 | **Screenshots/Evidence** | [ ] Capture: duplicate block, expiry reject, audit monitor |

---

## What to Say sa Panelist

### Para sa implemented items:

> **QR Security + Expiration**  
> *"Hindi na plain document ID ang QR namin. Gumagamit kami ng signed token — `SF1.{payload}.{hmac}`. Verified server-side sa bawat scan. May 180-day expiration — pag nag-expire o tampered, ini-reject ng system na may clear na error. Pag kailangan ng bago, fresh token ang nai-issue ng reprint."*

> **Duplicate Scan + State Rules**  
> *"May state matrix kami plus 8-second debounce. Hindi puwedeng mag-IN ulit kung naka-IN na, o mag-IN sa maling office. Isa lang ang valid na transition per scan — IN or OUT depende sa current state. Lahat ng rejections ay naka-log with reason codes."*

> **QR Audit Monitor**  
> *"May admin dashboard — QR scan monitor — nagpapakita kung sino, saan, kailan nag-scan, accepted o rejected, kasama ang reason. May CSV export para sa compliance review."*

### Para sa deferred items:

> **HTTPS**  
> *"Ang HTTPS ay deferred muna dahin ang target deployment namin ay municipal LAN. Sa lokal na network, HTTP is acceptable. Plano namin i-enable ito bago mag-actual go-live, kasama na ang TLS cert at redirect config."*

### Key lines na dapat memorize:

- *"Ang QR namin **hindi one-time forever** — state-controlled per valid transition."*
- *"Lahat ng scans — accepted or rejected — naka-log sa audit trail."*
- *"HTTPS deferred by design para sa LAN demo; ise-set up bago go-live."*

---

## Demo Order

**Recommended sequence:** `A+S1 → S2 duplicate → S3 wrong IN → S5 tamper → S6 admin monitor → C COA`

**Password:** `smartflow123`

> Full scenario details (S1–S6, Q&A, panel mapping): **[DEMO-SCENARIOS-COMPLETE.md](./DEMO-SCENARIOS-COMPLETE.md)**

### Dalawang bagay na huwag pagsamahin

| Layer | Ano | Halimbawa |
|-------|-----|-----------|
| **Document request** | Formal na "hingi / approve" sa tamang office | ENG humingi ng budget check → inbox ng BUD |
| **Physical QR trail** | Folder talagang lumipat — IN / OUT bawat desk | DV folder: **ENG → BUD → ACC** |

### Tamang QR trail per document type

| Document | Pilot trail (SmartFlow) | Labas ng pilot |
|----------|------------------------|----------------|
| **Disbursement Voucher** | **ENG → BUD → ACC** | Treasury → Mayor → Treasury (check release) |
| **Approved Budget** | **BUD → ACC → ENG** (kung hinihingi ng ENG) | — |
| **Payroll** | *Hindi physical QR sa Phase 1* | Accounting ang naghahanda |

**Rule:** Ang office na **may hawak ng folder** ang nag-Register + QR print.

**Panel line (kung tanungin ang Treasury):**  
> *"SmartFlow ay hanggang Accounting sa pilot — ang payment release sa Treasury at Mayor ay manual pa. Hindi 'approve' ng DV ang app, track lang ng pisikal na folder."*

**Kung tanungin "bakit hindi HR?"** — HR para sa payroll; DV = project/end-user folder, hindi dumadaan sa HR.

---

## Demo Script

**Cast:** Neil (`engineering.staff`) · Tofers (`head.engineering`) · Angel (`budget.staff`) · Zandra (`hr.staff`) · Rainier (`accountant.main`)

### Setup (5 min bago mag-demo)

1. XAMPP: **Apache + MySQL** on
2. Run sync:
   ```powershell
   .\scripts\sync-backend-to-xampp.ps1
   .\scripts\setup-smartflow.ps1
   ```
3. Run app:
   ```powershell
   cd mobile\flutter && flutter run
   ```
4. Purge test data (kung kailangan):  
   `http://localhost/Smartflow/backend/backend/api/dev-purge-demo-documents.php?all=1`

**Opening line:** *"SmartFlow: requests para sa kung sino ang dapat tumugon; QR scans para sa kung nasaan na ang pisikal na folder."*

---

### Part 1 — Login (1 min)

| Step | Action | Say |
|------|--------|-----|
| 1 | Get Started → Login | |
| 2 | Login as **`engineering.staff`** | *"Neil, Engineering clerk."* |

---

### Part 2 — Scenario A: DV Trail (main demo, ~5 min)

**Story:** May DV folder sa Engineering. I-track ang lipat nito hanggang Treasury/Mayor (full path). Hindi dadaan sa HR.

#### Neil — Register DV sa ENG

| Step | Action | Say |
|------|--------|-----|
| 1 | **New** → Title: `DV – Road Repair Project` · Type: **Disbursement Voucher** | *"End user ang naghahanda ng DV — nasa desk nila, kaya sila mag-register."* |
| 2 | Note **DOC-…** · secured QR + expiry · auto IN sa ENG | *"Signed QR — hindi raw ID. Custody log, hindi approval ng bayad."* |
| 2b | **Scan** tab → scan label → **Secured QR verified** | *"Server checks: signature + expiry."* |
| 3 | *(Optional)* **Requests** → Budget: `Please review DV for fund availability` | Ticket lang — hiwalay sa scan trail |
| 4 | **Scan** → **Mark OUT** → BUD | *"Papunta Budget para sa appropriation check."* |

#### Angel — Budget receives at forwards

| Step | Action | Say |
|------|--------|-----|
| 5 | Login **`budget.staff`** | |
| 6 | **Scan** → **Mark IN** | *"Dumating sa Budget. Wrong office ang ma-block kung maling IN."* |
| 7 | **Scan** → **Mark OUT** → ACC | *"Supporting docs complete — papunta Accounting."* |
| 8 | Logout | |

#### Rainier — Accounting receives (end ng pilot trail)

| Step | Action | Say |
|------|--------|-----|
| 9 | Login **`accounting.staff`** (ACC clerk, hindi `accountant.main`) | |
| 10 | **Scan** → **Mark IN** | *"Accounting checks completeness at legality — hindi DV approval sa app."* |
| 11 | **History** → timeline | *"Chain-of-custody para sa COA prep — named user, exact time."* |
| 12 | Login **`accountant.main`** → Admin → **COA report** | *"Head/accountant view — hindi siya frontline scanner."* |

> **Panel line:** *"DV path validated ng Municipal Accountant: ENG → BUD → ACC. Pagkatapos ACC, Treasury → Mayor → Treasury na para sa check release — yun ay wala pa sa SmartFlow pilot."*

---

### Part 3 — (Optional) Scenario B: ENG humingi ng budget file (~3 min)

**Gamitin kung may extra oras.** Hiwalay na story — huwag isabay sa Part 2.

**Story:** Neil kailangan ng approved budget. Hindi siya mag-QR ng file na nasa Budget pa.

| Actor | Step | Action |
|-------|------|--------|
| **Neil** | 1 | `engineering.staff` → **Requests** → Budget: `Need approved budget allotment for road repair` → Submit → Logout |
| **Angel** | 2 | `budget.staff` → **Inbox** → **Approve** → **New** → Approved Budget → Register + QR sa BUD → **OUT** → ACC → Logout |
| **Rainier** | 3 | `accounting.staff` → **IN** → **OUT** → ENG |
| **Neil** | 4 | `engineering.staff` → **IN** (receive) |
| **Angel** | 5 | **Fulfill** + link DOC ID |

*Optional:* Angel **Reject** + notes → Neil sees declined. *"Sa totoong opisina, may hiwalay na tawag/memo rin."*

---

### Part 4 — Head Monitor (2 min)

| Step | Action | Say |
|------|--------|-----|
| 1 | Login **`head.engineering`** (Tofers) | |
| 2 | **Home** / **Queue** / **Alerts** | *"Monitor lang — hindi araw-araw na scanner ang head."* |
| 3 | **History** → DOC ID → timeline | |

---

### Part 5 — Security Rejects (panel highlight, ~3 min)

Gawin pagkatapos ng partial DV trail (may DOC na IN/OUT na).

| Step | Login | Action | Say |
|------|-------|--------|-----|
| 1 | `engineering.staff` | Same doc → **Mark IN** ulit | *"Duplicate blocked — may reason code."* |
| 2 | `engineering.staff` | Doc OUT to BUD, huwag pa BUD IN → try **Mark IN** sa ENG | *"Wrong office — state rules."* |
| 3 | `engineering.staff` | Paste secured QR sa manual field · baguhin ng 1 char | *"Tampered label rejected."* |
| 4 | `accountant.main` | **QR scan monitor** → Rejected / All → **Copy CSV** | *"Audit monitor para COA."* |

---

### Part 6 — Admin / COA View (2 min)

| Step | Action | Say |
|------|--------|-----|
| 1 | Login **`accountant.main`** | |
| 2 | **Home** — lahat ng office | |
| 3 | **COA report** — buwanang summary | |
| 4 | **QR scan monitor** (kung hindi pa nagawa sa Part 5) | |

---

### Close (30 sec)

> *"Request = sino ang inutusan. Scan = totoong lipat ng folder. Hindi fixed na lahat dadaan sa apat na office — sinusunod ang uri ng dokumento."*

---

## Short Demo (5 min) — DV + Security Only

1. Neil: **New** → DV → secured QR → scan verify → **OUT** → BUD
2. Angel: **IN** → **OUT** → ACC
3. `accounting.staff`: **IN** → **History**
4. Neil: duplicate **IN** → reject
5. `accountant.main`: **QR scan monitor**
6. *"Treasury and Mayor are in the pilot — ENG → BUD → ACC → TRE → MAY → TRE."*

---

## Accounts

| Name | Username | Office | Role |
|------|----------|--------|------|
| Neil | `engineering.staff` | ENG | Staff / scanner |
| Tofers | `head.engineering` | ENG | Head / monitor |
| Angel | `budget.staff` | BUD | Staff / scanner |
| Zandra | `hr.staff` | HR | Staff |
| Maria | `accounting.staff` | ACC | Clerk / scanner |
| Rainier | `accountant.main` | ACC | Admin / COA view |

---

## Home Dashboard (Panel Q&A)

| Card | Meaning |
|------|---------|
| **Received** (today) | IN scans at your office today |
| **Sent** (today) | OUT scans today |
| **On desk** (now) | Folders still IN here — drops after Mark OUT (not a bug) |

Tap **Received / Sent** → History filtered for today. Tap **On desk** → scrolls to "At your office now". Activity rows show exact time (e.g. 2:14 PM).

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Invalid server response | `.\scripts\sync-backend-to-xampp.ps1` |
| Could not create document | Purge + retry |
| Cannot Mark IN | Previous office must **OUT** first |
| Admin cannot scan | Normal — staff/head lang ang scanner; ACC clerk sa deployment |
