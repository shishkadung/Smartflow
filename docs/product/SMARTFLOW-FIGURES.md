# Updated SmartFlow Figures

Aligned with the running system (PHP API, Flutter app, React web, MySQL `smartflow` schema).

## Contents

- [Roles and Actors](#roles-and-actors)
- [Figure 1.1 Context Diagram](#figure-11-context-diagram)
- [Figure 1.2 Use Case Diagram](#figure-12-use-case-diagram)
- [Figure 1.3A Staff/Clerk Activity Diagram](#figure-13a-staffclerk-activity-diagram)
- [Figure 1.3B Department Head Activity Diagram](#figure-13b-department-head-activity-diagram)
- [Figure 1.3C Municipal Accountant/Admin Activity Diagram](#figure-13c-municipal-accountantadmin-activity-diagram)
- [Figure 1.3D General Document Lifecycle](#figure-13d-general-document-lifecycle)
- [Figure 1.3E Disbursement Voucher Workflow](#figure-13e-disbursement-voucher-workflow)
- [Figure 1.3F Document Request Workflow](#figure-13f-document-request-workflow)
- [Figure 1.4 Entity Relationship Diagram](#figure-14-entity-relationship-diagram)
- [Figure 1.5 Software Architecture](#figure-15-software-architecture)
- [Department-Specific Flows](#department-specific-flows)
- [What Must Not Appear in Any Figure](#what-must-not-appear-in-any-figure)
- [Related Paper Fixes](#related-paper-fixes)

---

## Roles and Actors

SmartFlow has **three system roles** (`users.role`): `staff`, `head`, and `admin`. Every user belongs to exactly one office (`users.office_id`). The pilot offices are ENG, HR, BUD, ACC, TRE, and MAY.

| Actor in figures | System role | Office |
|---|---|---|
| Staff/Clerk | `staff` | Any pilot office |
| Department Head | `head` | Any pilot office (office-scoped view) |
| Municipal Accountant/Admin | `admin` | Accounting (ACC) |
| Treasury Personnel | `staff` or `head` | Treasury (TRE) |

> **Note:** "Treasury Personnel" is not a separate role. It is a staff or head account assigned to the Treasury office. Treasury-specific actions (such as recording payment released) are allowed because of the office, not a special role.

---

## Figure 1.1 Context Diagram

### Central Process

**SmartFlow Document Tracking and Management System**

### External Entities

1. Staff/Clerk
2. Department Head
3. Municipal Accountant/System Administrator
4. Treasury Personnel (staff/head assigned to Treasury)

### Staff/Clerk

**Staff/Clerk → SmartFlow**

- Login credentials
- Document registration details (only for folders the office physically holds)
- Document QR scans (Mark IN / Mark OUT)
- Return reason when sending a folder back to a previous office
- Document Request details
- Required-by date
- Request review decisions for requests addressed to the office
- Rejection reason
- Search and filter criteria

**SmartFlow → Staff/Clerk**

- Authentication result
- Generated QR code
- Document details
- Current document holder
- Document movement history
- Suggested next office
- Pending Document Requests
- Request status
- In-app alerts (incoming folders, overdue items, request updates)
- Office queue information

### Department Head

**Department Head → SmartFlow**

- Login credentials
- Document registration details
- Document QR scans
- Document Request details
- Approve or reject decisions on Document Requests addressed to the office
- Rejection reason
- Manual due date for office documents
- Office analytics request

**SmartFlow → Department Head**

- Authentication result
- Office document queue
- Document location and status
- Pending Document Requests for the office
- Document Request status
- Office analytics
- Delay and overdue alerts
- Movement history

### Municipal Accountant/Admin

**Municipal Accountant/Admin → SmartFlow**

- User account information
- Sign-up approval or rejection decisions
- Office assignments
- User role updates
- Account activation or deactivation
- Processing threshold settings
- Report parameters (month, quarter, or year)
- Search and monitoring criteria

**SmartFlow → Municipal Accountant/Admin**

- User and office records
- Pending sign-up requests
- System-wide document records
- Custody exceptions (unforwarded OUT, wrong-office receive, skipped Budget/Accounting)
- QR scan rejections
- Overdue processing records
- Monthly, quarterly, and annual COA-oriented summaries
- Audit logs
- System-wide analytics

### Treasury Personnel

**Treasury Personnel → SmartFlow**

- Document QR scans
- Payment released status (record only, on the linked disbursement Document Request)

**SmartFlow → Treasury Personnel**

- DV information
- Current document status
- Disbursement Document Requests approved by Accounting
- Document movement history
- In-app alerts

---

## Figure 1.2 Use Case Diagram

### Actors

1. Staff/Clerk
2. Department Head
3. Municipal Accountant/Admin
4. Treasury Personnel

### Staff/Clerk Use Cases

- Sign up (account pending admin approval)
- Log in
- Log out
- View dashboard
- Register document physically held by assigned office
- Enter document reference number
- Enter document type (Disbursement Voucher, Approved Budget, or named Others)
- Enter payee
- Enter fund source
- Enter target completion date (optional)
- Generate QR code
- Print QR code
- Scan QR code
- Scan document IN
- Scan document OUT to the next office
- Return document to a previous office with reason
- View current document holder
- View document movement history
- Search documents
- Filter documents
- Create Document Request
- Enter required-by date
- View request status
- Cancel own pending Document Request
- Approve Document Request addressed to own office
- Reject Document Request with reason
- Fulfill Document Request
- View alerts
- View assigned office queue

### Department Head Use Cases

Include all staff functions, plus:

- View office dashboard
- Monitor office document queue
- View office processing performance
- View delayed and overdue documents
- Set manual due date on office documents
- Review Document Requests addressed to the office
- Approve Document Request
- Reject Document Request with reason
- View office analytics
- Monitor documents currently held by office

### Municipal Accountant/Admin Use Cases

- Log in
- Review pending sign-up requests
- Approve or reject sign-up request
- Manage users
- Create user account
- Update user account
- Activate or deactivate user account
- Assign user role
- Assign user to office
- Manage offices
- Configure processing thresholds
- View all documents
- View all movements
- View all Document Requests
- Monitor custody exceptions and QR scan rejections
- Monitor overdue documents
- View audit logs
- View system-wide analytics
- Generate monthly COA-oriented summary
- Generate quarterly COA-oriented summary
- Generate annual COA-oriented summary
- Export COA-oriented summary (admin in Accounting only)
- Register documents physically held by Accounting
- Search and filter system records

### Treasury Personnel Use Cases

- Log in
- View Treasury document queue
- Scan document IN
- Scan document OUT
- View DV details
- Record payment released (fulfill disbursement Document Request after Accounting approval)
- View document movement history
- View alerts

### Explicitly Excluded Use Cases

Do **not** include:

- Approve Disbursement Voucher
- Digitally approve financial transactions
- Process payment or check release
- Register payroll folders for QR tracking
- Generate payroll
- Process employee salary
- Export COA summary by ordinary staff or heads
- Approve "signatory requests" (not a SmartFlow feature)

---

## Figure 1.3A Staff/Clerk Activity Diagram

```text
Start
→ Log in
→ System validates credentials
→ Credentials valid?
    No  → Display error → Return to login
    Yes → Display staff dashboard
→ Select activity
```

### Register Document Branch

```text
Does assigned office physically hold the document?
    No  → Do not register document
        → Create Document Request if document is needed
    Yes → Enter document information:
            • Title
            • Document type
            • Reference number
            • Payee (required for DV)
            • Fund source (required for DV)
            • Target completion date (optional)
        → Validate required fields
        → Information complete?
            No  → Display validation errors → Correct information
            Yes → Save document
                → System records first IN at the assigned office
                → Generate QR code
                → Print and attach QR code
                → Document becomes active in office queue
```

### Scan Document Branch

```text
Select QR scanner
→ Scan QR code
→ QR code valid (signed, not expired, matches folder)?
    No  → Display invalid QR message → Rescan or cancel
    Yes → Display document information and suggested next office
        → Select Mark IN or Mark OUT
        → Mark OUT: is the folder complete?
            Yes → Select receiving office (forward)
            No  → Select "Return to a previous office"
                → Select an office that already held the folder
                → Enter required return reason
        → Save movement
        → Update current holder, office, status, and timestamp
        → Add movement to history
        → Display success confirmation
```

### Document Request Branch

```text
Search required document
→ Is document physically available in assigned office?
    Yes → Follow normal office processing
    No  → Create Document Request
        → Select request type (by category or pull from a specific office)
        → Select category / requested-from office
        → Enter purpose
        → Enter required-by date (today or later)
        → Submit request
        → System records pending request
        → System alerts handling office
        → Monitor request status
        → Cancel request if no longer needed (pending or approved only)
```

### Process Received Request Branch

```text
Open requests addressed to office
→ Select pending request
→ Is request valid and document available?
    Yes → Approve request
        → Prepare/release document
        → Scan document OUT to requesting office
        → Mark request fulfilled when completed
    No  → Reject request
        → Enter required rejection reason
        → Save rejection
        → Send separate notice through existing office procedure when required
→ Log out
→ End
```

---

## Figure 1.3B Department Head Activity Diagram

```text
Start
→ Log in
→ System validates credentials
→ Credentials valid?
    No  → Display error → Return to login
    Yes → Display Department Head dashboard
→ View assigned office queue and alerts
→ Select activity
```

### Monitor Documents Branch

```text
View documents currently held by office
→ View in-office, incoming, outgoing, and overdue records
→ Select document
→ View document details
→ View movement history
→ Check current status and holder
→ Set manual due date when needed
→ Return to dashboard
```

### Document Request Review Branch

```text
Open Document Requests addressed to office
→ Select pending request
→ Review requester, purpose, and required-by date
→ Decision?
    Approve → Record approval
            → Requester sees approved status
            → Office releases the folder (Scan OUT) and fulfills the request
    Reject  → Enter required rejection reason
            → Record rejection
            → Requester sees rejected status and reason
            → Send separate rejection notice when required
```

### Register or Move Document Branch

```text
Does office physically hold the document?
    No  → Create Document Request
    Yes → Register document if not yet registered
        → Generate and attach QR code
        → Scan IN, Scan OUT, or Return as the document moves
        → System updates office queue and movement history
```

### Office Analytics Branch

```text
Open office analytics
→ Select reporting period
→ View:
    • Documents currently held
    • Incoming and outgoing documents
    • Pending requests
    • Delayed documents
    • Processing duration
→ Return to dashboard
→ Log out
→ End
```

---

## Figure 1.3C Municipal Accountant/Admin Activity Diagram

```text
Start
→ Log in
→ System validates administrator credentials
→ Credentials valid?
    No  → Display error → Return to login
    Yes → Display administration dashboard
→ Select activity
```

### Sign-up Approval Branch

```text
Open pending sign-up requests
→ Select request
→ Review name, username, email, office, and requested role
→ Decision?
    Approve → System creates the user account
    Reject  → System marks the request rejected
→ System records reviewer and review time, and writes an audit log entry
```

### User Management Branch

```text
Open user management
→ Create or select user
→ Enter/update:
    • Name
    • Username or email
    • Assigned office
    • Role (staff, head, admin)
    • Account status (active/inactive)
→ Validate information
→ Save changes
```

### Office and Threshold Management Branch

```text
Open system settings
→ Select office and document type
→ Configure:
    • Maximum processing hours (in-office)
    • Unconfirmed OUT hours (sent but not yet received)
→ Save threshold
→ System uses thresholds to flag delayed and unconfirmed records
```

### Monitoring Branch

```text
View all active documents
→ Search/filter by:
    • Reference number
    • Document type
    • Office
    • Status
    • Current holder
    • Date
→ View movement history
→ Review custody exceptions (filtered by the selected report period):
    • Unforwarded OUT (sent, never received)
    • Wrong-office receive attempts
    • Skipped office (DV reached Accounting, Treasury, or Mayor without Budget/Accounting)
    • Invalid or rejected QR scans
    • Overdue processing
→ Follow up with the responsible office
```

### COA Reporting Branch

```text
Open reports
→ Select monthly, quarterly, or annual summary
→ Select reporting period
→ System compiles scan-log metrics:
    • On-time handoffs
    • Unforwarded OUT
    • Delayed handoffs
    • Documents processed per office
→ Review generated summary
→ Is the admin assigned to Accounting?
    Yes → Export/copy COA-oriented summary
    No  → View only
```

### Document Registration Branch

```text
Does Accounting physically hold the document?
    No  → Do not register it
        → Create Document Request if needed
    Yes → Register document for Accounting
        → For DV: select the office it was received from
        → Generate QR code
        → Print and attach QR code
        → Process through normal scan workflow
→ Log out
→ End
```

> **Important:** The Municipal Accountant/Admin manages the system but is **not** the only person allowed to register documents. Every user, including the admin, can register documents only for their own assigned office.

---

## Figure 1.3D General Document Lifecycle

```text
Start
→ Physical document is received or created by an office
→ Is document included in SmartFlow tracking scope (DV, Approved Budget, Others)?
    No  → Follow existing manual process → End
    Yes → Does the office physically hold the document?
            No  → Create Document Request
            Yes → Is document already registered?
                    No  → Enter document information
                        → Validate information
                        → Save document (first IN recorded)
                        → Generate QR code
                        → Print and attach QR code
                    Yes → Scan document IN
→ System records:
    • Receiving office
    • Receiving user
    • Date and time
    • Current holder
    • Current status
→ Office processes physical document
→ Is document ready to move?
    No  → Keep in current office queue
        → Monitor processing threshold
        → Flag as overdue when threshold is exceeded
    Yes → Is the folder complete?
            Yes → Scan document OUT to next office
            No  → Return (Scan OUT) to a previous office with reason
        → System records outgoing movement
        → Send physical document
        → Receiving office scans document IN
        → Not received within the unconfirmed-OUT threshold?
            → Flag as unforwarded custody exception
→ Repeat processing and movement until the trail is complete
→ Trail complete?
    • DV: IN at Treasury after the Mayor's Office, or IN at Accounting after Treasury and the Mayor's Office
    • Approved Budget: IN at Accounting after Budget
→ Document leaves the active/overdue queue
→ Movement history and audit trail remain available
→ End
```

---

## Figure 1.3E Disbursement Voucher Workflow

### Swimlanes (use these exact lanes, in order)

1. Engineering
2. Budget
3. Accounting
4. Treasury
5. Mayor's Office
6. Treasury
7. Accounting *(optional)*

### Complete DV Flow

**Engineering**

```text
Start
→ Engineering prepares the Disbursement Voucher and supporting documents
→ Engineering physically holds and registers the DV
→ Engineering enters reference number, payee, fund source, and document type
→ Engineering generates and attaches QR code
→ Engineering scans DV OUT
→ Physical DV is forwarded to Budget
```

**Budget**

```text
→ Budget receives physical DV
→ Budget scans DV IN
→ Budget reviews allocation and budget-related requirements
→ Complete?
    No  → Return (Scan OUT) to Engineering with required reason
    Yes → Budget scans DV OUT
        → Forward physical DV to Accounting
```

**Accounting**

```text
→ Accounting receives physical DV
→ Accounting scans DV IN
→ Accounting reviews supporting documents and regularity
→ Complete and valid?
    No  → Return (Scan OUT) to a previous office with required reason
    Yes → Accounting scans DV OUT
        → Forward physical DV to Treasury
```

**Treasury**

```text
→ Treasury receives physical DV
→ Treasury scans DV IN
→ Treasury prepares payment or check (outside SmartFlow)
→ Payment preparation complete?
    No  → Keep in Treasury queue
        → Monitor processing threshold
    Yes → Treasury scans DV OUT
        → Forward physical DV/check to Mayor's Office
```

**Mayor's Office**

```text
→ Mayor's Office receives physical DV
→ Mayor's Office scans DV IN
→ Mayor's Office performs existing physical review/signing procedure
→ SmartFlow records tracking only
→ SmartFlow does not approve the DV
→ After signing, Mayor's Office scans DV OUT
→ Return physical DV to Treasury
```

**Treasury (return)**

```text
→ Treasury receives returned DV
→ Treasury scans DV IN
→ SmartFlow marks the DV trail complete (no longer active or overdue)
→ Treasury releases payment/check (outside SmartFlow)
→ If a disbursement Document Request is linked and Accounting approved it:
    Treasury marks the request fulfilled ("Payment released at Treasury")
```

**Accounting (optional)**

```text
→ Is the folder returned to Accounting for filing?
    Yes → Treasury scans DV OUT
        → Accounting receives and scans DV IN
        → Trail remains complete (filed at Accounting)
        → End
    No  → End (trail complete at Treasury)
```

### DV Route Label

```text
Engineering → Budget → Accounting → Treasury
→ Mayor's Office → Treasury (trail complete)
→ Optional return to Accounting
```

> **Note:** Do not show SmartFlow approving the voucher or processing payment. Approval, signature, and check release remain existing municipal procedures outside SmartFlow's decision-making authority. SmartFlow only records custody and the "payment released" status.

---

## Figure 1.3F Document Request Workflow

```text
Start
→ User searches for needed document
→ Is document currently held by the user's assigned office?
    Yes → Access/process document through normal office workflow
    No  → Select Create Document Request
→ Select request type:
    • By category (Approved Budget → Budget, Disbursement → Accounting)
    • Others / pull from a specific office
→ Enter purpose
→ Enter required-by date (today or later)
→ Validate required information
→ Required information complete?
    No  → Display validation message → Complete missing fields
    Yes → Submit request
→ System assigns status: pending
→ System records requester, requester office, handling office, purpose, and required-by date
→ Handling office sees the request in its queue
→ Requester may cancel while pending or approved → status: cancelled → End
→ Handling office reviews request
→ Is request valid and document available?
    No  → Reject request
        → Enter mandatory rejection reason
        → System records status: rejected
        → Requester sees the reason in-app
        → Handling office sends separate notice when required
        → End
    Yes → Approve request → status: approved
        → Prepare physical document
        → Scan document OUT to requesting office
        → Requesting office scans document IN
        → Mark request fulfilled → status: fulfilled
        → Record completion timestamp
        → End
→ Past the required-by date and still open?
    → Request is flagged overdue
```

**Disbursement requests:** Accounting approves or rejects. After the DV reaches Treasury, **Treasury** marks the request fulfilled ("Payment released at Treasury"). Treasury can only do this after Accounting has approved it.

**Request statuses:** `pending` → `approved` → `fulfilled`, or `rejected`, or `cancelled`.

---

## Figure 1.4 Entity Relationship Diagram

Table and column names below are taken from the deployed MySQL `smartflow` database.

### Core Entities

#### offices

| Field | Key |
|---|---|
| `id` | PK |
| `name` | |
| `code` | unique (ENG, HR, BUD, ACC, TRE, MAY) |

#### users

| Field | Key |
|---|---|
| `id` | PK |
| `name` | |
| `username` | unique |
| `email` | unique, nullable |
| `password_hash` | |
| `office_id` | FK → offices |
| `role` | `staff` / `head` / `admin` |
| `is_active` | |
| `avatar_path` | nullable |

**Relationships:**

- One Office has many Users

#### documents

| Field | Key |
|---|---|
| `id` | PK (tracking ID, e.g. `DOC-2026-000001`) |
| `title` | |
| `type` | |
| `origin_office_id` | FK → offices |
| `description` | nullable |
| `reference_no` | nullable |
| `payee` | nullable |
| `fund_source` | nullable |
| `received_from_office_id` | → offices, nullable |
| `due_at` | nullable |
| `created_by` | FK → users |
| `date_registered` | |

Current holder, current office, and current status are **not stored columns**. They come from the document's latest row in `movements`.

**Relationships:**

- One Office originates many Documents
- One User registers many Documents

#### movements

| Field | Key |
|---|---|
| `id` | PK |
| `document_id` | FK → documents |
| `office_id` | FK → offices |
| `destination_office_id` | FK → offices, nullable (set on OUT) |
| `status` | `IN` / `OUT` |
| `user_id` | FK → users |
| `remarks` | nullable (return reason stored here) |
| `scanned_at` | |

**Relationships:**

- One Document has many Movements
- One Office has many Movements
- One User performs many Movements

#### document_requests

| Field | Key |
|---|---|
| `id` | PK |
| `request_code` | unique |
| `request_kind` | `access` / `pull` |
| `document_category` | |
| `requested_by` | FK → users |
| `requester_office_id` | FK → offices |
| `requester_role` | |
| `handler_office_id` | FK → offices |
| `target_office_id` | → offices, nullable |
| `purpose` | |
| `required_by` | nullable |
| `related_document_id` | → documents, nullable |
| `status` | `pending` / `approved` / `rejected` / `fulfilled` / `cancelled` |
| `reviewed_by` | → users, nullable |
| `reviewed_at` | nullable |
| `review_notes` | nullable (rejection reason stored here) |
| `fulfilled_at` | nullable |
| `created_at` | |

**Relationships:**

- One User creates many Document Requests
- One Office handles many Document Requests
- A Document Request may be associated with a Document

#### signup_requests

| Field | Key |
|---|---|
| `id` | PK |
| `request_code` | unique |
| `full_name` | |
| `username` | unique |
| `email` | |
| `password_hash` | |
| `office_id` | FK → offices |
| `requested_role` | |
| `status` | `pending` / `approved` / `rejected` |
| `approved_by` | → users, nullable |
| `approved_at` | nullable |
| `created_at` | |

**Relationships:**

- One Office has many Sign-up Requests
- One Admin reviews many Sign-up Requests

#### processing_thresholds

| Field | Key |
|---|---|
| `id` | PK |
| `office_id` | FK → offices |
| `document_type` | |
| `max_hours` | |
| `out_unconfirmed_hours` | |
| `is_active` | |
| `updated_at` | |

**Relationships:**

- One Office has many Processing Thresholds (unique per office and document type)

#### audit_logs

| Field | Key |
|---|---|
| `id` | PK |
| `event_type` | |
| `document_id` | nullable |
| `user_id` | nullable |
| `office_id` | nullable |
| `status` | nullable |
| `outcome` | |
| `message` | |
| `meta_json` | nullable |
| `ip_address` | nullable |
| `user_agent` | nullable |
| `created_at` | |

**Relationships:**

- One User creates many Audit Logs
- One Document may have many Audit Logs

**Event types:** QR scans (`movement.scan`, `qr.verify`) feed the QR scan monitor. Admin and account actions (`signup.*`, `user.*`, `threshold.update`, `request.*`) are listed separately as Admin & account activity. Threshold changes store the old and new values in `meta_json`.

### Auth Support

| Table | Columns |
|---|---|
| `auth_tokens` | `id` PK, `user_id` FK → users, `token_hash`, `expires_at`, `is_revoked`, `ip_address`, `user_agent`, `created_at` |
| `password_resets` | `id` PK, `user_id` FK → users, `token_hash`, `expires_at`, `used_at`, `created_at` |
| `qr_tokens` | `id` PK, `document_id`, `token_hash`, `issued_by`, `expires_at`, `is_revoked`, `created_at` |

> **Note:** "FK →" marks a foreign key enforced in the database. A plain "→" marks a reference the application maintains without a database constraint.

---

## Figure 1.5 Software Architecture

### Client Layer

- **Flutter Mobile Application** (Android)
- **React Web Application**

**Mobile Functions**

- QR scanning
- Document registration
- Mark IN, Mark OUT, and Return to previous office
- Document Request creation
- Request processing
- Alerts
- Queue and history viewing
- Admin reports (monthly, quarterly, annual)

**Web Functions**

- Administrative dashboard
- User management and sign-up approval
- Office management
- System-wide monitoring
- Analytics
- COA-oriented summaries (monthly, quarterly, annual) and export
- Audit and custody exception monitoring
- Scan and register pages

### Application/API Layer

**PHP REST API**

Responsibilities:

- Authentication and authorization (token-based)
- Role- and office-based access control
- Document registration
- Signed QR generation and validation
- Document movement processing (IN, OUT, return)
- Document Request processing
- Sign-up approval
- User and office management
- Threshold monitoring
- Analytics and reporting
- Audit logging

### Data Layer

**MySQL Database**

Stores:

- Offices
- Users
- Documents
- Movements
- Document Requests
- Sign-up Requests
- Processing thresholds
- Audit logs
- Authentication support data (auth tokens, password resets, QR tokens)

### Architecture Connections

| From | Via | To |
|---|---|---|
| Flutter Mobile App | HTTPS/JSON | PHP REST API |
| React Web App | HTTPS/JSON | PHP REST API |
| PHP REST API | SQL Queries | MySQL Database |
| MySQL Database | Query Results | PHP REST API |
| PHP REST API | JSON Responses | Mobile and Web Applications |

---

## Department-Specific Flows

### Engineering Office

```text
Receive/create engineering transaction documents
→ Register document only when physically held
→ Generate and attach QR code
→ Process engineering requirements
→ For DV: prepare DV and supporting documents
→ Scan OUT
→ Forward to Budget
→ If returned by Budget: Scan IN, correct, and forward again
→ Monitor movement and status
```

### Human Resources Office

```text
Receive/create HR documents (registered as named "Others" folders)
→ Register only when physically held
→ Generate and attach QR code
→ Process HR document
→ Scan OUT when forwarded
→ Receiving office scans IN
→ Monitor status and movement history
```

> **Payroll clarification:** Payslip functionality only. No QR-tracked payroll folder in Phase 1, and payroll Document Requests are not accepted.

### Budget Office

```text
Receive document
→ Scan IN
→ Review budget allocation and requirements
→ Complete?
    No  → Return (Scan OUT) to the previous office with required reason
    Yes → Scan OUT and forward to next office
→ For DV: forward to Accounting
```

### Accounting Office

```text
Receive document
→ Scan IN
→ Review completeness, supporting documents, and regularity
→ Complete?
    No  → Return (Scan OUT) to a previous office with required reason
    Yes → Scan OUT and forward
→ For DV: forward to Treasury
→ Approve or reject disbursement Document Requests
→ Perform optional post-payment filing (DV returned from Treasury)
→ Generate monthly, quarterly, or annual COA-oriented summary through admin access
```

### Treasury Office

```text
Receive document
→ Scan IN
→ Review payment-related information
→ Prepare payment/check (outside SmartFlow)
→ Forward to Mayor's Office for signing
→ Receive signed document back
→ Scan IN (DV trail complete)
→ Release payment (outside SmartFlow)
→ Mark linked disbursement Document Request fulfilled ("Payment released")
→ Forward to Accounting for filing when required
```

### Mayor's Office

```text
Receive document
→ Scan IN
→ Perform existing physical review/signing procedure
→ Scan OUT
→ Return document to originating or next responsible office
→ For DV: return to Treasury
```

---

## What Must Not Appear in Any Figure

Remove or avoid these statements:

- Only the Municipal Accountant registers documents.
- Every document must first be logged by Accounting.
- The admin can register documents for other offices.
- Payroll folders are QR-tracked.
- SmartFlow approves Disbursement Vouchers.
- SmartFlow processes payments or check release.
- Department Heads approve "signatory requests."
- Treasury Personnel is a separate system role.
- All rejection activities happen only inside SmartFlow.
- Ordinary staff or heads can export COA summaries.
- A document can be registered by an office that does not physically hold it.
- SmartFlow guarantees reduction of Acknowledgment of Receipt incidents.
- Every department follows exactly the same internal workflow.
- SmartFlow replaces the municipality's financial approval procedure.

---

> **Section 4.3.3 guidance:** Use Activity Diagrams for Section 4.3.3, because the official template asks for a DFD **or** an Activity Diagram. You do not need to create both. Keep the Context Diagram, Use Case Diagram, ERD, and Software Architecture as separate required figures.

---

## Related Paper Fixes

These are outside the figures but conflict with them:

- **System test ST-02 "Payroll routing HR → Accounting"** contradicts the scope statement that payroll is not a QR-tracked folder. Replace it with an Approved Budget or "Others" routing test.
- **Context diagram narrative** says the Municipal Accountant "sends document registration data." Keep it, but state that registration is limited to folders Accounting physically holds.
- **Department Head flowchart (Figure 1.7 narrative)** says heads "approve or reject documents." Reword to "approve or reject Document Requests addressed to their office."
