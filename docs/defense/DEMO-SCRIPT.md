# SmartFlow — Demo Script (~12–15 min)

**Audience:** Panel / Municipal Accountant / class  
**Cast:** Neil · Tofers · Angel · Zandra · Rainier  
**Password:** `smartflow123`

> **Lahat ng scenario (A, S1–S6, B, H, C, C2, 5-min script, Q&A, panel mapping):**  
> **[DEMO-SCENARIOS-COMPLETE.md](./DEMO-SCENARIOS-COMPLETE.md)** ← basahin ito tonight.

**Bukas — recommended order:** A+S1 → S2 duplicate → S3 wrong IN → S5 tamper → S6 admin monitor → C COA.

---

## ⚠️ Tamang flow (basahin muna — ito ang dating mali)

May **dalawang layer** — huwag isahing pipeline:

| Layer | Ano | Halimbawa |
|-------|-----|-----------|
| **A. Document request** | Formal na “hingi / approve” sa **tamang office** | ENG humingi ng **budget check** → inbox ng **BUD** |
| **B. Physical QR trail** | Folder talagang lumipat — **IN / OUT** bawat desk | DV folder: **ENG → BUD → ACC** |

**Mali sa dating script:** DV (Disbursement Voucher) pinadaan sa **HR** — HR para sa **payroll**, hindi sa road-repair DV.

**Validated sa client (Municipal Accountant):** Pinaka-importante sa demo = **DV trail**. Pilot QR types = **DV** at **Approved Budget** lang.

**Tama sa Urbiztondo practice (client + thesis):**

| Document type | Pilot QR trail (SmartFlow) | Buong LGU path (labas ng pilot) |
|---------------|---------------------------|----------------------------------|
| **Disbursement Voucher** | **ENG → BUD → ACC** | Pagkatapos ACC: **Treasury → Mayor → Treasury** (check release) — **hindi pa sa app** |
| **Approved budget** | **BUD → ACC → ENG** (kung hinihingi ng ENG) | — |
| **Payroll** | *Payslip access — hindi physical QR sa Phase 1* | Accounting ang naghahanda ng payroll |

**Request vs scan:**

- **Budget request** = “Budget office, pakicheck ang pondo” (ticket sa BUD)  
- Pag may **physical folder** na, **scan** ang nagpapatunay na umalis/dumating

**⚠️ Mali kung pareho:** ENG humingi ng budget file → tapos **ENG pa mag-print ng QR** ng dokumentong **wala pa sa kanya**.

**Rule:** Ang office na **may hawak** ng folder ang nag-**Register** + QR print. Kung ENG humihingi at wala pa sa desk niya ang docs → pagkatapos ng accept, **Budget** mag-register → **BUD → ACC → ENG** (client validated).

**Dalawang scenario:**

| | **A — DV trail** (**main demo** — client priority) | **B — Hingi ng budget docs** (optional, 2nd) |
|---|------------------------------------------------------|-----------------------------------------------|
| Request | Optional: ENG → BUD ticket “pakireview ang DV” | ENG → BUD: kailangan ng budget file / pondo |
| Sino mag-register + QR? | **Neil (ENG)** — nasa Eng ang DV folder | **Angel (BUD)** — nasa Budget ang dokumento |
| Pisikal (pilot) | **ENG → BUD → ACC** | **BUD → ACC → ENG** |

**Panel line (Treasury):** *“SmartFlow ay hanggang Accounting sa pilot — ang **payment release** sa Treasury at Mayor ay manual pa; hindi ‘approve’ ng DV ang app, **track lang** ng pisikal na folder.”*

---

## Before you start (5 min earlier)

1. XAMPP: **Apache + MySQL** running  
2. ```powershell
   cd "C:\Users\nljhn\Downloads\Capstone 1 -Neil"
   .\scripts\sync-backend-to-xampp.ps1
   .\scripts\setup-smartflow.ps1
   ```
3. ```powershell
   cd mobile\flutter
   flutter run
   ```
4. Purge test data kung kailangan:  
   `http://localhost/Smartflow/backend/backend/api/dev-purge-demo-documents.php?all=1`

