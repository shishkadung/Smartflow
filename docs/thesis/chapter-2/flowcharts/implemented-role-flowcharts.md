# SmartFlow Role Flowcharts — As Implemented

Source of truth: Flutter routes and screens, PHP API authorization and validation, client-discovery summary, and the 2026-09-28 system test report.

## Figure 2-5A — Staff / Clerk

```mermaid
flowchart TD
  S([Start]) --> L[Enter username and password]
  L --> AUTH{Login accepted and account active?}
  AUTH -->|No| ERR[Show authentication error] --> L
  AUTH -->|Yes| HOME[Open own-office dashboard]
  HOME --> TASK{Choose task}

  TASK -->|Register| HOLD{Is the physical folder at this office?}
  HOLD -->|No| USE_REQ[Use Document Requests instead] --> HOME
  HOLD -->|Yes| TYPE{Is the document type allowed for this office?}
  TYPE -->|No| BLOCK_TYPE[Block registration and show office guidance] --> HOME
  TYPE -->|Yes| FORM[Enter title, type, reference, payee, fund source, and optional due date]
  FORM --> ACC_DV{Accounting registering a DV?}
  ACC_DV -->|Yes| FROM[Select required received-from office; ACC cannot be the sender]
  ACC_DV -->|No| VALIDATE
  FROM --> VALIDATE{Required fields complete?}
  VALIDATE -->|No| FORM_ERR[Show validation error and keep form values] --> FORM
  VALIDATE -->|Yes| DUP{Possible duplicate reference?}
  DUP -->|Yes| VERIFY[Verify existing document or explicitly Register anyway]
  DUP -->|No| CREATE[Create tracking ID]
  VERIFY --> CREATE
  CREATE --> QR[Issue signed, expiring secured QR payload]
  QR --> INITIAL_IN[Automatically record initial IN at the registering office]
  INITIAL_IN --> PRINT[Show/print QR label and registration details]
  PRINT --> HOME

  TASK -->|Scan| OPEN_SCAN[Open camera, upload QR image, or enter document ID]
  OPEN_SCAN --> QR_OK{Secured QR valid and matches document?}
  QR_OK -->|No| QR_REJECT[Reject and audit invalid, tampered, expired, or mismatched QR] --> OPEN_SCAN
  QR_OK -->|Yes| SHOW[Show document, current custodian, due state, and suggested next office]
  SHOW --> ACTION{Available custody action?}
  ACTION -->|Mark IN| DEST{Was folder sent to this office?}
  DEST -->|No| WRONG[Block wrong receiver or invalid sequence] --> OPEN_SCAN
  DEST -->|Yes| DUP_IN{Recent duplicate action?}
  DUP_IN -->|Yes| DUP_BLOCK[Block duplicate scan] --> HOME
  DUP_IN -->|No| SAVE_IN[Save IN movement; update holder, status, timestamp, history, and audit]
  ACTION -->|Mark OUT| HELD{Is latest movement IN at this office?}
  HELD -->|No| NOT_HELD[Block OUT because office does not hold folder] --> HOME
  HELD -->|Yes| OUT_KIND{Forward or return?}
  OUT_KIND -->|Forward| PICK[Select a different destination office]
  OUT_KIND -->|Return| RETURN[Select a previous holder and enter required return reason]
  PICK --> SAVE_OUT[Save OUT movement and destination]
  RETURN --> SAVE_OUT
  SAVE_IN --> COMPLETE{Trail complete?}
  SAVE_OUT --> COMPLETE
  COMPLETE -->|Yes| DONE[Mark completed; remove due/overdue state and further suggestion] --> HOME
  COMPLETE -->|No| HOME

  TASK -->|Document Request| REQ_KIND{Request by type or from a specific office?}
  REQ_KIND -->|By type| CAT[Select allowed document category]
  REQ_KIND -->|From office| TARGET[Select target office]
  CAT --> REQ_FORM[Enter mandatory purpose and required-by date]
  TARGET --> REQ_FORM
  REQ_FORM --> REQ_VALID{Request valid?}
  REQ_VALID -->|No| REQ_ERR[Show missing-field, self-request, payroll, or routing error] --> REQ_FORM
  REQ_VALID -->|Yes| PENDING[Create pending request and notify handler office]
  PENDING --> VIEW{Inbox or My Requests?}
  VIEW -->|My Requests| STATUS[Track pending, approved, rejected, fulfilled, or cancelled]
  STATUS --> CANCEL{Cancel pending/approved request?}
  CANCEL -->|Yes| CANCELLED[Record cancelled status and audit] --> HOME
  CANCEL -->|No| HOME
  VIEW -->|Handler Inbox| REVIEW{Accept or decline pending request?}
  REVIEW -->|Decline| REASON[Require reason; record rejected; remind separate phone/memo notice] --> HOME
  REVIEW -->|Accept| APPROVED[Record approved status]
  APPROVED --> DV_REQ{Disbursement request?}
  DV_REQ -->|Yes| TRE[Only Treasury may mark payment released after Accounting accepts]
  DV_REQ -->|No| CLOSE[Handler closes request; optional tracking ID link]
  TRE --> FULFILLED[Record fulfilled/payment released timestamp and audit] --> HOME
  CLOSE --> FULFILLED

  TASK -->|History or Alerts| REVIEW_INFO[View movement trail, incoming folders, delayed items, and notifications] --> HOME
  HOME --> LOGOUT[Log out] --> E([End])
```

Implementation notes:

- Staff sees only the assigned office's operational data.
- HR cannot register payroll folders in Phase 1.
- `OUT` always requires a destination. Only that destination can record the next `IN`.
- Completed DV route: ENG → BUD → ACC → TRE → MAY → TRE → ACC.

