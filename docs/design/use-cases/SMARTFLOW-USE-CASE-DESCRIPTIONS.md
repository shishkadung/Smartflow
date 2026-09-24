# SmartFlow Use Case Descriptions

## Instructions for Each Actor

---

## 1. Accounting

**Role:** Creates documents and prints QR labels for physical folders.

| Use Case | Description | How To |
|----------|-------------|--------|
| **Create Document** | Register a new document (voucher, payable, etc.) in the system | 1. Log in as Accounting<br>2. Click "Create Document"<br>3. Enter title, type, origin office<br>4. Save - system generates DOC-ID |
| **Print QR Label** | Generate printable QR label with signed token | 1. Find document in list<br>2. Click "Print QR"<br>3. System creates SF1 token<br>4. Print label, attach to physical folder |
| **Reprint Label** | Issue new QR token when label is damaged/lost | 1. Search document<br>2. Click "Reprint Label"<br>3. Old token revoked, new token issued<br>4. Print new label |

---

## 2. Staff/Clerk

**Role:** Scan documents IN when received, OUT when forwarded.

| Use Case | Description | How To |
|----------|-------------|--------|
| **Scan IN** | Record document arrival at your office | 1. Tap "Scan IN"<br>2. Scan QR label on folder<br>3. System verifies token (signature + expiry)<br>4. Document marked IN at your office |
| **Scan OUT** | Record document departure to another office | 1. Tap "Scan OUT"<br>2. Scan QR label<br>3. Select destination office<br>4. Document marked OUT, alert sent to recipient |
| **Verify QR** | *Included in Scan IN/OUT* - Validates signed token | System automatically checks:<br>- Signature valid?<br>- Expired? (180 days)<br>- Matches document? |
| **Block Duplicate** | *Included in Scan* - Prevents double-submit within 8 seconds | If same scan within 8s:<br>"Duplicate scan blocked" error shown |
| **View Document History** | See movement trail of a document | 1. Search document<br>2. View timeline: IN/OUT at each office |

**State Rules You Follow:**
- ✓ First scan must be IN
- ✗ Cannot scan IN twice at same office
- ✓ Must be IN before scanning OUT
- ✓ OUT requires selecting destination office

---

## 3. Department Head

**Role:** Same scanning as Staff, plus monitoring office alerts.

| Use Case | Description | How To |
|----------|-------------|--------|
| **Scan IN** | Receive documents at your office | Same as Staff |
| **Scan OUT** | Forward documents to other offices | Same as Staff |
| **Verify QR** | *Included* - Token validation | Automatic on scan |
| **View Alerts** | See stuck/lost documents in your office | 1. Open "Alerts" tab<br>2. View documents OUT too long<br>3. View unconfirmed receipts |
| **Track Location** | Find where a document currently is | 1. Search document<br>2. See current office + last scan time |
| **View Document History** | Full movement audit trail | Same as Staff |

**Extra Responsibility:**
- Monitor alerts for your office's document delays
- Ensure staff scan promptly

---

## 4. System Admin

**Role:** Monitor all system activity, manage audits, investigate issues.

| Use Case | Description | How To |
|----------|-------------|--------|
| **Monitor Scans** | Real-time dashboard of all scan activity | 1. Open "QR Monitor"<br>2. View accepted vs rejected scans<br>3. Filter by time (24h/48h/7 days)<br>4. See top reject reasons |
| **View Suspicious** | Detect users with multiple failed scans | Dashboard shows:<br>- Users with 3+ rejected scans<br>- Possible training issues or security concern |
| **Export Audit CSV** | Download scan history for compliance | 1. Set filters (date range, office)<br>2. Click "Export CSV"<br>3. Copy/paste to Excel for records |
| **Reprint Label** | Help Accounting reprint lost labels | Admin override to reprint any document's QR |

**What You Monitor:**
- Total scans (accepted/rejected)
- QR errors (expired, tampered, invalid)
- State violations (duplicate, wrong office)
- Suspicious scan patterns

---

## 5. COA Auditor

**Role:** External auditor verifying document custody compliance.

| Use Case | Description | How To |
|----------|-------------|--------|
| **View Audit Reports** | Access all scan audit logs | 1. Log in as COA<br>2. Access audit dashboard<br>3. View all scan events with timestamps |
| **Verify Compliance** | Check if custody rules were followed | Review:<br>- Documents properly scanned IN/OUT<br>- No missing scan records<br>- Chain of custody intact |
| **Access Trail** | See full document lifecycle | 1. Search any document<br>2. View complete trail:<br>   Created → Scanned → Forwarded → Archived |
| **Generate Report** | Export findings for COA submission | 1. Select date range<br>2. Generate compliance report<br>3. PDF/CSV export for official records |
| **Track Location** | Find current location of any document | Real-time tracking:<br>Which office currently holds the document |

**COA Checks:**
- ✓ Every document has complete audit trail
- ✓ No gaps in custody chain
- ✓ QR security working (signed tokens)
- ✓ State rules enforced (no IN→IN, etc.)
- ✓ Expired/revoked labels handled properly

---

## Use Case Relationships

```
Scan IN ──includes──→ Verify QR Token
    │
    └──includes──→ Block Duplicate (8s debounce)

Scan OUT ──includes──→ Verify QR Token
    │
    └──includes──→ Check State Rules

Verify QR ──extends──→ View Document History
    (on success, can view full trail)
```

---

## Quick Reference: Error Codes by Actor

| Error Code | What Happened | Actor Action |
|------------|---------------|--------------|
| `qr_expired` | Label older than 180 days | Staff: Tell Accounting to reprint |
| `qr_tampered` | Signature doesn't match | Staff: Label may be forged - notify Admin |
| `duplicate` | Scanned same doc twice in 8s | Staff: Wait, then retry if needed |
| `already_in_here` | Trying IN when already IN | Staff: Doc already received, no action needed |
| `not_in_at_office` | OUT scan but doc not here | Staff: Check if doc physically present |
| `wrong_receiver` | IN at office not designated | Staff: Verify you're the correct recipient |

---

## System Security Features (All Actors Benefit)

| Feature | How It Protects |
|---------|-----------------|
| **Signed QR Tokens (SF1)** | Prevents forged labels - only system can generate valid tokens |
| **180-Day Expiry** | Old labels auto-reject - forces periodic reprint/validation |
| **State Machine** | Prevents logical errors (IN→IN, OUT without IN) |
| **8-Second Debounce** | Stops accidental double-scans |
| **Full Audit Trail** | Every action logged with user, time, office, IP |
| **Audit Dashboard** | Admin/COA can detect suspicious patterns |

---

*Generated: May 2026*  
*Version: Pre-Defense Implementation*
