# Live role flowcharts (staff · head · admin)

Use these for the updated Chapter 2 figures. Preview in Cursor, or paste a block into [mermaid.live](https://mermaid.live) and export PNG on a **white** background.

| Figure | Role | Replaces |
|--------|------|----------|
| **2-5** | `staff` — department member / clerk | Old clerk “scan only” figure |
| **2-5b** | `head` — department head (one office) | Old head figure |
| **2-5c** | `admin` — municipal monitor + system config | Old 2-5c Accountant **and** 2-5d Admin (one role in the app) |

Offices: **ENG · HR · BUD · ACC · TRE · MAY**

---

## Figure 2-5 — Staff

```mermaid
flowchart TD
  S([Start]) --> L[Login as staff]
  L --> H[Home — own office only]
  H --> Q{Is the folder on your desk?}

  Q -->|No| REQ[Create document request]
  REQ --> HAND{Are you the handler office?}
  HAND -->|No| WAIT[Wait for accept or decline]
  WAIT --> END([End])
  HAND -->|Yes| DEC{Accept or decline?}
  DEC -->|Decline| NOTE[Status declined — also send separate notice]
  NOTE --> END
  DEC -->|Accept| PROG[In progress]
  PROG --> DONE{Folder custody finished?}
  DONE -->|Yes| FUL[Fulfill request and link tracking ID]
  FUL --> END
  DONE -->|No| PROG

  Q -->|Yes| HAS{Does the folder already have a QR?}
  HAS -->|No| REG[Register document and show secured QR]
  REG --> SCAN
  HAS -->|Yes| SCAN[Open Scan]
  SCAN --> ACT{IN or OUT?}
  ACT -->|IN| IN[Mark IN at this office]
  ACT -->|OUT| OUT[Mark OUT and choose next office]
  IN --> SAVE[Save movement — update dashboard and history]
  OUT --> SAVE
  SAVE --> MORE{Need alerts or history?}
  MORE -->|Yes| AH[View alerts or history]
  AH --> H
  MORE -->|No| END
```

**Footer:** If the folder is not on the desk, request it. If it is on the desk, the holding office registers and scans. Staff cannot open municipal COA reports or system settings.

---

## Figure 2-5b — Department head

```mermaid
flowchart TD
  S([Start]) --> L[Login as head]
  L --> H[Office dashboard — this office only]
  H --> LATE{Is a document overdue?}
  LATE -->|Yes| AL[Open alerts or queue]
  AL --> FU[Follow up with staff]
  FU --> H
  LATE -->|No| AN[Optional: open office analytics]
  AN --> HOLD{Will you also handle a physical folder?}
  HOLD -->|No| HIS[View office history]
  HIS --> END([End])
  HOLD -->|Yes| SAME[Use staff rule: request, register, or scan IN or OUT]
  SAME --> END
```

**Footer:** A head monitors one office. A head does not manage users, offices, thresholds, or municipal COA reports.

---

## Figure 2-5c — Admin

```mermaid
flowchart TD
  S([Start]) --> L[Login as admin]
  L --> H[Municipal dashboard — all pilot offices]
  H --> TASK{What is the task?}

  TASK -->|Monitor documents| MON[Review history, alerts, and requests]
  MON --> COA[Generate COA flow report]
  COA --> QR[Open QR monitor]
  QR --> EX[Review rejected scans and audit gaps]
  EX --> END([End])

  TASK -->|Configure system| SU[Approve or reject signup requests]
  SU --> US[Manage users — role and office]
  US --> OF[Manage offices]
  OF --> TH[Set processing-time thresholds]
  TH --> SYS[Check system status]
  SYS --> END
```

**Footer:** Daily IN/OUT on the DV trail is done by **staff**. Admin monitors the municipality, exports COA flow summaries, and configures the system. SmartFlow does not approve payment or produce financial statements.

---

## Shape map

| Mermaid | Word symbol |
|---------|-------------|
| `([Start])` / `([End])` | Oval |
| `[Process]` | Rectangle |
| `{Question?}` | Diamond |
