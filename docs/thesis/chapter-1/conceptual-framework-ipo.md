# SmartFlow — Conceptual Framework (IPO) & System Requirements

**Figure 1** uses four boxes: INPUT → PROCESS → OUTPUT, with EVALUATION below OUTPUT.  
Copy **short box text** into Word/Lucid; use **detailed specs** below for Chapter 1.6.1 or defense notes.

---

## Figure 1 — Copy into each box

*Tip: In Word/Lucid, use **3 sub-boxes** inside INPUT — **Knowledge** | **Software specs** | **Hardware** — so Flutter/React/PHP text fits.*

---

### INPUT

**Knowledge Requirements**
- QR tracking of physical documents (no content digitization)
- Document flow and COA support reporting
- System analysis and design (SDLC)

**Flutter Mobile App (Specs)**
- Framework: **Flutter** · Language: **Dart**
- Platform: **Android** smartphone (camera required)
- Functions: user login · QR **scan-in** / **scan-out** · receive/forward log
- Data sent: tracking ID, office, personnel, timestamp, status, remarks
- Connects to: **PHP REST API** (JSON) over LGU **Wi-Fi / LAN**

**React Web Portal (Specs)**
- Framework: **React.js** · Runs in: **Chrome / Edge / Firefox**
- Modules: document register · **QR generate & print** · real-time **dashboard**
- Modules: **delay alerts** · **COA flow reports** · **department analytics**
- Export: **PDF / Excel** · Admin: users, offices, roles, time thresholds
- Connects to: same **PHP REST API** as mobile

**Server & Database (Specs)**
- **PHP 8** — REST API (auth, documents, scans, alerts, reports)
- **MySQL** — users, offices, documents, scan_logs, thresholds, alerts
- **Apache** — hosts API + web app · **HTTPS** in production
- **RBAC** — role-based access (clerk, head, Accountant, admin)

**Hardware Requirements**
- Android phone with camera (per office)
- PC/laptop for web users · Server PC · Printer (QR labels)

**Data Inputs**
- Documents: **DV, payroll, approved budget**
- Metadata: document ID, type, origin office, reference, QR code
- Users: personnel, office, role · Processing time thresholds per department

*Pilot: Engineering · HR · Budget · Accounting*

---

### PROCESS

- Register financial documents and generate QR labels through the web portal.
- Track receiving and forwarding of physical documents through QR scanning on the Flutter mobile application.
- Record document audit trail (office, personnel, timestamp, status) in PHP and MySQL.
- Monitor document location, processing time, and overdue status with automated delay alerts on the web portal.
- Generate COA flow summary reports and department performance analytics on the web portal.

---

### OUTPUT

**Deployed System (with specs)**
- **Flutter app** — Android; QR scan handoff; mobile audit trail view
- **React portal** — dashboard, alerts, COA reports (monthly/quarterly/annual), analytics
- **PHP REST API + MySQL** — centralized audit trail and report data

**System Features Produced**
- Unique **QR labels** per financial document
- **Real-time** location and time-at-office on web dashboard
- **Scan-in / scan-out** history (office, user, date/time)
- **Overdue alerts** · **COA flow summaries** · **bottleneck analytics**

**Organizational Results**
- Faster document location · Office accountability
- Less phone/chat follow-up · Better data for COA support (not financial statements)

---

### EVALUATION

**ISO/IEC 25010** — Functional Suitability, Performance Efficiency, Compatibility, Usability, Reliability, Security, Maintainability, Portability.

**Pilot users:** Accounting staff, department heads, frontline clerks (Engineering, HR, Budget, Accounting).

---

### Caption

*Figure 1. Input–Process–Output Model of the SmartFlow System*

---

## Software & System Requirements (Detailed Specs)

*Aligned with [`../srs.md`](../srs.md) and seven specific objectives.*

### 1. System Architecture

| Layer | Component | Specification |
|-------|-----------|-----------------|
| Presentation | Flutter mobile app | Android 8.0+ (API 26+); camera for QR scan; receives/forwards documents |
| Presentation | React web portal | Modern browser (Chrome, Edge, Firefox); responsive dashboard and reports |
| Application | PHP REST API | RESTful endpoints for auth, documents, scans, alerts, reports; JSON payloads |
| Data | MySQL database | Relational store: users, offices, roles, documents, scan_logs, thresholds, alerts |
| Infrastructure | Apache HTTP Server | Hosts API and web build; HTTPS in production on LGU server |

**Integration:** Flutter and React share one API and one database; scan on mobile updates web dashboard in near real time.

---

### 2. Mobile Application (Flutter)

| ID | Requirement |
|----|-------------|
| M-01 | User login with role validation (department user, head, Accounting, admin) |
| M-02 | Scan QR on physical folder; log **receive** or **forward** action |
| M-03 | Capture document tracking ID, office, personnel, date/time, optional remarks |
| M-04 | Append each scan to **immutable audit trail** (no casual delete of handoff records) |
| M-05 | View current status of recently scanned documents (optional queue list) |
| M-06 | Operate on municipal **LAN or Wi-Fi**; offline queue optional (future) |
| M-07 | Simple UI for low technology knowledge (large buttons, minimal steps) |

**Maps to objectives:** 2 (scan-and-forward), 7 (evaluation with frontline users).

---

### 3. Web Administrator Portal (React)