**Say:** *“SmartFlow: **requests** kung sino ang dapat tumugon, **QR scans** kung nasaan na ang pisikal na folder.”*

---

## Part 1 — Entry (1 min)

| Step | Action | Say |
|------|--------|-----|
| 1 | Get Started → Login | |
| 2 | **`engineering.staff`** | *“Neil, Engineering clerk.”* |

---

## Part 2 — Scenario A: DV trail (**main demo**)

**Story:** May **Disbursement Voucher folder** na sa Engineering (end user). I-track ang pisikal na lipat hanggang Accounting. **Hindi** dadaan sa HR. Pagkatapos ACC, ang folder ay **Treasury / Mayor** na — labas ng pilot.

### Neil — register DV sa ENG

| Step | Action | Say |
|------|--------|-----|
| 1 | (Naka-login na **`engineering.staff`**) **New** → Title: `DV – Road Repair Project` · Type: **Disbursement Voucher** | *“End user ang naghahanda ng DV packet — nasa desk nila kaya sila mag-register.”* |
| 2 | Copy **DOC-…** · **secured QR** + expiry · auto **IN** sa ENG | *“Signed QR — hindi raw ID; custody log, hindi approval ng bayad.”* |
| 2b | **Scan** tab → scan label → **Secured QR verified** | *“Server: signature + expiry.”* |
| 3 | *(Optional)* **Document requests** → Budget: `Please review DV for fund availability` | Ticket lang — hiwalay sa scan trail |
| 4 | **Scan** → **Mark OUT** → **BUD** (suggested) | *“Budget: appropriation check.”* |

### Angel — Budget receives at forwards

| Step | Action | Say |
|------|--------|-----|
| 5 | Login **`budget.staff`** | |
| 6 | **Scan** → same DOC ID → **Mark IN** | *“Dumating sa Budget — wrong office blocked kung maling IN.”* |
| 7 | **Scan** → **Mark OUT** → **ACC** (suggested) | *“Supporting docs complete sa Budget → Accounting.”* |
| 8 | Logout | |

### Rainier — Accounting receives (end of pilot trail)

| Step | Action | Say |
|------|--------|-----|
| 9 | Login **`accounting.staff`** (ACC clerk — **hindi** accountant.main) | |
| 10 | **Scan** → **Mark IN** | *“Accounting: completeness at legality ng supporting docs — **hindi** DV approval sa app.”* |
| 11 | **History** → timeline (named user, date/time) | *“Chain-of-custody para sa COA prep.”* |
| 12 | Login **`accountant.main`** → Admin → **COA report** | *“Head/accountant view — hindi siya frontline scanner.”* |

**Panel line:**  
> *“DV path na validated ng Municipal Accountant: **ENG → BUD → ACC**, tapos **Treasury → Mayor → Treasury** para sa check release — yung huli wala pa sa SmartFlow pilot. Hindi HR ang dadaan para sa DV.”*

**Kung tanong “bakit hindi HR?”** — payroll hiwalay; DV = project/end-user folder.

---

## Part 3 — (Optional) Scenario B: ENG humingi ng budget file

**Gamitin kung may extra oras** — hiwalay na story sa Part 2. **Huwag** isabay sa DV demo.

**Story:** Neil kailangan ng **approved budget / allotment** — **hindi** siya mag-QR ng file na nasa Budget pa.

### Neil — request lang

| Step | Action | Say |
|------|--------|-----|
| 1 | **`engineering.staff`** → **Document requests** → **Budget (→ BUD)** | *“Formal request sa owner office.”* |
| 2 | Purpose: `Need approved budget allotment for road repair` → Submit → Logout | |

### Angel — approve, register, send

| Step | Action | Say |
|------|--------|-----|
| 3 | **`budget.staff`** → **Inbox** → **Approve** | |
| 4 | **New** → **Approved Budget** → Register + QR sa **BUD** | *“Holder office ang nag-register.”* |
| 5 | **OUT** → **ACC** → Logout | |

### Rainier → Neil — ACC then ENG

