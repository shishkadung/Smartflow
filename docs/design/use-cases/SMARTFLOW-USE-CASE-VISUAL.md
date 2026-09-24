# SmartFlow Use Case Visual

## System Overview

```mermaid
flowchart TB
    subgraph Actors
        S[👤 Staff/Clerk]
        H[👤 Department Head]
        A[👤 Municipal Admin]
        AC[👤 Accounting]
    end

    subgraph CoreFeatures["🔐 Secure Document Tracking"]
        QR[QR Label Management]
        SCAN[Scan IN/OUT]
        AUDIT[Audit Monitoring]
        ALERT[Alert System]
    end

    S --> SCAN
    H --> SCAN
    H --> ALERT
    A --> AUDIT
    A --> QR
    AC --> QR
```

---

## 1. QR Security Use Case

```mermaid
sequenceDiagram
    actor Accounting
    actor Staff
    actor System
    actor Database

    rect rgb(230, 245, 255)
    Note over Accounting,Database: 🔐 Phase 1: Secure QR Generation
    Accounting->>System: Create Document
    System->>Database: Insert document record
    Database-->>System: DOC-2026-000001
    System->>System: Generate SF1 signed token<br/>HMAC-SHA256(payload + secret)
    System->>Database: Store token metadata
    System-->>Accounting: Printable QR label<br/>(SF1.{base64}.{signature})
    end

    rect rgb(255, 245, 230)
    Note over Staff,Database: 🔍 Phase 2: QR Verification
    Staff->>System: Scan QR label
    System->>System: Validate signature<br/>Check expiration (180 days)
    alt Valid Token
        System->>Database: Log qr.verify SUCCESS
        System-->>Staff: Show document details
    else Invalid/Expired
        System->>Database: Log qr.verify REJECTED
        System-->>Staff: Show error: "Label expired - reprint needed"
    end
    end
```

---

## 2. State-Based Scanning (IN/OUT)

```mermaid
stateDiagram-v2
    [*] --> Unregistered : Document Created
    Unregistered --> IN_OfficeA : First Scan IN
    
    IN_OfficeA --> OUT_OfficeA : Scan OUT (with destination)
    OUT_OfficeA --> IN_OfficeB : Recipient scans IN
    IN_OfficeB --> OUT_OfficeB : Forward to next office
    OUT_OfficeB --> IN_OfficeC : Continue chain...
    
    note right of IN_OfficeA
        ✓ Valid: First IN
        ✗ Blocked: IN again at same office
    end note
    
    note right of OUT_OfficeA
        ✓ Valid: Must be IN at this office
        ✗ Blocked: OUT without prior IN
        ✗ Blocked: Wrong destination office
    end note
    
    note right of IN_OfficeB
        ✓ Valid: Was sent TO this office
        ✗ Blocked: Random IN (not recipient)
    end note
```

---

## 3. Scan Validation Matrix

```mermaid
flowchart LR
    A[Scan Request] --> B{Current State}
    
    B -->|No History| C{Action Type}
    C -->|IN| D[✓ Accept - First receipt]
    C -->|OUT| E[✗ Reject - Must IN first]
    
    B -->|IN at Office A| F{Action Type}
    F -->|IN at A| G[✗ Reject - Already IN]
    F -->|OUT from A| H[✓ Accept - Ready to forward]
    F -->|IN at B| I[✗ Reject - Must OUT first]
    
    B -->|OUT from A to B| J{Action Type}
    J -->|IN at A| K[✗ Reject - Already OUT]
    J -->|IN at B| L[✓ Accept - Correct recipient]
    J -->|IN at C| M[✗ Reject - Wrong office]
    
    style D fill:#90EE90
    style H fill:#90EE90
    style L fill:#90EE90
    style E fill:#FFB6C1
    style G fill:#FFB6C1
    style I fill:#FFB6C1
    style K fill:#FFB6C1
    style M fill:#FFB6C1
```

---

## 4. Audit Monitoring Flow

```mermaid
flowchart TB
    subgraph ScanEvents["📱 Every Scan Event"]
        direction TB
        SE1[QR Verify]
        SE2[Movement Scan]
        SE3[Duplicate Block]
        SE4[State Rejection]
    end

    subgraph AuditLog["🗄️ Audit Logs Table"]
        direction TB
        AL[event_type, document_id, user_id, office_id]
        AL2[status, outcome, message, meta_json]
        AL3[ip_address, user_agent, created_at]
    end

    subgraph AdminDashboard["📊 Admin QR Monitor"]
        direction TB
        AD1[Summary Cards: Accepted vs Rejected]
        AD2[Top Reject Reasons]
        AD3[Suspicious Users 3+ Rejects]
        AD4[Event Timeline]
        AD5[CSV Export]
    end

    SE1 -->|Write| AuditLog
    SE2 -->|Write| AuditLog
    SE3 -->|Write| AuditLog
    SE4 -->|Write| AuditLog

    AuditLog -->|Query| AdminDashboard
```

---

## 5. Duplicate Prevention Logic

