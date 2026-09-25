# Chapters 1–3 — What to Change (Based on Live System)

**Source of truth:** live SmartFlow (`web/`, `mobile/flutter/`, `backend/backend/api/`)  
**Demo path:** ENG → BUD → ACC → TRE → MAY → TRE (check release)  
**Do not change:** problem framing · **COA support ≠ financial statements**

---

## Chapter 1 — Introduction, Scope, Objectives, IPO

### Scope and offices

| Old (paper) | New (system) |
|---|---|
| Engineering, HR, Budget, Accounting | **ENG, HR, BUD, ACC, TRE, MAY** |

Add Treasury and Mayor staff/heads to beneficiaries.

### What is actually tracked

| Tracked with QR | Not a QR folder |
|---|---|
| Disbursement Voucher | Payroll folder |
| Approved Budget | — |
| Others | — |

- HR has **no** dedicated QR type in the pilot.
- Payroll = **payslip access only** — remove “payroll records” as a tracked folder.

### DV path to write

```text
ENG → BUD → ACC → TRE → MAY → TRE (check release)
→ ACC only if the folder returns
```

- App **suggests** next office.
- App does **not** approve the voucher or release the check.

### Two actions (not one)

| Situation | Action |
|---|---|
| Folder **not** on your desk | **Document request** |
| Folder **on** your desk | Holding office **Register** + **Scan IN/OUT** |

Registration is **not** limited to the Accountant.

### Significance (panel ask)

Emphasize these as unique vs plain QR systems:

- Signed QR payload: `SF1` + **HMAC-SHA256**
- Validity: **180 days** (6 months)
- Only SmartFlow can verify; admin can **reprint** a fresh label
- **Duplicate-scan** block (short window)
- Admin **QR monitor** for scan history

### Objectives

Keep the **seven** approved objectives; reword 1–6 to match the app:

1. Signed QR tagging  
2. Six-office scan trail  
3. Dashboard  
4. Delay alerts (processing thresholds)  
5. COA flow summaries (monthly / quarterly / annual)  
6. Office analytics  
7. Usability evaluation  

If the panel wants fewer: merge into **five** — tracking, QR security, alerts, COA reports, audit trail.  
**Do not** add payment approval as an objective.

### Figure 1 (IPO)

| Box | Change |
|---|---|
| **INPUT** | Documents = DV + Approved Budget; pilot = **six** offices; remove payroll as tracked type |
| **PROCESS** | Move **Waterfall** here (out of Input); add document requests; signed QR + expiration; Flutter **and** React can register / request / scan |
| **OUTPUT** | Hybrid stack outputs + QR security features |
| **EVALUATION** | Include Treasury + Mayor users (not only ENG/HR/BUD/ACC) |

### Add: short COA subsection

1. Describe LGU paper path: Budget check → Accounting check → Treasury → Mayor signature → check release.  
2. State: SmartFlow only logs **where** the folder is and **how long** it stayed.  
3. Accounting still prepares the COA report **outside** the system.

---

## Chapter 2 — Methodology, Diagrams, Data Dictionary

### Opening and architecture

- Same **six offices** and **two** primary document types in the first paragraph.
- Both clients → one PHP API → one MySQL DB over **HTTPS**.
- Flutter is **not** scan-only.
- React is **not** the only place to register.

### SDLC (§2.1.3)

| Old | New |
|---|---|
| Iterative / Agile, seven sprints | **Waterfall**: Requirements → Design → Development → Testing → Deployment |

Drop sprint wording. Match Capstone 2 PDF + panel revision.

### DFD (Figures 2-2 and 2-3)

**Include**

- Clerks for all **six** offices  
- Department head  
- System administrator  
- Municipal Accountant  
- COA **outside** the system (receives support files from Accountant)  
- Process for **document requests** beside register, scan, alerts, COA reports, admin config  

**Remove**

- “City Clerk”  
- “Municipal Approval Committee”  
- In-app approval of payments  

