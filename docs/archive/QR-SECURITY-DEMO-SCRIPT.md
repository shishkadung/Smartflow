# QR Security Encryption Demo Script

> **Panel Recommendation #1**: QR code security encrypted and the application that can decrypt will be your system.

---

## Demo Overview

**Duration**: 5 minutes  
**Goal**: Show encrypted QR format and system-only decryption capability  

---

## Setup (1 minute)

1. **Prerequisites**:
   - Document already registered in SmartFlow
   - QR code displayed on screen
   - Flutter app running with scanner ready

2. **Opening Statement**:
   > *"SmartFlow uses encrypted QR codes - hindi na plain document ID ang nakasulat. Only our system can decrypt and verify them."*

---

## Step 1: Show Encrypted Format (30 seconds)

### Visual Display
```
QR Code Content:
SF1.eyJkIjoiRE9DLTIwMjQtMTIzNDU2IiwiaSI6MTcxNjgwMDQwMCwiZSI6MTczMjM2MjQwMH0.abc123def456...

Format: SF1.{base64url(json)}.{base64url(hmac-sha256 signature)}
```

### Talking Points
- **"SF1 prefix"** - identifies SmartFlow secured tokens
- **"Middle part"** - encrypted document data (ID, issue time, expiry)
- **"Last part"** - digital signature for tamper protection

---

## Step 2: Legitimate QR Verification (1 minute)

### Action Sequence
1. **Scan valid QR code** with Flutter app
2. **Show success message**: "Secured QR verified" ✅
3. **Display server response**:
   ```json
   {
     "valid": true,
     "document_id": "DOC-2024-123456",
     "message": "QR verified",
     "issued_at": "2026-05-28T10:00:00Z",
     "expires_at": "2026-11-24T10:00:00Z"
   }
   ```

### Explanation
> *"Server validates: signature + format + expiration. Only then ibibigay ang document ID."*

---

## Step 3: Security Demonstrations (2 minutes)

### A. Tampered QR Rejection

**Action**:
1. Copy QR content manually
2. **Change 1 character** in the middle part
3. **Paste in manual QR field** → Scan

**Expected Result**:
```
❌ Invalid QR — label may be damaged or forged. Reprint from SmartFlow.
```

**Explanation**:
> *"Digital signature failed. System detected tampering. Automatic reject."*

### B. Format Validation

**Action**:
1. Remove SF1 prefix → `eyJkIjoiRE9D...`
2. **Scan modified QR**

**Expected Result**:
```
❌ Unrecognized QR format
```

### C. Expiration Demo (Optional)

**Setup**: Use expired test token or modify expiry timestamp

**Expected Result**:
```
❌ This QR label has expired. Ask Accounting to reprint the label.
```

---

## Step 4: System-Only Decryption (1 minute)

### Technical Explanation

> **"Why only SmartFlow can decrypt:"**

1. **Secret Key**: Stored in `.qr-secret` file on server
2. **HMAC-SHA256**: Cryptographic signature verification
3. **Base64URL Decoding**: Converts encrypted payload back to JSON
4. **Validation Pipeline**: Format → Signature → Expiration → Content

### Security Benefits

- **🔒 Tamper-proof**: Any modification = signature mismatch
- **⏰ Time-limited**: 180-day auto-expiration
- **🔐 System-exclusive**: External apps cannot read our QR codes
- **📝 Audit-ready**: All verification attempts logged

---

## Key Panel Talking Points

### When asked about encryption:
> *"Ang QR namin gumagamit ng signed token format: SF1.{payload}.{signature}. Server-side verification sa bawat scan."*

### When asked about security:
> *"Hindi pwede i-copy-paste ang QR namin. May digital signature na server-side lang mabasa. Pag tampered, automatic reject."*

### When asked about decryption:
> *"Ang system lang ang maka-decrypt dahil sa secret key at HMAC verification. External apps cannot read our encrypted QR codes."*

---

## Technical References

**Implementation Files**:
- `qr-token-helper.php` - Encryption/decryption logic
- `qr-verify.php` - API endpoint for verification
- `movements-create.php` - QR validation in document flow

**Security Features**:
- ✅ HMAC-SHA256 digital signatures
- ✅ 180-day token expiration
- ✅ Format validation (DOC-YYYY-XXXXXX)
- ✅ Tamper detection and rejection
- ✅ System-only decryption capability

---

## Demo Success Criteria

- [ ] Show encrypted QR format (SF1 prefix)
- [ ] Demonstrate successful verification
- [ ] Show tampered QR rejection
- [ ] Explain system-only decryption
- [ ] Connect to Panel Recommendation #1

**Result**: Complete demonstration of QR security encryption compliance ✅
