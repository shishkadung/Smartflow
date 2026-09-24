# SmartFlow — Overall Polish Checklist

**Goal:** UI/UX at copy polished across **lahat ng roles** (clerk, head, admin, auth) para sa deployment ang natitira: server, accounts, training — hindi na “ayusin ang app.”

**How to use:** Gawin **isa-isa**, top to bottom. Mark `[x]` kapag tapos + na-test sa device/emulator. Hot restart: `R` sa Flutter terminal.

**Sync backend** (kung may PHP edits):  
`Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass` → `.\scripts\sync-backend-to-xampp.ps1`

---

## Legend

| Symbol | Meaning |
|--------|---------|
| `[x]` | Done (based on recent polish pass — verify pa rin) |
| `[ ]` | Not done / verify ulit |
| **P0** | Do before defense |
| **P1** | Do before “deployment-ready” handoff |
| **P2** | Nice-to-have / post-defense |

---

## Phase 0 — Baseline (5 min)

- [x] XAMPP Apache + MySQL ON
- [x] `.\scripts\sync-backend-to-xampp.ps1` success
- [x] `http://localhost/Smartflow/backend/backend/api/dev-api-health.php` → OK
- [ ] `flutter run` sa `mobile\flutter` — walang red API banner sa Home *(verify manually on device)*
- [ ] Purge test data kung malinis na demo: `dev-purge-demo-documents.php?all=1`

---

## Phase 1 — Vocabulary & consistency (app-wide)

**Standard (gamitin sa buong app):**

| Old / mixed | Standard |
|-------------|----------|
| In-Flow, IN today | **Received** (today) |
| Out-Flow, OUT today | **Sent** (today) |
| QR Tags active, At desk | **On desk** (now) |
| IN only / OUT only (filters) | **Received** / **Sent** |
| OUT pill (lists) | **SENT** (red) |
| declined (requests) | **Declined** |

### 1.1 Clerk (staff)

- [x] **P0** Home stats: Received / Sent / On desk + hint
- [x] **P0** Home: “At your office now” always visible + empty card
- [x] **P0** Home: tap Received/Sent → History filtered; On desk → scroll
- [x] **P0** Today’s activity: exact time (`2:14 PM`)
- [x] **P1** Profile mini-stats: Received / Sent / On desk
- [ ] **P1** Scan / History / Alerts: `SfClerkPageOverviewCard` (same chrome as Home) — *optional unify*
- [x] **P0** Scan: Quick open (below Look up); blocked-forward card
- [x] **P1** Scan: neutral ops copy (forwarded folder hint)
- [x] **P0** History: lookup field + Received/Sent chips + movement timeline
- [x] **P1** History: empty filter states → `SfEmptyState`
- [x] **P0** Mark IN button labels unified (“Mark IN”)

### 1.2 Head (supervisor)

- [x] **P0** Staff activity list: SENT/IN + `formatMovementListTime`
- [x] **P1** Queue: “Awaiting receive” filter aligned with dashboard preview
- [x] **P1** Head Home: “Updated … pull to refresh” footer
- [x] **P1** Head Analytics: last-sync line + empty if no stats
- [ ] **P2** Head Queue / Alerts: filter-empty → `SfEmptyState`

### 1.3 Admin (Municipal Accountant)

- [x] **P0** COA Reports: prominent export card + submission note
- [x] **P1** Admin Thresholds: “Max processing hours” + validation + errors
- [x] **P1** Admin System: fallback UI kung walang status payload
- [ ] **P2** Admin Users: empty state kapag Pending filter walang laman
- [ ] **P2** Admin dashboard: sync label style (match staff/head relative time)

### 1.4 Shared screens

- [x] **P0** Document Requests: layer banner + status labels + due-by box
- [x] **P1** Document Requests: empty inbox/mine + New request CTA
- [x] **P1** Register (clerk): overview card + office tips
- [x] **P1** Document Requests: role-specific overview card (staff/head/admin)
- [x] **P0** Register success: next steps + QR + Open Scanner

---

## Phase 2 — Auth (public) — deployment onboarding