| Step | Action | Say |
|------|--------|-----|
| 6 | **`accounting.staff`** → **IN** → **OUT** → **ENG** | *“Client: dadaan muna sa Accounting.”* |
| 7 | **`engineering.staff`** → **IN** (receive) | |
| 8 | Angel: **Fulfill** + link DOC ID | |

**Optional reject:** Angel **Reject** + notes → Neil sees **declined**; *“Sa totoong opisina, hiwalay na tawag/memo rin.”*

---

## Part 4 — Optional: Payroll (skip sa main demo)

**Client:** payslip access lang — **hindi** physical QR payroll sa Phase 1. Skip maliban kung tanungin; sabihin: *“Out of pilot scope; Accounting prepares payroll.”*

---

## Part 5 — Head monitor (2 min)

| Step | Action | Say |
|------|--------|-----|
| 1 | **`head.engineering`** (Tofers) | |
| 2 | **Home** / **Queue** / **Alerts** | *“Monitor lang — hindi araw-araw na scanner ang head.”* |
| 3 | **History** → DOC ID → timeline | |

---

## Part 6 — Security rejects (panel — ~3 min)

Gawin **pagkatapos** ng partial DV trail (may DOC na IN/OUT) o sa dulo. Detalye: [DEMO-SCENARIOS-COMPLETE.md](./DEMO-SCENARIOS-COMPLETE.md).

| Step | Login | Action | Say |
|------|--------|--------|-----|
| 1 | `engineering.staff` | Same doc → **Mark IN** ulit | *“Duplicate blocked — may reason code.”* |
| 2 | `engineering.staff` | Doc OUT to BUD, **huwag** pa BUD IN → try **Mark IN** sa ENG | *“Wrong office — state rules.”* |
| 3 | `engineering.staff` | Paste secured QR sa manual field · **1 char** baguhin | *“Tampered label rejected.”* |
| 4 | `accountant.main` | Home → **QR scan monitor** → Rejected / All · **Copy CSV** | *“Audit monitor para COA.”* |

---

## Part 7 — Admin / COA view (2 min)

| Step | Action | Say |
|------|--------|-----|
| 1 | **`accountant.main`** | |
| 2 | **Home** — lahat ng office | |
| 3 | **COA report** — buwanang summary | |
| 4 | **System** | |
| 5 | **QR scan monitor** (kung hindi sa Part 6) | |

---

## Close (30 sec)

> *“**Request** = sino ang inutusan (BUD/HR/ACC/ENG). **Scan** = totoong lipat ng folder. Hindi fixed na lahat dadaan sa apat na office — sinusunod ang uri ng dokumento.”*

---

## Accounts

| Name | Username | Office |
|------|----------|--------|
| Neil | `engineering.staff` | ENG |
| Tofers | `head.engineering` | ENG |
| Angel | `budget.staff` | BUD |
| Zandra | `hr.staff` | HR |
| Maria (ACC clerk) | `accounting.staff` | ACC (scans) |
| Rainier | `accountant.main` | ACC (admin / COA) |

---

## Short demo (5 min) — DV + security

1. Neil: **New** → **DV** → secured QR → scan verify → **OUT** → BUD  
2. Angel: **IN** → **OUT** → ACC  
3. `accounting.staff`: **IN** → **History**  
4. Neil: duplicate **IN** → reject  
5. `accountant.main`: **QR scan monitor**  
6. *“Treasury and Mayor are in the pilot — ENG → BUD → ACC → TRE → MAY → TRE. Treasury marks payment released on the ticket.”*

---

## Home dashboard (panel Q&A)

| Card | Meaning |
|------|---------|
| **Received** (today) | IN scans at your office today |
| **Sent** (today) | OUT scans today |
| **On desk** (now) | Folders still **IN** here — after Mark OUT, count drops (not a bug) |

Tap **Received** / **Sent** → **History** filtered for today. Tap **On desk** → scrolls to **At your office now**. Activity rows show **exact time** (e.g. 2:14 PM).

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Invalid server response | `.\scripts\sync-backend-to-xampp.ps1` |
| Could not create document | Purge + retry; ID fix nasa server na |
| Cannot Mark IN | Previous office **OUT** muna |
| Admin cannot scan | Normal — staff/head lang; ACC clerk sa deployment |