| ID | Requirement |
|----|-------------|
| W-01 | Register financial document: type (DV / payroll / budget), reference, origin office, date |
| W-02 | Generate and **print unique QR code** per document at origin |
| W-03 | **Real-time dashboard:** active documents, current office, time at office, overdue flag |
| W-04 | **Automated alerts** when processing time exceeds department threshold |
| W-05 | **COA flow summaries:** monthly, quarterly, annual — totals processed, avg. time per department, late counts, completion rates |
| W-06 | **Department analytics:** submission speed, late counts, bottleneck patterns |
| W-07 | Search/filter by tracking ID, type, office, status, date range |
| W-08 | Export reports to **PDF/Excel** for Accounting and COA support files |
| W-09 | Admin: manage users, offices, roles, processing time thresholds, routes |
| W-10 | Role-based screens: admin, Municipal Accountant, department head, registry encoder |

**Maps to objectives:** 1, 3, 4, 5, 6, 7.

---

### 4. Backend — PHP REST API & MySQL

| ID | Requirement |
|----|-------------|
| B-01 | Authenticate users; issue session/token; enforce role on every request |
| B-02 | CRUD for documents (metadata only — no voucher/payroll file upload in v1) |
| B-03 | Record scan events; compute dwell time per office |
| B-04 | Compare dwell time vs. threshold; generate overdue alerts |
| B-05 | Aggregate data for COA flow reports and department analytics |
| B-06 | Audit log retention per LGU policy |
| B-07 | API consumed by both Flutter and React clients |

**Database (minimum entities):** `users`, `roles`, `offices`, `documents`, `document_types`, `scan_logs`, `thresholds`, `alerts`, `report_snapshots` (optional).

---

### 5. Security & Compliance

| ID | Requirement |
|----|-------------|
| S-01 | Secure login; password policy per LGU IT |
| S-02 | **Role-based access control** (RBAC) on mobile and web |
| S-03 | **HTTPS** for production |
| S-04 | QR label shows **tracking ID only** — not full personal/financial content (Data Privacy Act of 2012) |
| S-05 | Movement metadata and scan logs stored on LGU-controlled server |

---

### 6. Non-Functional Requirements

| ID | Category | Specification |
|----|----------|-----------------|
| NFR-01 | Platform | Flutter on LGU Android phones; React on desktop/laptop browsers |
| NFR-02 | Usability | QR handoff logged in seconds; minimal training for clerks |
| NFR-03 | Performance | Dashboard and scan feedback within acceptable LAN response time |
| NFR-04 | Reliability | Centralized MySQL backup; server uptime responsibility of LGU |
| NFR-05 | Maintainability | Modular API; documented endpoints for future LGU MIS integration |
| NFR-06 | Scope | No RFID/NFC; no document content OCR; no financial statement generation |

---

### 7. Functional Requirements ↔ Objectives

| Objective | Module | Spec IDs |
|-----------|--------|----------|
| 1 — QR tagging | Web | W-01, W-02 |
| 2 — Scan-and-forward | Mobile + API | M-02–M-04, B-03 |
| 3 — Dashboard | Web + API | W-03, B-03–B-05 |
| 4 — Alerts | Web + API | W-04, B-04 |
| 5 — COA reports | Web + API | W-05, W-08, B-05 |
| 6 — Analytics | Web + API | W-06, B-05 |
| 7 — Evaluation | All + ISO 25010 | Pilot UAT; see EVALUATION box |

---

### 8. Out of Scope (v1)

- Digitizing or storing voucher/payroll/budget **file content**
- RFID, NFC, IoT sensors
- Financial statement generation (Accounting office)
- Pilot beyond Engineering, HR, Budget, Accounting
- Non–COA-critical document types

---

## Optional narrative (1 paragraph under Figure 1)

SmartFlow addresses manual inter-department routing of financial documents in the Municipality of Urbiztondo. The **input** consists of knowledge, software, system, hardware, and data requirements needed to develop the hybrid application. The **process** covers document registration, QR-based tracking, audit trail recording, monitoring with alerts, and generation of COA-oriented reports. The **output** is the deployed SmartFlow system and improved document visibility and accountability. The **evaluation** measures system quality using ISO/IEC 25010 during pilot testing with Accounting staff, department heads, and frontline clerks.

---

## Compact INPUT (if one small box only)

Use this shorter block if the diagram has limited space:

**Software specs:** **Flutter/Dart** (Android, QR scan-in/out) · **React.js** (register, dashboard, alerts, COA reports) · **PHP REST API** · **MySQL** · **Apache/HTTPS** · **RBAC**

---

## Figure 1 checklist

- [ ] Four boxes drawn (INPUT → PROCESS → OUTPUT; EVALUATION below)
- [ ] INPUT includes **Flutter / React / PHP** spec bullets (or compact line)
- [ ] Caption: *Figure 1. Input–Process–Output Model of the SmartFlow System*
- [ ] Insert into Chapter I §1.6.1

---

## Stack (final)

| Part | Technology |
|------|------------|
| Mobile | Flutter (Dart), Android |
| Web | React |
| Server | PHP REST API, MySQL, Apache |

**One-line defense:** *SmartFlow tracks paper financial documents with QR on Flutter, manages reports on React, and stores data on PHP/MySQL to support Accounting and COA compliance in Urbiztondo.*
