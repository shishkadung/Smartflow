# Figure 2-5A — Staff / Clerk Flowchart

Source of truth: implemented Flutter screens, PHP API validation, client-discovery summary, and the 2026-09-28 system test report.

```mermaid
flowchart TD
  S([Authenticated Staff User]) --> HOME[Open own-office dashboard]
  HOME --> TASK{Choose task}

  TASK -->|Register| HOLD{Is the physical folder at this office?}
  HOLD -->|No| USE_REQ[Use Document Requests instead] --> HOME
  HOLD -->|Yes| TYPE{Is the document type allowed for this office?}
  TYPE -->|No| BLOCK_TYPE[Block registration and show office guidance] --> HOME
  TYPE -->|Yes| FORM[Enter title, type, reference, payee, fund source, and optional due date]
  FORM --> ACC_DV{Accounting registering a DV?}
  ACC_DV -->|Yes| FROM[Select required received-from office; ACC cannot be sender]
  ACC_DV -->|No| VALIDATE
  FROM --> VALIDATE{Required fields complete?}
  VALIDATE -->|No| FORM_ERR[Show validation error and keep form values] --> FORM
  VALIDATE -->|Yes| DUP{Possible duplicate reference?}
  DUP -->|Yes| VERIFY[Verify existing document or explicitly Register anyway]
  DUP -->|No| CREATE[Create tracking ID]
  VERIFY --> CREATE
  CREATE --> QR[Issue signed and expiring secured QR payload]
  QR --> INITIAL_IN[Automatically record initial IN at registering office]
  INITIAL_IN --> PRINT[Show and print QR label and registration details]
  PRINT --> HOME

  TASK -->|Scan| OPEN_SCAN[Use camera, upload QR image, or enter document ID]
  OPEN_SCAN --> QR_OK{Secured QR valid and matches document?}
  QR_OK -->|No| QR_REJECT[Reject and audit invalid, tampered, expired, or mismatched QR] --> OPEN_SCAN
  QR_OK -->|Yes| SHOW[Show document, custodian, due state, and suggested destination]
  SHOW --> ACTION{Available custody action?}
  ACTION -->|Mark IN| DEST{Was folder sent to this office?}
  DEST -->|No| WRONG[Block wrong receiver or invalid sequence] --> OPEN_SCAN
  DEST -->|Yes| DUP_IN{Recent duplicate action?}
  DUP_IN -->|Yes| DUP_BLOCK[Block duplicate scan] --> HOME
  DUP_IN -->|No| SAVE_IN[Save IN; update holder, status, timestamp, history, and audit]
  ACTION -->|Mark OUT| HELD{Is latest movement IN at this office?}
  HELD -->|No| NOT_HELD[Block OUT because office does not hold folder] --> HOME
  HELD -->|Yes| OUT_KIND{Forward or return?}
  OUT_KIND -->|Forward| PICK[Select a different destination office]
  OUT_KIND -->|Return| RETURN[Select previous holder and enter required return reason]
  PICK --> SAVE_OUT[Save OUT movement and destination]
  RETURN --> SAVE_OUT
  SAVE_IN --> COMPLETE{Trail complete?}
  SAVE_OUT --> COMPLETE
  COMPLETE -->|Yes| DONE[Mark completed; clear due state and forwarding suggestion] --> HOME
  COMPLETE -->|No| HOME

  TASK -->|Document Request| REQ_KIND{By document type or from a specific office?}
  REQ_KIND -->|By type| CAT[Select allowed document category]
  REQ_KIND -->|From office| TARGET[Select target office]
  CAT --> REQ_FORM[Enter mandatory purpose and required-by date]
  TARGET --> REQ_FORM
  REQ_FORM --> REQ_VALID{Request valid?}
  REQ_VALID -->|No| REQ_ERR[Show field, self-request, payroll, or routing error] --> REQ_FORM
  REQ_VALID -->|Yes| PENDING[Create pending request and notify handler office]
  PENDING --> VIEW{Inbox or My Requests?}
  VIEW -->|My Requests| STATUS[Track pending, approved, rejected, fulfilled, or cancelled]
  STATUS --> CANCEL{Cancel pending or approved request?}
  CANCEL -->|Yes| CANCELLED[Record cancellation and audit] --> HOME
  CANCEL -->|No| HOME
  VIEW -->|Handler Inbox| REVIEW{Accept or decline pending request?}
  REVIEW -->|Decline| REASON[Require reason; reject; remind separate phone or memo notice] --> HOME
  REVIEW -->|Accept| APPROVED[Record approved status]
  APPROVED --> DV_REQ{Disbursement request?}
  DV_REQ -->|Yes| TRE[Accounting accepts; Treasury marks payment released]
  DV_REQ -->|No| CLOSE[Handler closes request; optional tracking ID link]
  TRE --> FULFILLED[Record fulfilled timestamp and audit] --> HOME
  CLOSE --> FULFILLED

  TASK -->|History or Alerts| INFO[View movement trail, incoming folders, delays, and notifications] --> HOME
  HOME --> OUT[Log out] --> E([End])
```

## Verified Notes

- Staff sees operational data for the assigned office only.
- Registration automatically creates the initial `IN` movement.
- `OUT` requires a destination; only that destination may record the next `IN`.
- HR payroll-folder registration is excluded from Phase 1.
- Completed DV route: `ENG → BUD → ACC → TRE → MAY → TRE → ACC`.

