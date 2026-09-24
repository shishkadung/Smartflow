# SmartFlow — Panel Revision Checklist

**Source:** Three panel revision sheets (National Teachers College, BSIT 3-3)  
**Project:** SmartFlow — QR-Based Inter-Department Document Flow Tracking and COA Compliance System for the Municipality of Urbiztondo  
**Last updated:** May 2026

Use this for re-defense prep. Status keys:

| Symbol | Meaning |
|--------|---------|
| ✅ | Done (implemented or addressed in manuscript/code) |
| ⏳ | Partial (started, needs paper polish or full system finish) |
| ❌ | Not yet done |

---

## Panel 1 — Technical (SDLC, security, QR, HTTPS)

| # | Panel comment | Status | Notes |
|---|---------------|--------|-------|
| 1 | Conceptual framework: put **SDLC in Process** | ⏳ | `docs/thesis/chapter-1/conceptual-framework-ipo.md` mentions SDLC in Input; Figure 1 may still need explicit **SDLC/Waterfall in PROCESS box** in Word. |
| 2 | Change SDLC to **Waterfall** | ❌ | Manuscript still says **Agile SDLC** (`SmartFlow_Capstone1.md` §2.1.3). |
| 3 | Encryption: **AES, RSA + SHA hashing** | ⏳ | Login uses `password_hash` (bcrypt). No AES/RSA/SHA for QR payloads yet. |
| 4 | **QR code expiration** | ❌ | QR payload is plain document ID (`qr.php`, register `qr_payload`). |
| 5 | **Implement HTTPS** | ⏳ | Docs mention HTTPS in production; dev uses HTTP (XAMPP). Demo HTTPS possible via **cloudflared tunnel** (`https://….trycloudflare.com`). |
| 6 | **Prevent duplicate scanning** | ✅ | `smartflow_has_recent_duplicate_movement()` in `movements-helper.php` blocks repeat scans (~8 seconds). |
| 7 | Students should know **COA process** | ⏳ | Client discovery + defense Q&A + COA reports in app; add clear **written COA flow section** in Chapter I/II. |
| 8 | **Audit / monitor QR usage** | ⏳ | `audit_logs` + `smartflow_write_audit_log()` on scans; `audit-exceptions.php` for custody gaps. No dedicated **QR usage monitor** admin screen yet. |

---

## Panel 2 — Documentation & diagrams

| # | Panel comment | Status | Notes |
|---|---------------|--------|-------|
| 1 | **Introduction** — 1 page only | ❌ | `SmartFlow_Capstone1.md` has long intro (1.0, 1.1, 1.2, significance, etc.), not one consolidated page. |
| 2 | **Objectives** — too many specific objectives | ❌ | Still 8 bullet specific objectives (§1.2.2); panel wants fewer / merged. |
| 3 | **System flowchart** — fix background, make visible | ❌ | Flowcharts in `docs/thesis/chapter-2/flowcharts/` and manuscript images; panel wants **clearer visuals** in bound doc. |
| 4 | **Revise Use Case Diagram** | ❌ | Use case in manuscript §2.1.6; `docs/thesis/chapter-03-system-design.md` is still a **placeholder**. |
| 5 | *(blank)* | — | — |
| 6 | *(blank)* | — | — |

**Panel notes (bottom of sheet):**

| Note | Status | Notes |
|------|--------|-------|
| Make sure to have **security on QR code** | ❌ | Same as Panel 1 #3 and Panel 3 #1. |
| Provide **expiration on QR code** | ❌ | Same as Panel 1 #4. |

---

## Panel 3 — Innovation & encrypted QR

| # | Panel comment | Status | Notes |
|---|---------------|--------|-------|
| 1 | **QR encrypted**; only SmartFlow app can decrypt | ❌ | QR encodes plain `DOC-…` ID; any scanner can read it. |
| 2 | **Reschedule** — present system with **significant innovation** | ⏳ | Working Flutter pilot + DV trail + requests + COA exceptions is strong; frame **encrypted QR, HTTPS, audit dashboard** as revision innovations. |

---

## Already implemented (cite during defense)

| Item | Where |
|------|--------|
| Duplicate scan prevention | `backend/backend/api/movements-helper.php` |
| Movement audit trail (office, user, timestamp) | `movements` table + History in Flutter |
| COA-oriented reporting | `reports-summary.php`, admin COA UI |
| Audit exceptions (custody gaps) | `audit-exceptions.php` |
| Scan action logging | `audit_logs` + `smartflow_write_audit_log()` |
| Client-aligned pilot (DV trail, roles, required-by) | `docs/client/CLIENT-DISCOVERY-RESPONSES-SUMMARY.md` |
| Defense / demo runbooks | `docs/defense/DEFENSE-CHECKLIST.md`, `docs/defense/PRE-DEFENSE-BUKAS.md` |

---

## Priority before re-defense (highest impact)

### Paper / manuscript

- [ ] Replace **Agile** with **Waterfall** SDLC in §2.1.3 + new Figure 2.4
- [ ] Add **SDLC/Waterfall** inside conceptual framework **PROCESS** box (Figure 1)
- [ ] Condense **Introduction** to **1 page**
- [ ] Merge/trim **specific objectives** (§1.2.2)
- [ ] Revise **system flowchart** figures (visible background)
- [ ] Revise **use case diagram** (§2.1.6)
- [ ] Add **COA process** subsection (what LGU does vs what SmartFlow logs)

### System (panel security & innovation)

- [ ] **QR expiration** (time-limited token in payload)
- [ ] **QR security** — signed/encrypted payload (e.g. HMAC-SHA256 + expiry; app-only validate)
- [ ] **HTTPS** — production plan; demo via cloudflared if needed
- [ ] **QR usage monitor** admin view (from `audit_logs`)

---

## Summary counts

| Status | Panel 1 | Panel 2 | Panel 3 | Total items* |
|--------|---------|---------|---------|--------------|
| ✅ Done | 1 | 0 | 0 | 1 |
| ⏳ Partial | 4 | 0 | 1 | 5 |
| ❌ Not yet | 3 | 4+2 notes | 1 | 10 |

\*Excludes blank rows and duplicate note items counted under Panel 2 notes.

---

## One-liner for panel Q&A

> *Duplicate scan blocking, movement audit logs, and COA exception reporting are implemented. SDLC figure, introduction/objectives, use case/flowchart revisions, QR encryption with expiration, full HTTPS deployment, and a dedicated QR usage monitor are documented as revisions in progress.*

---

## Related docs

| File | Purpose |
|------|---------|
| `docs/defense/DEFENSE-CHECKLIST.md` | Demo week checklist |
| `docs/defense/PRE-DEFENSE-BUKAS.md` | Night-before runbook |
| `docs/client/CLIENT-DISCOVERY-RESPONSES-SUMMARY.md` | Municipal Accountant validation |
| `docs/thesis/chapter-1/conceptual-framework-ipo.md` | Figure 1 IPO text |
| `docs/thesis/SmartFlow_Capstone1.md` | Full manuscript |
