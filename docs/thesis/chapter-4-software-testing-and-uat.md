# 4.4 Software Testing Plan

This section presents the software testing plan used to verify that SmartFlow meets Functional Requirements FR-1 through FR-7 before pilot deployment at the Municipality of Urbiztondo. Testing followed the Waterfall testing phase described in Section 4.1 and covered the implemented hybrid stack: a **React (Vite)** web client for registration, dashboards, document requests, Account & security, and Municipal Accountant / COA views; a **Flutter** Android client for QR scanning and role-based clerk / head / admin screens; a **PHP** REST API on Apache; and a **MySQL** database.

Testing progressed from the smallest units of code to the full system, then to acceptance by LGU users. Defects found at each level were logged, corrected, and retested before the next level began. Pre-testing was considered complete when critical and high-severity defects were resolved, FR-1 through FR-7 were demonstrable on the pilot environment, and User Acceptance Testing (UAT) sign-off was obtained from the Municipal Accountant or designated LGU representative under the memorandum of agreement.

| Test level | Purpose | Primary focus |
| ---------- | ------- | ------------- |
| Unit testing | Verify individual functions and modules in isolation | Auth, tracking codes / QR payload, scan rules, thresholds, alerts, report calculations |
| Integration testing | Verify connected modules and data exchange | React / Flutter ↔ PHP API ↔ MySQL end-to-end flows |
| System testing | Verify the complete system against FR-1 to FR-7 | Scripted scenarios with sample financial documents |
| User Acceptance Testing (UAT) | Verify fitness for daily LGU use and ISO/IEC 25010 quality | Realistic tasks by Accountant, heads, and clerks |

***Table 4.1 — Overview of the SmartFlow Software Testing Plan***

---

## 4.4.1 Unit Testing

Unit testing examined individual modules and functions of SmartFlow to confirm that each component produced the correct output for both expected and edge-case inputs. Units were tested by the research team during development, before modules were combined for integration testing.

### Objectives

1. Confirm that authentication and session handling accept valid credentials and reject invalid ones.
2. Confirm that document registration generates a unique tracking code suitable for QR labeling.
3. Confirm that scan-action rules (IN / OUT, receive / forward) enforce correct document state transitions.
4. Confirm that threshold comparison and alert generation flag overdue documents correctly.
5. Confirm that report and analytics calculations aggregate scan-log data without inventing financial statement content.

### Scope of Units Tested

| Unit / module | Description | Sample inputs | Expected result |
| ------------- | ----------- | ------------- | --------------- |
| Authentication | Login with username/email and password | Valid clerk account; wrong password; inactive / pending account | Success with role and office data; clear rejection for invalid or unapproved accounts |
| Document registration | Create document metadata and tracking code | Disbursement voucher or approved budget with reference number and origin office | Unique tracking ID; signed QR payload bound to the document; record stored in `documents` |
| QR / tracking parser | Decode scanned payload | Valid QR; malformed string; unknown tracking code | Valid code resolves to document; invalid codes rejected with user-readable error |
| Scan state rules | IN before OUT; duplicate-scan blocking | Receive then forward; OUT without prior IN; repeated identical scan | Allowed transitions succeed; illegal or duplicate scans blocked and logged as such |
| Threshold comparison | Compare dwell time to configured hours | Document within limit; document past limit for office / type | No alert within limit; overdue alert created when threshold exceeded |
| Alert creation | Persist and surface overdue flags | Overdue document for ENG / HR / BUD / ACC / TRE / MAY | Alert linked to document and office; visible to Accountant and concerned head |
| Report aggregation | Totals, average time, late counts, completion rate | Sample `movements` / document activity for a period | Correct counts and means; no financial statement fields generated |

***Table 4.2 — Unit Testing Scope for SmartFlow***

### Method and Tools

