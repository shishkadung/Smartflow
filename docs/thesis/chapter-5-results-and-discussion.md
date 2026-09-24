# CHAPTER 5: RESULTS AND DISCUSSION

Paste into Capstone 2 after Chapter 4. Insert real screenshots where marked. **ISO/IEC 25010 numbers:** replace every `[WM]` / `[n]` / `[INSERT]` cell after you encode the actual questionnaire responses — do not invent survey scores for the bound manuscript.

---

## 5.1 System Implementation

This chapter presents the implemented SmartFlow system as deployed for pilot use in the Municipality of Urbiztondo, then discusses evaluation results for Specific Objective 7 (ISO/IEC 25010–based User Acceptance Testing). SmartFlow is a **hybrid** application: a **React (Vite)** web client for browser-based office work, a **Flutter** Android client for QR scanning and mobile role screens, a **PHP** REST API on Apache, and a **MySQL** database. Version 1 tracks **physical folder custody** (metadata and movement). It does **not** store scanned document images or produce COA financial statements.

Pilot offices in the implemented system are **Engineering (ENG)**, **Human Resources (HR)**, **Budget (BUD)**, **Accounting (ACC)**, **Treasury (TRE)**, and **Mayor’s Office (MAY)**. Application roles are **`staff`** (clerk), **`head`** (department head), and **`admin`** (Municipal Accountant / system administrator).

### 5.1.1 Main Interface / Dashboard

After successful sign-in, users land on a role-appropriate home view.

- **Clerk (`staff`):** office desk summary (received / sent / on desk), shortcuts to Scan, Register, Requests, History, and Alerts.
- **Department head (`head`):** office snapshot (in office, overdue, average time) scoped to that office only.
- **Municipal Accountant (`admin`):** municipal overview (active documents, overdue, pending sign-ups) plus access to Users, COA reports, QR monitor, and system status.

*[Insert Figure 5.1 — Clerk dashboard (web or mobile)]*  
*[Insert Figure 5.2 — Admin municipal dashboard]*

***Figure 5.1 / 5.2 — Role dashboards after login***

### 5.1.2 Authentication, Profile, and Account Security

Users authenticate with username and password. Pending sign-up requests remain blocked until an administrator approves them. From the office badge / account menu, users can open **See profile** (identity and desk stats) and **Account & security** (profile photo, name, username, **email** for password reset, change password, log out). Role and office assignment remain read-only for the signed-in user.

*[Insert Figure 5.3 — Login screen]*  
*[Insert Figure 5.4 — Account & security / Edit profile]*

***Figure 5.3 / 5.4 — Authentication and account security***

### 5.1.3 Document Registration and QR Generation (FR-1)

When a physical folder is **on the clerk’s desk**, the clerk registers it (document type, title, reference, origin office). SmartFlow creates a unique tracking identity and a **signed QR** payload (HMAC-based; not a raw unprotected ID). The QR can be displayed for printing or for camera scan / image upload on the Scan screen.

*[Insert Figure 5.5 — Register document form]*  
*[Insert Figure 5.6 — Generated QR / registration success]*

***Figure 5.5 / 5.6 — Registration and QR tagging***

### 5.1.4 Scan and Forward Tracking (FR-2)

Clerks log handoffs by scanning the QR (**receive / IN** when the folder arrives; **forward / OUT** when releasing to another office). The system records office, user, timestamp, and action in the movement / audit trail. Illegal transitions (for example, OUT before IN, or duplicate IN) are rejected and can be reviewed on the administrator **QR monitor**.

Primary pilot trail for a disbursement voucher (client priority):

**ENG → BUD → ACC → TRE → MAY → TRE**

The application tracks the folder’s location; it does **not** approve payment in-app. Treasury payment release may be reflected on the related **document request** ticket where that workflow is used.

*[Insert Figure 5.7 — Scan screen (camera or upload)]*  
*[Insert Figure 5.8 — Document history / trail]*

***Figure 5.7 / 5.8 — Scan handoff and custody trail***

### 5.1.5 Document Requests (Layer A)

When the folder is **not yet** on the requesting office’s desk, staff create a **formal document request** (ticket) instead of registering. The handler office can accept or decline; fulfillment still requires physical custody steps (register + scan) when the folder moves. This matches municipal practice and avoids confusing “register” with “ask for a file.”

*[Insert Figure 5.9 — Document requests inbox / create request]*

***Figure 5.9 — Formal document request (Layer A)***

### 5.1.6 Alerts and Thresholds (FR-4)

Processing thresholds (`max_hours` per office / document type) drive overdue alerts. Clerks and heads see office-scoped alerts; the Municipal Accountant sees municipal overdue items. Thresholds are configurable by the administrator.

*[Insert Figure 5.10 — Alerts list]*  
*[Insert Figure 5.11 — Admin processing thresholds (optional)]*

***Figure 5.10 / 5.11 — Overdue alerts and thresholds***

### 5.1.7 COA Support Reports and Analytics (FR-5, FR-6)

The administrator can open municipal **COA support** summaries (period totals, on-time / delayed indicators, completion-oriented counts) and related analytics. These outputs support Accounting’s preparation for COA; they are **not** the financial statements themselves.

*[Insert Figure 5.12 — COA / compliance summary]*  
*[Insert Figure 5.13 — QR scan monitor / audit rejects]*

***Figure 5.12 / 5.13 — COA support view and QR audit monitor***

### 5.1.8 Summary of Implemented Modules vs Objectives

