# SmartFlow Chapters 1-4 Accuracy Replacement Checklist

Based on the client-validated workflow and the current SmartFlow implementation.

## Global Replacements

Apply these corrections throughout the manuscript.

- [ ] `four pilot offices` -> `six pilot offices: Engineering, Human Resources, Budget, Accounting, Treasury, and the Mayor's Office`
- [ ] `scan_logs` -> `movements`
- [ ] `user_accounts` -> `users`
- [ ] `QR encryption` -> `QR signing`
- [ ] `QR decryption` -> `QR verification and decoding`
- [ ] `real-time dashboard` -> `centralized dashboard showing the latest retrieved data`
- [ ] `PDF or Excel` -> `PDF-oriented output and CSV`
- [ ] `COA compliance system` -> `COA-oriented custody tracking and reporting support system`
- [ ] `completion rate` -> `on-time, unforwarded, and delayed custody percentages`
- [ ] `administrator scans documents` -> `routine scanning is performed by authorized staff and department heads`
- [ ] `COA Auditor is a SmartFlow user` -> `COA remains external and receives support files prepared by Accounting`

---

## Chapter 1 - Introduction

### Document Scope

- [ ] Replace any tracked-document list containing payroll with:

> SmartFlow tracks Disbursement Vouchers, Approved Budgets, and other authorized physical document folders. Payroll is limited to payslip access and is not registered as a QR-tracked folder in Phase 1.

### Pilot Offices

- [ ] Replace the old office scope with:

> The pilot implementation covers Engineering, Human Resources, Budget, Accounting, Treasury, and the Mayor's Office.

### Registration Rule

- [ ] Replace statements saying Accounting registers all documents with:

> An authorized user from the office physically holding an unregistered folder registers the document and generates its signed QR label.

- [ ] Add the holder/request rule:

> If the office physically holds the folder, it may register and track it. If the folder is not physically held by the requesting office, the user must create a Document Request instead.

### Validated DV Route

- [ ] Use this route consistently:

> ENG -> BUD -> ACC -> TRE -> MAY -> TRE, with return to ACC when required for filing.

### System Boundary

- [ ] Replace statements implying financial approval or payment processing with:

> SmartFlow records physical custody, document location, movement history, and processing duration. It does not approve vouchers, prepare checks, release payments, execute official signatures, or replace existing municipal financial procedures.

### COA Support

- [ ] Replace strong COA compliance claims with:

> SmartFlow provides COA-oriented custody records and flow summaries to support Accounting's audit preparation. It does not generate official COA reports or financial statements.

### QR Security

- [ ] Use this description:

> SmartFlow uses an `SF1.{payload}.{signature}` QR format protected by an HMAC-SHA256 signature. The QR is valid for 180 days and may be reprinted with a fresh token when necessary.

- [ ] Do not describe the QR token as encrypted, hidden, or decrypted.
- [ ] State that the QR payload contains:
  - Document tracking ID
  - Issuance timestamp
  - Expiration timestamp

### Beneficiaries

- [ ] Include staff and department heads from all six pilot offices.

### Specific Objectives

Keep seven objectives, aligned with the following:

1. Signed QR tagging
2. Six-office custody trail
3. Centralized dashboards
4. Delay alerts using processing thresholds
5. Monthly, quarterly, and annual COA-oriented summaries
6. Office analytics
7. ISO/IEC 25010 usability evaluation

---

## Chapter 2 - Related Literature and Studies

### Important Rule

- [ ] Do not alter facts describing other researchers' systems, even when those studies mention payroll, SMS, encryption, or real-time tracking.
- [ ] Revise only statements describing or comparing SmartFlow.

### Dashboard Information

- [ ] Replace:

> SmartFlow displays document locations in real time.

With:

> SmartFlow centrally records document movements and displays the latest custody information when the dashboard is retrieved or refreshed.

### Alerts

- [ ] Replace:

> SmartFlow replaces SMS notifications with QR tags.

With:

> SmartFlow uses in-application alerts and QR-based custody records instead of relying on SMS notifications.

### COA Claims

- [ ] Replace:

> SmartFlow ensures COA compliance.

With:

> SmartFlow supports audit preparation through chronological custody records and COA-oriented summaries.

### Expected Benefits

- [ ] Do not claim that SmartFlow guarantees fewer missing documents, fewer delays, or complete legal compliance.
- [ ] Use:

> SmartFlow is intended to improve visibility, accountability, and audit preparation.

### QR Comparisons

- [ ] Replace `encrypted QR` with:

> HMAC-SHA256-signed QR payload with server-side integrity and expiration verification.

---

## Chapter 3 - Technical Background

### System Architecture

- [ ] Replace direct database-access wording with:

> Flutter and React communicate with the PHP REST API over HTTPS. The PHP API performs validation and reads from or writes to the MySQL database. Neither client connects directly to MySQL.

### Dashboard Updates

- [ ] Replace:

> Every mobile scan immediately appears on the web dashboard in real time.

With:

> Every accepted movement is stored centrally and becomes available to the web and mobile dashboards when they retrieve or refresh the latest data.

### Client Capabilities

- [ ] Use:

> Both Flutter and React provide authorized registration, scanning, requests, history, and alerts. React additionally provides desktop-oriented administration, monitoring, analytics, and reporting.

### Administrator Responsibilities

- [ ] Use:

> The administrator primarily handles signup approval, users, offices, processing thresholds, municipality-wide monitoring, QR and audit exceptions, system status, and COA-oriented reports. Routine physical handoff scanning is assigned to staff and department heads.