Unit checks were performed using controlled API requests against PHP endpoints, database inspection of MySQL tables (`users`, `documents`, `movements`, `processing_thresholds`, alerts / audit tables), React page checks for login / register / admin reports, and Flutter checks for scan confirmation and error messages. Each failed case was recorded with module name, input, observed result, severity, and fix status, then retested after correction.

### Sample Unit Test Cases

| ID | Test case | Steps (summary) | Pass criteria |
| -- | --------- | --------------- | ------------- |
| UT-01 | Valid login | Submit correct credentials for a clerk in Accounting | User authenticated; role and office returned |
| UT-02 | Invalid login | Submit wrong password | Access denied; no session issued |
| UT-03 | Register DV | Register disbursement voucher with required fields | Document saved; unique tracking code generated |
| UT-04 | Duplicate tracking prevention | Attempt conflicting registration rules as implemented | System prevents duplicate / conflicting identity per design |
| UT-05 | Valid receive (IN) | Scan valid QR and mark receive at assigned office | `movements` row created; current office updated |
| UT-06 | OUT before IN | Attempt forward / OUT when document is not IN | Action rejected; audit trail unchanged for illegal action |
| UT-07 | Duplicate scan block | Repeat the same scan action immediately | Second scan blocked; user notified |
| UT-08 | Overdue alert | Set short threshold; leave document past limit | Alert generated and associated with document / office |
| UT-09 | Report totals | Seed known documents and scans; run summary | Totals and late counts match seed data |

***Table 4.3 — Sample Unit Test Cases***

### Acceptance Criteria for Unit Testing

Unit testing was accepted when all critical units passed expected and edge-case checks, failed cases were fixed and retested, and no open critical defect remained in authentication, QR identity, scan-state enforcement, threshold/alert logic, or report calculation.

---

## 4.4.2 Integration Testing

Integration testing verified that SmartFlow modules work correctly when connected: the React web client and Flutter mobile app, PHP REST API, and MySQL database exchanging JSON over the municipal LAN or Wi-Fi (HTTPS in the target deployment environment).

### Objectives

1. Verify end-to-end document registration → QR generation → physical handoff scanning → dashboard update.
2. Verify that scan events written by mobile or web clerks appear in Accountant and department-head views without manual re-entry.
3. Verify that overdue logic using processing thresholds produces alerts visible to the correct roles.
4. Verify that office-scoped access limits department heads to their office while the Municipal Accountant retains municipal-wide visibility.
5. Verify that COA-oriented flow summaries and exports are built from live `documents` and `movements` data.

### Integration Scenarios

| ID | Integrated path | Verification |
| -- | --------------- | ------------ |
| IT-01 | Web or Flutter login → PHP auth → MySQL `users` / roles / offices | Session reflects correct role (`admin` / `staff` / `head`) and office |
| IT-02 | Register document (clerk / authorized encoder on web or mobile) → API → `documents` → QR display / print | Tracking ID and signed QR usable on device camera or uploaded image |
| IT-03 | Receive scan → API → `movements` + document location update → head / Accountant dashboard | Location and timestamp match the scan |
| IT-04 | Forward (OUT) to next office → API → MySQL → subsequent receive at destination | Handoff chain preserved in audit trail (e.g. ENG→BUD→ACC→TRE→MAY→TRE) |
| IT-05 | Threshold breach → alert record → Accountant and head notifications / lists | Correct offices notified; unrelated offices not flooded |
| IT-06 | Generate monthly flow summary / COA support export | Figures match database counts for the selected period |
| IT-07 | Role restriction | Clerk: scan / register / requests for office; head: office-scoped; admin: users, thresholds, COA reports, QR monitor |

***Table 4.4 — Integration Test Scenarios***

### Method

Integration tests used a staging or pilot server configuration matching the LGU stack (Apache, PHP, MySQL), the React web app on a browser, and Android devices (or emulator) running the Flutter application. A sample disbursement voucher originating from Engineering and moving through Budget, Accounting, Treasury, and Mayor’s Office was registered, labeled, scanned at each handoff, and checked on dashboards and reports. Network failures and delayed responses were noted as operational risks consistent with Chapter I limitations (for example, skipped scans leave gaps in the audit trail).