| Specific objective | Implemented module(s) | Status |
| ------------------ | --------------------- | ------ |
| 1 — QR tagging at origin | Register + signed QR | Implemented |
| 2 — Scan-and-forward audit trail | Scan IN/OUT + movements / history | Implemented |
| 3 — Real-time dashboard | Role dashboards (staff / head / admin) | Implemented |
| 4 — Automated delay alerts | Thresholds + Alerts | Implemented |
| 5 — COA-aligned flow summaries | Admin reports / exports | Implemented (pilot) |
| 6 — Department performance / bottlenecks | Head / admin analytics views | Implemented (pilot) |
| 7 — Usability evaluation | UAT script + ISO/IEC 25010 questionnaire | See Section 5.2 |

***Table 5.1 — Mapping of Implemented Modules to Specific Objectives***

---

## 5.2 Evaluation Results (ISO/IEC 25010)

User Acceptance Testing followed the design in Chapter 4 (Section 4.5). After completing the structured task script, participants answered an ISO/IEC 25010–based questionnaire using a five-point Likert scale (5 = Strongly Agree … 1 = Strongly Disagree). Weighted means (WM) were computed per characteristic and overall.

### 5.2.1 Respondents

| Role | Office(s) | Number of respondents `[n]` |
| ---- | --------- | --------------------------- |
| Municipal Accountant / admin | ACC | `[n]` |
| Department head | ENG / HR / BUD / ACC / TRE / MAY | `[n]` |
| Clerk / staff | ENG / HR / BUD / ACC / TRE / MAY | `[n]` |
| **Total** | | **`[n]`** |

***Table 5.2 — UAT / Questionnaire Respondents***

### 5.2.2 Verbal Interpretation Scale

| Weighted mean | Verbal interpretation |
| ------------- | --------------------- |
| 4.21 – 5.00 | Strongly Agree |
| 3.41 – 4.20 | Agree |
| 2.61 – 3.40 | Uncertain |
| 1.81 – 2.60 | Disagree |
| 1.00 – 1.80 | Strongly Disagree |

***Table 5.3 — Verbal Interpretation of Weighted Means***  
*(Confirm exact cutoffs with the research adviser before final binding.)*

### 5.2.3 Results by ISO/IEC 25010 Characteristic

| Characteristic | WM `[insert]` | Interpretation `[insert]` |
| -------------- | ------------- | ------------------------- |
| Functional suitability | `[WM]` | `[…]` |
| Performance efficiency | `[WM]` | `[…]` |
| Compatibility | `[WM]` | `[…]` |
| Usability | `[WM]` | `[…]` |
| Reliability | `[WM]` | `[…]` |
| Security | `[WM]` | `[…]` |
| Maintainability | `[WM]` | `[…]` |
| Portability | `[WM]` | `[…]` |
| **Overall** | **`[WM]`** | **`[…]`** |

***Table 5.4 — ISO/IEC 25010 Evaluation Results***

*[Optional: Insert Figure 5.14 — Bar chart of WM by characteristic]*

### 5.2.4 Pilot Operational Metrics (optional supplement)

If available from the pilot database for the UAT period:

| Metric | Value `[insert]` |
| ------ | ---------------- |
| Documents registered | `[…]` |
| Scan events (IN + OUT) | `[…]` |
| Overdue alerts raised | `[…]` |
| Average dwell time (selected offices) | `[…]` |
| Rejected illegal / duplicate scans | `[…]` |

***Table 5.5 — Pilot Operational Metrics (from `documents` / `movements`)***

These metrics support discussion of Objectives 5 and 6; they do not replace the ISO perception scores for Objective 7.

---

## 5.3 Discussion of Findings

### 5.3.1 Alignment with Objectives 1–6

The implemented modules demonstrate that SmartFlow can tag physical packets with signed QR codes, log handoffs into a durable audit trail, surface location and overdue status on role dashboards, and produce COA-oriented flow summaries for the Municipal Accountant. The six-office pilot path for disbursement vouchers reflects client-validated routing (including Treasury and Mayor’s Office), while keeping payment approval outside the tracking app.

### 5.3.2 Alignment with Objective 7

*[After scores exist:]* Discuss which ISO characteristics scored highest/lowest, whether overall WM falls in Agree / Strongly Agree, and how comments from the Municipal Accountant, heads, and clerks explain usability (scan discipline, training, LAN). Relate findings to local studies that also used ISO/IEC 25010 for QR or LGU systems (Chapter 2).

### 5.3.3 Limitations Observed in Pilot

1. **Scan discipline** — skipped scans create gaps; SmartFlow cannot invent missing handoffs.  
2. **Network / device readiness** — pilot depends on municipal LAN/Wi-Fi and available Android / browser devices.  
3. **Scope of documents** — version 1 focuses on custody of selected financial/administrative folders; payroll remains **payslip access only** (no payroll-folder QR), per client clarification.  
4. **COA role** — reports support preparation; they do not replace Accounting’s financial statements.  
5. **UAT sample size** — purposive pilot sample; results generalize to Urbiztondo pilot offices, not all LGUs.

### 5.3.4 Implications for Deployment

Results support **pilot use** with training, threshold tuning, and administrator oversight (user approval, QR monitor). Wider rollout should wait until scan habits stabilize and hosting/security hardening is completed with LGU IT.

---

*Screenshot tip: use the defense DV script in `docs/defense/START-HERE.md` so figures match what you demo to the panel.*