- [x] **P1** Get Started: secondary **Sign up** link
- [x] **P1** Login: field hints
- [x] **P1** Signup: **Step 1 of 2 / Step 2 of 2**
- [x] **P1** Signup: errors → `SfErrorBanner`
- [x] **P1** Signup: offices load fail → error + retry
- [x] **P2** Signup pending: approval copy pass

---

## Phase 3 — Alerts & badges (all roles)

- [x] **P0** Staff alert badge = visible count (not hidden/snoozed)
- [x] **P0** Staff badge updates after acknowledge / snooze / restore
- [x] **P1** Head alert badge uses same `AlertActionsStore.visibleCount`
- [x] **P1** Staff alerts: filter-empty → `SfEmptyState`
- [x] **P1** Head alerts: filter-empty → `SfEmptyState`
- [ ] **P2** Snooze/ack copy review (pilot vs production)

---

## Phase 4 — Per-role smoke test (after each phase)

Gawin after Phase 1–2 batches. One login per row; **30 sec** lang each.

| # | User | Quick check | API (May 27) |
|---|------|-------------|--------------|
| 1 | `engineering.staff` | Home stats → Register DV → Scan OUT → History | ✅ dashboard + requests |
| 2 | `budget.staff` | Scan IN → OUT → Home | ✅ dashboard |
| 3 | `accounting.staff` | Scan IN → History timeline | ✅ dashboard + alerts |
| 4 | `accountant.main` | Admin → COA Reports → copy summary | ✅ admin + COA export |
| 5 | `head.engineering` | Queue → filter → History (monitor) | ✅ queue + analytics |
| 6 | `hr.staff` | Register empty state message (expected) | ✅ login + HR office |

- [x] **API smoke** — 6/6 pass (`fix-api.ps1` + per-user endpoints)
- [ ] **UI smoke** — tap-through on emulator/device — use [`UI-VALIDATION-5MIN.md`](UI-VALIDATION-5MIN.md) (seal · Scan · COA heroes + clerk Mark OUT/IN)

---

## Phase 5 — Docs & defense alignment

- [x] **P0** `DEMO-SCRIPT.md` — dashboard Q&A
- [x] **P0** `PRE-DEFENSE-BUKAS.md`
- [x] **P1** `presentation-script.md` — restored, mobile-first
- [ ] **P1** Thesis slides: align “React web” vs Flutter prototype (if panel asks)
- [x] **P1** `CLIENT-DISCOVERY-RESPONSES-SUMMARY.md`

---

## Phase 6 — Deployment-only (huwag gawin bago defense kung wala oras)

*Ito ang “susunod” after polish — hindi UI.*

- [ ] Production server (Apache/PHP/MySQL) + HTTPS/LAN
- [ ] Real office accounts (not demo seed only)
- [ ] Printer workflow for QR labels
- [x] Treasury/Mayor offices (TRE + MAY in routing, seed users, signup)
- [ ] Server-backed alert ack (today: per-device `AlertActionsStore`)
- [ ] Backup / restore procedure
- [ ] User training (1-pager per role)

---

## Suggested order (chill — 1 item per session)

| Session | Task ID | Ano |
|---------|---------|-----|
| 1 | Phase 0 | Baseline health |
| 2 | 2.1–2.4 | Get Started + Signup polish |
| 3 | 1.3 Admin Thresholds | Labels + validation |
| 4 | 1.3 Admin System | Fallback UI |
| 5 | 1.1 Scan | Remove “Demo tip” → ops copy |
| 6 | 1.1 History | Empty states `SfEmptyState` |
| 7 | 1.2 Head Home | Last refreshed footer |
| 8 | 1.2 Head Analytics | Sync + empty |
| 9 | 1.4 Requests | Overview card per role |
| 10 | Phase 4 | Full smoke test table |
| 11 | Phase 5 | Slides alignment |

---

## When you say “tapos na polish”

- [ ] Lahat **P0** at **P1** checked
- [ ] Phase 4 smoke test — walang crash, walang misleading label
- [ ] One full **DV demo** rehearsal (`DEMO-SCRIPT.md` Part 2)
- [ ] Panel one-liners memorized (Treasury, HR, On desk = 0, not approval)

---

*Last updated: Sep 2026 — UI polish pass (seal · compact · tokens · hierarchy · micro · heroes). Validate with [`UI-VALIDATION-5MIN.md`](UI-VALIDATION-5MIN.md).*