### Acceptance Criteria for Integration Testing

Integration testing was accepted when the primary path—register, print/display QR, receive, forward, view status, generate alert when overdue, and export a flow summary—completed successfully across React and/or Flutter, PHP, and MySQL, and role-based visibility behaved as designed for clerk (`staff`), department head (`head`), and Municipal Accountant / administrator (`admin`).

---

## 4.4.3 System Testing

System testing evaluated SmartFlow as a complete application against Functional Requirements FR-1 through FR-7, using scripted scenarios that mirror inter-department routing of physical financial documents among Engineering, Human Resources, Budget, Accounting, Treasury, and the Mayor’s Office (pilot codes ENG, HR, BUD, ACC, TRE, MAY).

### Objectives

1. Demonstrate FR-1 to FR-7 on the integrated system.
2. Confirm correct behavior for normal workflows and negative / incomplete scenarios.
3. Confirm that version 1 tracks metadata and movement only (no stored document images or financial statement content).
4. Confirm readiness for UAT with LGU participants.

### Mapping of System Tests to Functional Requirements

| FR | Requirement (summary) | System test focus |
| -- | --------------------- | ----------------- |
| FR-1 | Register document and generate printable / displayable signed QR | Registration fields, unique ID, QR usability (camera or image upload) |
| FR-2 | Log handoffs via scan (receive / forward) with audit trail | Scan identity, office, user, timestamp, action |
| FR-3 | Dashboard of active documents (location, elapsed time, overdue) | Municipal-wide and office-scoped views |
| FR-4 | Overdue alerts based on configured thresholds | Threshold setup and alert appearance |
| FR-5 | COA-aligned flow summaries (period totals, times, late counts, completion) | Report generation and export |
| FR-6 | Department performance / bottleneck analytics | Ranking and late counts by office |
| FR-7 | Support UAT and ISO/IEC 25010 evaluation | Stable pilot build; questionnaire and task scripts usable |

***Table 4.5 — System Testing Mapped to FR-1 through FR-7***

### Sample System Test Cases

| ID | Scenario | Document / offices | Expected system behavior |
| -- | -------- | ------------------ | ------------------------ |
| ST-01 | Happy path — disbursement voucher | ENG → BUD → ACC → TRE → MAY → TRE | Full audit trail; final location and status correct; app tracks folder only (no payment approval in-app) |
| ST-02 | Formal document request (Layer A) | ENG requests file from Budget; Budget accepts and fulfills | Ticket status updates; custody still requires register + scan when folder moves |
| ST-03 | Approved budget monitoring | BUD → ACC (and onward as office practice) | Registration and handoffs visible to Accountant |
| ST-04 | Incomplete trail (skipped scan) | Forward without receive at an office | Gap detectable in history; consistent with known limitation |
| ST-05 | Illegal state | OUT / forward before IN; duplicate IN | Rejected; user informed; reject visible on admin QR monitor |
| ST-06 | Overdue document | Short threshold on Budget | Alert raised; appears for Accountant and Budget head |
| ST-07 | COA support export | Period with known seed documents | Export totals match system records; no financial statements generated |
| ST-08 | Access control | Head of Engineering views dashboards | Sees Engineering-scoped data; not other offices’ full municipal board |

***Table 4.6 — Sample System Test Cases***

### Alpha Testing

Before UAT, the research team and capstone adviser conducted alpha validation on the staging / pilot build. Defects were classified by severity (critical, high, medium, low). Critical and high-severity defects were required to be fixed and retested prior to LGU acceptance testing.

### Acceptance Criteria for System Testing

System testing was accepted when scripted cases for FR-1 through FR-7 passed (or failed only on documented limitations such as skipped physical scans), alpha feedback was addressed for critical/high defects, and the pilot environment was stable enough for structured UAT.