### Database Tables

- [ ] Use these runtime tables:
  - `users`
  - `offices`
  - `documents`
  - `movements`
  - `document_requests`
  - `signup_requests`
  - `processing_thresholds`
  - `audit_logs`
  - `password_resets`
  - `auth_tokens`

- [ ] Keep `qr_tokens` only if it exists in the final deployed MySQL schema export.

### Delay Alerts

- [ ] Replace claims about alerts being automatically sent with:

> SmartFlow computes overdue and unconfirmed movement conditions from movement records and processing thresholds and displays them to authorized users.

### QR Security Explanation

- [ ] Replace encryption/decryption explanations with:

> HMAC-SHA256 provides integrity and authenticity, not encryption. SmartFlow detects modified or forged payloads. QR expiration, five-minute verified scan sessions, custody-state validation, destination validation, duplicate blocking, and audit logging reduce unauthorized or repeated use.

- [ ] Do not claim that HMAC prevents users from photographing or copying a valid QR image.

### Privacy Statement

- [ ] Replace automatic Data Privacy Act compliance claims with:

> The QR payload excludes document contents and personal financial information, supporting data minimization. Formal Data Privacy Act compliance remains subject to the LGU's privacy assessment and policies.

### Report Metrics

- [ ] Replace unsupported average-processing and completion-rate claims with:
  - Documents within the selected period
  - Documents processed by office
  - On-time handoffs
  - Unforwarded OUT movements
  - Delayed movements
  - Audit and custody exceptions

---

## Chapter 4 - Methodology, Testing, and Evaluation

### SDLC

- [ ] Keep the Waterfall SDLC:

> Requirements -> Design -> Development -> Testing -> Deployment -> Maintenance

- [ ] Remove Agile, iterative sprint, and seven-sprint wording.

### Diagram Replacements

- [ ] **Figure 1.0 - Waterfall SDLC:** Retain with minor wording cleanup.
- [ ] **Figure 1.1 - DFD Level 0:** Use the updated context diagram.
- [ ] **Figure 1.2 - Use Case Diagram:** Replace the old Accounting/System Admin/COA Auditor diagram.
- [ ] **Figure 1.3 - DFD Level 1:** Replace the old diagram containing approval processes, `Scan Logs`, and `Transactions`.
- [ ] **Figure 1.4 - ERD:** Regenerate from the final deployed MySQL schema.
- [ ] **Figure 1.5 - Software Architecture:** Replace the old four-office and web-only QR-generation architecture.
- [ ] **Figure 1.6 - Employee Flowchart:** Replace with the Staff/Clerk flowchart.
- [ ] **Figure 1.7 - Department Head Flowchart:** Replace the four-head/document-approval workflow.
- [ ] **Figure 1.8 - System Admin Flowchart:** Replace with the Municipal Accountant/Admin workflow.

### Section 4.3.3

- [ ] If Figure 1.3 is a DFD, describe it as:

> Figure 1.3 presents the SmartFlow Data Flow Diagram Level 1.

- [ ] Do not call it an Activity Diagram unless the inserted figure is actually an activity diagram.

### Department Head Responsibilities

- [ ] Replace document-approval wording with:

> Department heads may approve, reject, or fulfill Document Requests addressed to their assigned office. They do not approve or reject financial documents through SmartFlow.

### UAT Participants

- [ ] Replace `frontline clerks from four pilot offices` with:

> Authorized staff and department heads from all six pilot offices, together with the Municipal Accountant/System Administrator.

### Registration Tests

- [ ] Remove payroll from SmartFlow registration test data.
- [ ] Use:
  - Disbursement Voucher
  - Approved Budget
  - Others

### Unit and Integration Test Corrections

- [ ] `scan_logs row created` -> `movement record created`
- [ ] `current office updated` -> `current custody derived from the latest movement`
- [ ] `alert record created` -> `overdue condition computed and displayed`
- [ ] `roles table` -> `users.role`
- [ ] `Accountant/authorized encoder` -> `authorized user from the office physically holding the folder`

### Report Testing

- [ ] Use:

> Verify documents within the selected period, documents processed by office, and on-time, unforwarded, and delayed custody percentages using the `documents` and `movements` tables.

### Section Structure

- [ ] Section 4.3.5 is titled **Data Dictionary** but currently contains the Software Architecture figure.
- [ ] Add the actual data dictionary or rename and reorganize the section.

### Formatting

- [ ] Ensure all flowcharts remain readable when inserted at manuscript size.
- [ ] Remove remaining red revision highlights before final submission.
- [ ] Use one consistent figure-numbering format throughout the manuscript.
- [ ] Keep captions short and place detailed explanations in the body text.

---

## Final Consistency Checklist

- [ ] Six pilot offices are used consistently.
- [ ] Payroll is never presented as a QR-tracked folder.
- [ ] Only the physical holder registers a folder.
- [ ] Document Requests are separate from QR custody movements.
- [ ] The DV route is consistent.
- [ ] Treasury records payment release on the related request; SmartFlow does not release payments.
- [ ] Roles are only `staff`, `head`, and `admin`.
- [ ] Treasury and Mayor are offices, not application roles.
- [ ] COA is external to SmartFlow.
- [ ] COA exports are restricted to authorized Accounting personnel.
- [ ] HMAC signing is never called encryption.
- [ ] Dashboard data is not described as push-based real-time data.
- [ ] Runtime database names match the final schema export.
- [ ] Figures and their narratives describe the same workflow.
