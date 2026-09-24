# Data Dictionary — paste into Chapter II (Word)

**Replaces old draft:** four entities (`offices`, `users`, `documents`, `movements`) with `code` on offices, string PK on documents, and `IN`/`OUT` status.

**Current design:** eight tables in `backend/schema.sql`, Figure 2-6 in [`erd.md`](erd.md).

---

## Intro paragraph (paste before Table 2.7)

The database structure is defined in **backend/schema.sql** and consists of **eight entities**: **roles**, **offices**, **users**, **document_types**, **documents**, **scan_logs**, **thresholds**, and **alerts**. The design supports role-based access for the system administrator, Municipal Accountant, department heads, and clerks; metadata for disbursement vouchers, payroll records, and approved budgets; an immutable QR handoff audit trail; processing-time rules; and overdue notifications. Document file content and financial statements are not stored. The primary key for documents is a surrogate integer (**document_id**); the **tracking_code** is the unique value encoded in the QR label for scanning and manual verification.

---

## Table 2.7 — Entity: roles

| Attribute | Type | Description |
|-----------|------|-------------|
| **role_id** | INT, PK, AI | Role identifier |
| role_name | VARCHAR(50) | `admin`, `accountant`, `head`, `clerk` |

---

## Table 2.8 — Entity: offices

| Attribute | Type | Description |
|-----------|------|-------------|
| **office_id** | INT, PK, AI | Office identifier |
| office_name | VARCHAR(100) | Pilot office name (Engineering, HR, Budget, Accounting) |

---

## Table 2.9 — Entity: users

| Attribute | Type | Description |
|-----------|------|-------------|
| **user_id** | INT, PK, AI | User identifier |
| username | VARCHAR(50), UNIQUE | Login username |
| password_hash | VARCHAR(255) | Bcrypt-hashed password |
| full_name | VARCHAR(100) | Display name |
| office_id | INT, FK → offices | Assigned office |
| role_id | INT, FK → roles | System role |
| is_active | BOOLEAN | Active account (deactivated users cannot log in) |

---

## Table 2.10 — Entity: document_types

| Attribute | Type | Description |
|-----------|------|-------------|
| **type_id** | INT, PK, AI | Document type identifier |
| type_name | VARCHAR(50) | Disbursement Voucher, Payroll Record, Approved Budget |

---

## Table 2.11 — Entity: documents

| Attribute | Type | Description |
|-----------|------|-------------|
| **document_id** | INT, PK, AI | Internal document record identifier |
| tracking_code | VARCHAR(50), UNIQUE | QR label value (e.g. `SF-2026-000123`) |
| type_id | INT, FK → document_types | Financial document type |
| reference_no | VARCHAR(100) | Office reference number on the physical file |
| origin_office_id | INT, FK → offices | Office where the document was registered |
| current_office_id | INT, FK → offices | Latest location (dashboard) |
| status | VARCHAR(30) | e.g. `active`, `completed` |
| created_at | DATETIME | Registration timestamp |
| completed_at | DATETIME, NULL | When marked complete by Municipal Accountant |

*No `title`, `description`, or file-content columns — metadata only, per project scope.*

---

## Table 2.12 — Entity: scan_logs

*Replaces old entity **movements** (`IN`/`OUT`). Actions are **receive** and **forward**.*

| Attribute | Type | Description |
|-----------|------|-------------|
| **scan_id** | INT, PK, AI | Scan record identifier |
| document_id | INT, FK → documents | Associated document |
| office_id | INT, FK → offices | Office where scan occurred |
| user_id | INT, FK → users | Scanning personnel |
| action | VARCHAR(20) | `receive` or `forward` |
| scanned_at | DATETIME | Scan timestamp |
| remarks | TEXT, NULL | Optional note |

*Append-only audit trail; records are not casually deleted (NFR-04).*

---

## Table 2.13 — Entity: thresholds

| Attribute | Type | Description |
|-----------|------|-------------|
| **threshold_id** | INT, PK, AI | Threshold rule identifier |
| office_id | INT, FK → offices | Office the rule applies to |
| document_type_id | INT, FK → document_types | Document type the rule applies to |
| max_hours | INT | Maximum hours at office before overdue |
| is_active | BOOLEAN | Administrator can enable or disable the rule |

*Unique pair: (`office_id`, `document_type_id`).*

---

## Table 2.14 — Entity: alerts

| Attribute | Type | Description |
|-----------|------|-------------|
| **alert_id** | INT, PK, AI | Alert identifier |
| document_id | INT, FK → documents | Overdue document |
| office_id | INT, FK → offices | Office where document is overdue |
| triggered_at | DATETIME | When alert was created |
| is_resolved | BOOLEAN | Cleared when document moves or is completed |

---

## Table 2.15 — Cardinality relationships

| Relationship | Cardinality | Meaning |
|--------------|-------------|---------|
| roles → users | **1 : M** | One role, many users |
| offices → users | **1 : M** | One office, many users |
| document_types → documents | **1 : M** | One type, many documents |
| offices → documents (origin) | **1 : M** | One office originates many documents |
| offices → documents (current) | **1 : M** | One office currently holds many documents |
| documents → scan_logs | **1 : M** | One document, many scan events |
| users → scan_logs | **1 : M** | One user, many scans |
| offices → scan_logs | **1 : M** | One office, many scan events |
| offices + document_types → thresholds | **M : M** (via thresholds) | Processing rules per office and type |
| documents → alerts | **1 : M** | One document may generate multiple alerts over time |
| offices → alerts | **1 : M** | One office, many overdue alerts |

**Closing sentence (paste after Table 2.15):**

The **tracking_code** on each document is unique and is printed on the QR label so the Flutter mobile application, React web portal, and MySQL database use the same identifier during scanning, dashboard display, and audit review. On registration, **current_office_id** is set to the document’s starting office; each **receive** or **forward** scan appends a **scan_logs** row and updates **current_office_id**. COA flow reports and department analytics are computed from **documents** and **scan_logs** at report time rather than stored as separate snapshot tables in version 1.

---

## Old → new mapping (delete from thesis)

| Old | New |
|-----|-----|
| 4 entities | 8 entities |
| `offices.code` (ACC, BUD…) | `office_name` only |
| `users.role` ENUM | `role_id` → **roles** table |
| `documents.id` VARCHAR PK | `document_id` INT PK + `tracking_code` UNIQUE |
| `documents.title`, `description`, `date_registered` | `reference_no`, `created_at`; no title/description |
| `documents.created_by` | Not in v1 (optional later) |
| **movements** `IN`/`OUT` | **scan_logs** `receive`/`forward` |
| — | **document_types**, **thresholds**, **alerts** added |