---

## 4.5 User Acceptance Testing (UAT) and Evaluation

User Acceptance Testing confirmed that SmartFlow is usable and acceptable for daily document-flow work in the Municipality of Urbiztondo. Evaluation for Specific Objective 7 used an **ISO/IEC 25010**-based questionnaire administered after participants completed realistic tasks. Detailed numerical results are presented in Chapter 5 (Evaluation Results); this section describes the UAT design, procedures, instruments, and acceptance criteria.

### 4.5.1 Purpose of UAT

1. Validate that LGU users can complete core tasks without researcher intervention beyond initial training.
2. Confirm that the system supports accountability and COA-oriented routing evidence (flow history and summaries), while physical documents remain the official legal records.
3. Collect structured quality ratings across the eight ISO/IEC 25010 characteristics.
4. Obtain formal acceptance (sign-off) from the Municipal Accountant or designated LGU representative.

### 4.5.2 Participants and Setting

| Role | Participation in UAT |
| ---- | -------------------- |
| Municipal Accountant / administrator (`admin`) | Monitor municipal dashboard, review alerts, generate / export flow summaries, QR monitor, user / threshold checks |
| Department heads (`head`) — ENG, HR, BUD, ACC, TRE, MAY as applicable | Review office dashboard, processing time, and overdue items |
| Frontline clerks (`staff`) — six pilot offices | Register when folder is on desk; perform receive and forward QR scans; use document requests when folder is not yet on desk |
| System administrator (pilot: often same user as Municipal Accountant) | Confirm user approval, office, and threshold configuration tasks |

***Table 4.7 — UAT Participants***

UAT was conducted at the Municipality of Urbiztondo using municipal network resources, pilot Android smartphones, and office browsers for the React web client, consistent with the study setting. Participants were selected through purposive sampling because they perform or supervise financial document routing in the six pilot offices.

### 4.5.3 UAT Task Script

Participants followed a structured script. Tasks were role-specific.

| Step | Task | Actor | Pass if |
| ---- | ---- | ----- | ------- |
| 1 | Sign in with assigned account | All roles | Successful login to correct role interface (web and/or mobile) |
| 2 | Register a sample financial document and obtain QR / tracking ID | Clerk / authorized encoder (folder on desk) | Document appears in system; QR scannable |
| 3 | Attach or present QR with the physical packet | Clerk / encoder | Label usable at next office |
| 4 | Scan **receive (IN)** at receiving office | Clerk | Confirmation shown; history updated |
| 5 | Scan **forward (OUT)** when releasing the document | Clerk | Location / status updated for next office |
| 6 | View active documents, location, and elapsed time | Head / Accountant | Data matches recent scans |
| 7 | Review overdue / alert list (after threshold exercise or live overdue item) | Head / Accountant | Alert understandable and actionable |
| 8 | Generate a period flow summary / COA support view and export file | Accountant (`admin`) | Export opens; figures plausible vs. known test set |
| 9 | (Optional) Open Account & security — confirm profile / email / password change entry points | Any role | Screens reachable; no critical defect |
| 10 | Sign out | All roles | Session ended securely |

***Table 4.8 — Structured UAT Task Script***

Observers recorded completion (pass / fail), time on task where useful, errors, and training notes. Critical failures blocked acceptance until fixed and retested.

### 4.5.4 Evaluation Instrument (ISO/IEC 25010)

After completing UAT tasks, participants answered a questionnaire mapped to the eight ISO/IEC 25010 software quality characteristics:

1. Functional suitability  
2. Performance efficiency  
3. Compatibility  
4. Usability  
5. Reliability  
6. Security  
7. Maintainability  
8. Portability  

Each item used a five-point Likert scale (5 = Strongly Agree, 4 = Agree, 3 = Uncertain, 2 = Disagree, 1 = Strongly Disagree). Weighted mean (WM) summarized responses per characteristic and overall:

\[
WM = \frac{\sum (w \times x)}{\sum w}
\]

where \(w\) is the item weight and \(x\) is the numeric Likert response. Frequency and percentage described the distribution of answers. Verbal interpretation followed the scale approved with the research adviser (illustrative cutoffs: 4.21–5.00 Strongly Agree; 3.41–4.20 Agree; 2.61–3.40 Uncertain; 1.81–2.60 Disagree; 1.00–1.80 Strongly Disagree). Exact cutoffs used in the final manuscript shall match adviser-approved values reported in Chapter 5.

The questionnaire instruments appear in the Appendices (Survey Instruments / Questionnaires). System-generated pilot metrics (documents processed, average dwell time, late counts, completion rate) from `documents` and `movements` may supplement perception scores when discussing Objectives 5 and 6 in Chapter 5.

### 4.5.5 Acceptance Criteria and Sign-Off

UAT and evaluation were considered successful when all of the following were met:

1. Core UAT tasks (Table 4.8) were completed by representative users for each role, with no unresolved critical defects.
2. FR-1 through FR-7 remained demonstrable on the pilot build.
3. Participants completed the ISO/IEC 25010 questionnaire; results are tabulated in Chapter 5.
4. The Municipal Accountant or designated LGU representative signed off on acceptance for pilot use, acknowledging documented limitations (for example, skipped scans create incomplete trails; version 1 does not store document file content or produce financial statements).

### 4.5.6 Transition to Results

Chapter 5 presents system implementation screenshots / module descriptions and the **Evaluation Results (ISO/IEC 25010)**, including weighted means, interpretation, and discussion of findings relative to the study objectives.

---

## Capstone 2 manuscript checklist — findings from `new ver_SmartFlow_Capstone2.docx.pdf`

Working notes for the team after reviewing the Capstone 2 PDF against the **live** SmartFlow stack (`web/` React, `mobile/flutter/`, `backend/backend/api/`) and defense docs. Use this when filling the Word/PDF manuscript — **not** as thesis body text.

**Source reviewed:** `new ver_SmartFlow_Capstone2.docx.pdf` (77 pages)  
**Live demo reference:** [docs/defense/START-HERE.md](../defense/START-HERE.md) (6 offices, DV path ENG→BUD→ACC→TRE→MAY→TRE)

### Critical — must fix before oral defense

| # | What we saw in the Capstone 2 PDF | What to fix |
| - | -------------------------------- | ----------- |
| 1 | **Abstract empty** — page only has leftover `Font: Times New Roman; Size: 12` | Write Abstract (problem, SmartFlow solution, method, key results once Ch5 has numbers) |
| 2 | **Chapter 5 empty** — headings 5.1–5.3 only; no screenshots, no ISO tables, no discussion | Fill Ch5: module screenshots + ISO/IEC 25010 WM tables + interpretation |
| 3 | **Chapter 6 + References + Appendices A–D + CVs** are TOC stubs only | Write conclusions/recommendations; paste references; attach questionnaires, sample reports, screenshots, CVs |
| 4 | **§4.5 UAT** says numerical results / weighted means are “in Chapter 5,” and cutoffs “will be used in the final manuscript” | Either complete Ch5 with real scores **or** do not claim completed UAT results until data exist |
| 5 | Roles story clashes with demo — PDF implies incomplete RBAC / “future enhancement,” extra roles (e.g. COA auditor, accounting personnel as separate app roles) | Align to live roles only: **`admin`** (Municipal Accountant), **`staff`** (clerk), **`head`** (department head). Navigation shells already exist |
| 6 | Pilot offices often still **ENG · HR · BUD · ACC only** | Align scope, defs, UAT participants, and ST scenarios to **six offices:** ENG, HR, BUD, ACC, **TRE**, **MAY** (client discovery + live seed) |
| 7 | DFD / Level-1 language invents **“City Clerk,” “Municipal Approval Committee,” approval workflows** | Rewrite DFDs/activity text as **custody tracking** (register → scan IN/OUT → alerts → COA *support* reports). SmartFlow does **not** digitally approve payments or DVs |