## Figure 2-5B — Department Head

```mermaid
flowchart TD
  S([Start]) --> L[Login as Head]
  L --> AUTH{Credentials valid and account active?}
  AUTH -->|No| ERR[Show error] --> L
  AUTH -->|Yes| DASH[Open dashboard for assigned office only]
  DASH --> TASK{Choose task}

  TASK -->|Monitor office| QUEUE[Open office queue]
  QUEUE --> FILTER[Review on-desk, incoming, outgoing, completed, and delayed documents]
  FILTER --> DOC[Open document details and full movement history]
  DOC --> FOLLOW{Overdue or exception?}
  FOLLOW -->|Yes| ALERT[Open alert and follow up with assigned staff] --> DASH
  FOLLOW -->|No| DASH

  TASK -->|Analytics| PERIOD[Select reporting period]
  PERIOD --> ANALYTICS[View office holdings, handoffs, delays, requests, and processing duration]
  ANALYTICS --> DASH

  TASK -->|Physical folder operation| PHYS{Register or scan?}
  PHYS -->|Register| HOLDER{Is folder physically at this office?}
  HOLDER -->|No| REQUEST[Create Document Request] --> DASH
  HOLDER -->|Yes| REG[Use the same validated registration flow as Staff]
  REG --> HEAD_NOTE[Registration creates secured QR and initial IN; assign clerk for physical handoffs]
  HEAD_NOTE --> DASH
  PHYS -->|Scan| SCAN[Use the same QR, custody, destination, duplicate, and return validations as Staff]
  SCAN --> DASH

  TASK -->|Document Requests| REQS[Open Inbox or My Requests]
  REQS --> PENDING{Pending handler request?}
  PENDING -->|Yes| DECIDE{Accept or decline?}
  DECIDE -->|Decline| WHY[Require reason; record rejection; remind separate notice] --> DASH
  DECIDE -->|Accept| ACCEPT[Record approved status and continue office processing] --> DASH
  PENDING -->|No| TRACK[Track approved, rejected, fulfilled, or cancelled status] --> DASH

  TASK -->|History or Alerts| INFO[Review office-only history and notifications] --> DASH
  DASH --> OUT[Log out] --> E([End])
```

Implementation notes:

- A Head is restricted to one assigned office.
- Head can use Register and Scan, but does not manage users, offices, thresholds, audit exceptions, or municipal COA reports.
- The implemented app has no separate production Signatory Request module.

## Figure 2-5C — Municipal Accountant / Admin

```mermaid
flowchart TD
  S([Start]) --> L[Login as Admin]
  L --> AUTH{Credentials valid and account active?}
  AUTH -->|No| ERR[Show error] --> L
  AUTH -->|Yes| DASH[Open municipal dashboard for all pilot offices]
  DASH --> TASK{Choose task}

  TASK -->|Monitor municipality| MON[Review office status, active folders, history, alerts, and requests]
  MON --> QRMON[Open QR monitor and audit activity]
  QRMON --> EX{Rejected scans or audit gaps?}
  EX -->|Yes| REVIEW[Inspect invalid QR, wrong-office, sequence, duplicate, and missing-scan events] --> DASH
  EX -->|No| DASH

  TASK -->|COA reports| MODE{Monthly or annual?}
  MODE --> PERIOD[Select reporting period]
  PERIOD --> REPORT[Compile handoff metrics and completion data]
  REPORT --> EXPORT[Export authorized Accounting COA flow summary; record audit action]
  EXPORT --> DASH

  TASK -->|Signup review| SIGNUPS[Open pending signup requests]
  SIGNUPS --> DECIDE{Approve or reject?}
  DECIDE -->|Reject| REJECT_SIGNUP[Record rejected signup] --> DASH
  DECIDE -->|Approve| ACCOUNT[Create active account with requested role and office]
  ACCOUNT --> DASH

  TASK -->|Manage users| USERS[Update role, office assignment, profile, and active status]
  USERS --> LAST_ADMIN{Would this deactivate the final active Admin?}
  LAST_ADMIN -->|Yes| BLOCK[Block unsafe deactivation] --> DASH
  LAST_ADMIN -->|No| AUDIT_USER[Save and audit user change] --> DASH

  TASK -->|Configure offices| OFFICES[View and maintain pilot office records] --> DASH
  TASK -->|Thresholds| TH[Set processing-time thresholds by office/document type]
  TH --> DELAY[Thresholds drive delayed and overdue monitoring] --> DASH
  TASK -->|System status| SYS[Check API, database, office, active, overdue, and in-transit status] --> DASH

  TASK -->|Document Request| REQ[Create, monitor, accept/reject, fulfill, or cancel as authorized]
  REQ --> DV{Disbursement fulfillment?}
  DV -->|Yes| RULE[Accounting must accept first; Treasury normally marks payment released]
  DV -->|Admin override permitted by API| AUDIT_REQ[Complete action with admin audit context]
  RULE --> DASH
  AUDIT_REQ --> DASH

  TASK -->|Assigned-office Register/Scan| OPS[Use the same physical-holder, office, QR, custody, destination, and duplicate validations]
  OPS --> ACC_DV{Accounting registering a DV?}
  ACC_DV -->|Yes| FROM[Require received-from office; ACC cannot originate project DV] --> DASH
  ACC_DV -->|No| DASH

  DASH --> OUT[Log out] --> E([End])
```

Implementation notes:

- The live `admin` role combines Municipal Accountant monitoring/reporting with system administration.
- Contrary to an older demo note, current routes and APIs allow Admin to register and scan for the assigned office.
- Admin actions are audited. SmartFlow records payment-release status but does not approve financial transactions or produce financial statements.

