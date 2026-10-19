# Figure 2-5C — Municipal Accountant / Admin Flowchart

Source of truth: implemented Flutter screens, PHP API validation, client-discovery summary, and the 2026-09-28 system test report.

```mermaid
flowchart TD
  S([Authenticated Municipal Accountant / Admin]) --> DASH[Open municipal dashboard for all pilot offices]
  DASH --> TASK{Choose task}

  TASK -->|Monitor municipality| MON[Review office status, active folders, history, alerts, and requests]
  MON --> QRMON[Open QR monitor and audit activity]
  QRMON --> EX{Rejected scans or audit gaps?}
  EX -->|Yes| REVIEW[Inspect invalid QR, wrong-office, sequence, duplicate, and missing-scan events] --> DASH
  EX -->|No| DASH

  TASK -->|COA reports| MODE{Monthly or annual?}
  MODE --> PERIOD[Select reporting period]
  PERIOD --> REPORT[Compile handoff metrics and completion data]
  REPORT --> EXPORT[Export authorized Accounting COA flow summary]
  EXPORT --> REPORT_AUDIT[Record export audit action] --> DASH

  TASK -->|Signup review| SIGNUPS[Open pending signup requests]
  SIGNUPS --> DECIDE{Approve or reject?}
  DECIDE -->|Reject| REJECT_SIGNUP[Record rejected signup] --> DASH
  DECIDE -->|Approve| ACCOUNT[Create active account with approved office and role] --> DASH

  TASK -->|Manage users| USERS[Update role, office assignment, profile, and active status]
  USERS --> LAST_ADMIN{Would this deactivate the final active Admin?}
  LAST_ADMIN -->|Yes| BLOCK[Block unsafe deactivation] --> DASH
  LAST_ADMIN -->|No| AUDIT_USER[Save and audit user change] --> DASH

  TASK -->|Configure offices| OFFICES[View and maintain pilot-office records] --> DASH
  TASK -->|Thresholds| TH[Set processing-time threshold by office and document type]
  TH --> DELAY[Use thresholds for delayed and overdue monitoring] --> DASH
  TASK -->|System status| SYS[Check API, database, office, active, overdue, and in-transit status] --> DASH

  TASK -->|Document Request| REQ[Create, monitor, accept, reject, fulfill, or cancel as authorized]
  REQ --> DV{Disbursement fulfillment?}
  DV -->|Normal workflow| RULE[Accounting accepts first; Treasury marks payment released] --> DASH
  DV -->|Admin API authority| AUDIT_REQ[Complete authorized action with admin audit context] --> DASH

  TASK -->|Assigned-office Register or Scan| OPS[Apply physical-holder, office, QR, custody, destination, and duplicate rules]
  OPS --> ACC_DV{Accounting registering a DV?}
  ACC_DV -->|Yes| FROM[Require received-from office; ACC cannot originate project DV] --> DASH
  ACC_DV -->|No| DASH

  DASH --> OUT[Log out] --> E([End])
```

## Verified Notes

- The live `admin` role combines Municipal Accountant and System Administrator functions.
- Current routes and APIs allow Admin to Register and Scan for the assigned office.
- Admin actions are audited.
- SmartFlow records payment-release status but does not approve financial transactions or produce financial statements.