```mermaid
sequenceDiagram
    actor Staff
    participant API as movements-create.php
    participant Helper as movements-helper.php
    participant DB as Database

    Staff->>API: POST /movements-create<br/>{document_id, office_id, status, user_id}
    
    API->>Helper: smartflow_has_recent_duplicate()
    Helper->>DB: SELECT * FROM movements<br/>WHERE document_id = ?<br/>AND office_id = ?<br/>AND status = ?<br/>AND user_id = ?<br/>AND scanned_at >= NOW() - INTERVAL 8 SECOND
    
    alt Found within 8 seconds
        DB-->>Helper: Row found
        Helper-->>API: true (duplicate)
        API->>DB: Log audit: movement.scan REJECTED<br/>scan_error: duplicate
        API-->>Staff: 409 Conflict<br/>"Duplicate scan blocked"
    else Not found
        DB-->>Helper: No rows
        Helper-->>API: false (proceed)
        API->>DB: INSERT movement
        API->>DB: Log audit: movement.scan SUCCESS
        API-->>Staff: 200 OK<br/>Movement recorded
    end
```

---

## 6. Error Code Reference

```
┌────────────────────┬─────────────────────────────────────────────────┐
│ Error Code         │ Scenario                                        │
├────────────────────┼─────────────────────────────────────────────────┤
│ qr_tampered        │ QR signature invalid - possible forgery         │
│ qr_expired         │ Token past 180-day TTL - needs reprint          │
│ qr_mismatch        │ QR doc ≠ scanned doc - wrong label              │
│ duplicate          │ Same scan within 8 seconds                      │
│ already_in_here    │ Marking IN when already IN at this office       │
│ already_out_here   │ Marking IN when already OUT from this office    │
│ still_at_other_office│ Marking IN when doc at different office       │
│ wrong_receiver     │ IN scan at office not designated as recipient   │
│ not_in_at_office   │ OUT scan when doc not currently IN here         │
│ out_without_in     │ First scan is OUT (no prior IN exists)          │
│ missing_destination  │ OUT scan without selecting destination office   │
│ same_destination   │ Destination = current office                    │
│ role_forbidden     │ Admin/Accountant tried to scan (not allowed)    │
│ wrong_office       │ User scanning for different office              │
└────────────────────┴─────────────────────────────────────────────────┘
```

---

## 7. Complete Document Lifecycle

```mermaid
timeline
    title Document Journey: Creation → Archive

    section Creation
        Accounting : Create document record
                 : Generate signed QR token
                 : Print physical folder label

    section Office A
        Staff : Scan IN (first receipt)
              : Work on document
        Staff : Scan OUT to Office B
              : Hand over physically

    section Transit
        Courier : Physical transport
              : Digital trail: OUT at A

    section Office B  
        Staff : Scan IN (validate: was sent here)
              : Work on document
        Staff : Scan OUT to Office C

    section Office C
        Head  : Scan IN
              : Review/Approve
        Staff : Scan OUT to Accounting

    section Close
        Accounting : Scan IN (final)
                   : Process payment/file
                   : Archive document
```

---

## 8. Security Architecture

```mermaid
flowchart TB
    subgraph MobileApp["📱 Flutter App"]
        SCANNER[QR Scanner]
        API_CLIENT[API Client]
        AUTH[Auth Provider]
    end

    subgraph Backend["🔧 PHP Backend (XAMPP)"]
        QR_VERIFY[qr-verify.php]
        MOVEMENT[movements-create.php]
        AUDIT[audit-scans.php]
        HELPER[movements-helper.php]
        TOKEN[qr-token-helper.php]
    end

    subgraph Security["🔐 Security Layer"]
        HMAC[HMAC-SHA256 Signing]
        TTL[180-Day Expiration]
        STATE[State Validation]
        DEBOUNCE[8s Duplicate Guard]
    end

    subgraph Data["🗄️ MySQL Database"]
        DOCS[documents]
        MOV[movements]
        LOGS[audit_logs]
        TOKENS[qr_tokens]
    end

    SCANNER --> API_CLIENT
    API_CLIENT --> AUTH
    AUTH --> QR_VERIFY
    AUTH --> MOVEMENT
    AUTH --> AUDIT

    QR_VERIFY --> TOKEN
    MOVEMENT --> HELPER
    MOVEMENT --> TOKEN

    TOKEN --> HMAC
    TOKEN --> TTL
    HELPER --> STATE
    HELPER --> DEBOUNCE

    QR_VERIFY --> LOGS
    MOVEMENT --> MOV
    MOVEMENT --> LOGS
    AUDIT --> LOGS
```

---

## 9. Use Case Summary Table

| Use Case | Actor | Trigger | Success Outcome | Failure Handling |
|----------|-------|---------|-----------------|------------------|
| **UC1: Create Document** | Accounting | New voucher/payable | Signed QR token issued | Validation errors shown |
| **UC2: Print QR Label** | Accounting/Admin | Document registered | Printable label generated | Token regeneration option |
| **UC3: Verify QR** | Staff/Head | Camera scans QR | Document details shown | Expired/tampered error with code |
| **UC4: Scan IN** | Staff/Head | Document arrives | Movement recorded | State-based rejection with reason |
| **UC5: Scan OUT** | Staff/Head | Document forwarded | Movement + destination recorded | Missing destination or state errors |
| **UC6: Monitor Scans** | Admin | Daily audit review | Dashboard shows stats/rejects | CSV export for compliance |
| **UC7: View Suspicious Activity** | Admin | Anomaly detection | Flagged users list shown | Drill-down to user history |

---

*Generated: 2026-05-29*
*Version: Pre-Defense Implementation*
