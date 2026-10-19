# Figure 2-5B — Department Head Flowchart

Source of truth: implemented Flutter screens, PHP API validation, client-discovery summary, and the 2026-09-28 system test report.

```mermaid
flowchart TD
  S([Authenticated Department Head]) --> DASH[Open dashboard for assigned office only]
  DASH --> TASK{Choose task}

  TASK -->|Monitor office| QUEUE[Open office queue]
  QUEUE --> FILTER[Review on-desk, incoming, outgoing, completed, and delayed documents]
  FILTER --> DOC[Open document details and complete movement history]
  DOC --> FOLLOW{Overdue or exception?}
  FOLLOW -->|Yes| ALERT[Open alert and follow up with assigned staff] --> DASH
  FOLLOW -->|No| DASH

  TASK -->|Analytics| PERIOD[Select reporting period]
  PERIOD --> ANALYTICS[View holdings, handoffs, delays, requests, and processing duration]
  ANALYTICS --> DASH

  TASK -->|Physical folder operation| PHYS{Register or scan?}
  PHYS -->|Register| HOLDER{Is folder physically at this office?}
  HOLDER -->|No| REQUEST[Create Document Request] --> DASH
  HOLDER -->|Yes| REG[Use validated Staff registration rules]
  REG --> REG_RESULT[Create secured QR and automatic initial IN]
  REG_RESULT --> ASSIGN[Assign clerk to attach QR and perform physical handoffs]
  ASSIGN --> DASH
  PHYS -->|Scan| SCAN[Use Staff QR, custody, destination, duplicate, and return validations]
  SCAN --> DASH

  TASK -->|Document Requests| REQS[Open Inbox or My Requests]
  REQS --> PENDING{Pending handler request?}
  PENDING -->|Yes| DECIDE{Accept or decline?}
  DECIDE -->|Decline| WHY[Require reason; reject; remind separate notice] --> DASH
  DECIDE -->|Accept| ACCEPT[Record approved status and continue office processing] --> DASH
  PENDING -->|No| TRACK[Track approved, rejected, fulfilled, or cancelled status] --> DASH

  TASK -->|History or Alerts| INFO[Review office-only history and notifications] --> DASH
  DASH --> OUT[Log out] --> E([End])
```

## Verified Notes

- A Department Head is restricted to one assigned office.
- Head can use Register and Scan under the same validation rules as Staff.
- Head does not manage users, offices, thresholds, audit exceptions, or municipal COA reports.
- The implemented system has no standalone Signatory Request module.