### Important — should fix (paper vs live system)

| # | What we saw | What to fix |
| - | ----------- | ----------- |
| 8 | Capstone 1 leftovers: “follow-up interviews **are planned**”; Ch2 “**will use**” ISO / “**planned** web dashboard” | Past tense + present system: React admin + Flutter already implemented |
| 9 | Broken TOC / page map (e.g. Ch5 listed ~p.50 but mid-file is still Ch4; duplicate page refs for diagrams) | Regenerate TOC; add real **List of Tables** and **List of Figures** pages |
| 10 | Figure/table numbering chaos in Ch4 (`Figure 1.0`, `Table 1.0`…) | Renumber as **Figure 4.x / Table 4.x**; add 5.x after Ch5 content exists |
| 11 | Live features understated or missing in scope/objectives/UAT script | Mention where appropriate: **profile + email + avatar**, Account & security / change password, forgot-password, signup + admin approval, **document requests (Layer A)**, **QR image upload** on scan, admin **COA reports**, **QR monitor**, audit exceptions |
| 12 | Payroll framed as a core tracked folder type | Match client: **payslip access only / no payroll folder QR** (see START-HERE limitations) |
| 13 | Stack inconsistency — Ch3 has Flutter + React + PHP/MySQL; Ch4 testing tables lean Flutter-only | State hybrid stack everywhere; add React paths for registration/admin/COA where the demo uses web |
| 14 | Duplicate As-Is / To-Be blocks in Ch3 and Ch4 | Keep once; cross-reference the other chapter |

### Minor — polish

| # | What we saw | What to fix |
| - | ----------- | ----------- |
| 15 | **UrbizTondo** (capital T) in Acknowledgment | Standardize **Urbiztondo** |
| 16 | Typos / leftovers: `perseverance,and`, `ce ntralized`, `TTracking`, truncated UT-07 text, broken WM formula layout, encoding glitches | Proofread pass |
| 17 | Approval sheets still blank panelist lines | Expected until signed; don’t present as “final bound” without noting pending signatures |
| 18 | ERD narrative lists many DB “roles” as if separate tables | Match live schema: `users.role` string + `offices` (see `api-schema.sql`) |

### Already solid in the PDF (keep / lean on in defense)

- Chapter 1 problem framing and **COA support ≠ financial statements**
- Chapter 2 related literature (filled)
- Chapter 3 stack + **HMAC-SHA256 signed QR**, expiration, duplicate-scan blocking, state rules (aligns with `qr-token-helper.php`)
- Chapter 4 testing *structure* (unit → integration → system → UAT design) once Ch5 has scores/screenshots
- Waterfall SDLC (matches panel revision ask)

### Also fix when pasting Chapter 4 into Word

Keep this checklist in the repo; do **not** paste it into the bound manuscript. Before paste:

1. Confirm ST-01 / UAT script match the live DV demo path.
2. After real UAT, replace “results in Chapter 5” wording with actual WM values and cutoffs.
3. Renumber tables if Word already has Table 4.x elsewhere.

### Suggested fill order

1. Abstract (short)  
2. Chapter 5 screenshots + ISO tables (even draft scores labeled “pilot”)  
3. Chapter 6 + References  
4. Align Ch1 scope + Ch3/Ch4 offices/roles/DFD with the six-office demo  
5. Appendices (questionnaire, sample COA export, UAT sign-off form)  
6. Regenerate TOC / List of Tables / List of Figures  

---

*Copy Sections 4.4–4.5 into Capstone 2 Chapter IV after Section 4.3. Renumber tables if the manuscript already uses Table 4.x. Do not leave blank Chapter 5 while §4.5 claims completed evaluation results.*