### Flowcharts (2-5 … 2-5d)

Redraw on a **white / light** background.

| Figure | Role | Align to system |
|---|---|---|
| **2-5** | Clerk | Register when folder is on that desk; else Requests; Scan = Mark IN/OUT (incl. TRE/MAY on DV) |
| **2-5b** | Head | Office dashboard, overdue alerts, office analytics |
| **2-5c** | Accountant / admin | Municipal dashboard, COA reports, analytics; **admin does not scan** |
| **2-5d** | Administrator | Users, offices, roles, thresholds, QR monitor, signup approval |

### Use cases

**Actors only:** `staff` · `head` · `admin`

**Cover:** login · signup approval · forgot password · register + print QR · scan IN/OUT · request / accept / decline / fulfill · history · alerts · reports · analytics · thresholds · offices · QR monitor

### Data dictionary + ERD

**Do not use** old `backend/schema.sql` story (`roles` table, `scan_logs`, payroll as core type).

**Use live API schema:**

| Live tables / fields |
|---|
| `users.role` = `admin` \| `staff` \| `head` |
| `offices`, `documents` |
| `movements` (IN/OUT) |
| `document_requests` |
| `qr_tokens` |
| `audit_logs` |
| `signup_requests` |
| `password_resets` |
| `auth_tokens` |
| `processing_thresholds` |

Add a small table: **DFD process → research objective**.

---

## Chapter 3 — System Design

`docs/thesis/chapter-03-system-design.md` is still a **placeholder**.  
If Word Chapter 3 already has stack + signed QR, keep structure and fix facts below. Otherwise write:

| Section | Content |
|---|---|
| **3.1** | Custody tracking of physical folders — no file content, no payment approval |
| **3.2** | Use cases for `staff`, `head`, `admin` only |
| **3.3** | Context + Level 1 DFD, including document requests |
| **3.4–3.5** | Three-tier: Flutter + React + PHP/MySQL; QR format, 180-day expiry, reprint, duplicate-scan block |
| **3.6** | Screens: Home, Scan, Register, Requests, History, Alerts, Profile; head analytics; admin users / offices / thresholds / reports / QR monitor / system |
| **3.7** | Database from **live** API tables (not old `scan_logs` design) |

---

## One consistency rule (Ch 1–3)

Wherever the paper says any of these, replace:

| Wrong | Correct |
|---|---|
| Four offices | **Six offices** (ENG, HR, BUD, ACC, TRE, MAY) |
| Payroll QR | **Payslip access only** / no payroll folder QR |
| Agile / iterative sprints | **Waterfall** |
| Clerks only scan | Holding office **registers + scans** |
| Only Accounting registers | **Any holding office** registers when folder is on desk |
| Plain QR | **HMAC-SHA256 signed** QR + expiration + QR monitor |

---

## Quick checklist

- [ ] Ch1 scope = six offices  
- [ ] Ch1 docs = DV + Approved Budget (+ Others); no payroll QR  
- [ ] Ch1 DV path = ENG→BUD→ACC→TRE→MAY→TRE  
- [ ] Ch1 Register vs Request rule  
- [ ] Ch1 significance = signed QR + HTTPS + QR monitor  
- [ ] Ch1 IPO = Waterfall in PROCESS; six offices  
- [ ] Ch1 COA subsection  
- [ ] Ch2 Waterfall SDLC  
- [ ] Ch2 DFD = six clerks; no approval committee  
- [ ] Ch2 flowcharts white bg + role fixes  
- [ ] Ch2 use cases = staff / head / admin  
- [ ] Ch2 data dictionary = live tables  
- [ ] Ch3 filled or corrected to hybrid stack + live schema  

---

*Related: [chapter-4-software-testing-and-uat.md](chapter-4-software-testing-and-uat.md) (Capstone 2 checklist) · [../defense/REVISION-MATRIX.md](../defense/REVISION-MATRIX.md)*
