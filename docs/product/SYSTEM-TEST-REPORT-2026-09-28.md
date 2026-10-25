# SmartFlow System Test Report

**Date of testing:** September 28, 2026
**System version:** Local development build (post client-validation updates)
**Tested by:** Research team (with AI-assisted automated and manual testing)
**Environment:** Windows 11 · XAMPP (Apache + PHP + MySQL) · React/Vite web client (`localhost:5173`) · Flutter mobile client served as web build (`localhost:8088`, phone viewport)

---

## 1. Executive Summary

SmartFlow was tested end-to-end on both the **web client** and the **mobile client** against the workflow confirmed by the Municipal Accountant in the client discovery sessions (`docs/client/CLIENT-DISCOVERY-ACCOUNTING-HEAD.md`, `docs/client/CLIENT-DISCOVERY-RESPONSES-SUMMARY.md`).

| Area | Result |
| ---- | ------ |
| Backend / API integration suite | **69 of 69 checks passed** (after fixes and follow-up re-test) |
| Web client manual test | **All tested scenarios passed** |
| Mobile client manual test | **All tested scenarios passed** (after rebuild) |
| Defects found during testing | **4 functional defects + 2 minor UI issues — all fixed and retested** |
| Observations | 5 low-severity observations — all resolved the same day (see Section 8) |

The first run of the integration suite exposed four defects, the most serious being a **timezone mismatch** between PHP and MySQL that affected due-date / overdue computation and scan-session expiry. All four were corrected and the full suite was re-run with a 100% pass rate.

---

## 2. Scope

### In scope

- Document registration rules per office and document type (including the new logbook fields)
- Full Disbursement Voucher (DV) custody route: **ENG → BUD → ACC → TRE → MAY → TRE → ACC**
- Approved Budget route: **BUD → ACC**
- QR security: signed payloads, tampering, scan-session expiry, duplicate-scan blocking
- Physical-holder rule (wrong office, double OUT)
- Document requests: routing, accept / decline / payment released, role restrictions
- COA support summary (Monthly and Annual) and export permission
- Audit exceptions, QR scan monitor, and role-based access control
- Web and mobile user interfaces for the above

### Out of scope

- Native Android camera scanning on a physical device (mobile was tested as a Flutter web build in a phone-sized viewport)
- Load / performance testing
- Production HTTPS deployment

---

## 3. Test Approach

| Level | Method | Tools |
| ----- | ------ | ----- |
| Integration / system (API) | Scripted end-to-end scenario using real HTTP calls against the PHP API and live MySQL data, with multiple role accounts | PowerShell script (61 assertions) |
| Web UI | Manual scripted walkthrough in browser | Cursor browser, Chrome DevTools |
| Mobile UI | Manual scripted walkthrough of the Flutter app in a phone viewport | Flutter web-server, Cursor browser |
| Static analysis | Linting of changed files | `flutter analyze`, ESLint |

**Test accounts used:** `neil.admin` (Municipal Accountant / Admin, ACC), `neil.acc.staff` (Accounting clerk), `neil.eng.head`, `neil.bud.head`, `neil.tre.head`, `neil.may.head`, `neil.hr.head`.

All test records were tagged `E2E-TEST` and removed from the database after testing.

---

## 4. Backend / API Test Results (61 / 61 passed)

### 4.1 Registration rules

| ID | Test case | Result |
| -- | --------- | ------ |
| API-01 | ENG registers a DV (HTTP 201) | Pass |
| API-02 | Initial Scan IN automatically recorded at ENG | Pass |
| API-03 | Signed QR payload (`SF1.` prefix) issued | Pass |
| API-04 | BUD cannot register a DV (not in its allowed types) | Pass |
| API-05 | HR cannot register a payroll folder | Pass |
| API-06 | ENG cannot register on behalf of another office | Pass |
| API-07 | Duplicate reference lookup finds the existing DV | Pass |
| API-08 | Logbook fields (reference no., payee, fund source) saved on the document | Pass |
| API-09 | Accounting DV without "received from" office is rejected | Pass |
| API-10 | Approved Budget without reference number is rejected | Pass |
| API-11 | BUD registers an Approved Budget with reference number | Pass |

### 4.2 DV custody route and QR security

| ID | Test case | Result |
| -- | --------- | ------ |
| API-12 | Each handoff on the route ENG → BUD → ACC → TRE → MAY → TRE → ACC recorded (OUT + IN per leg) | Pass |
| API-13 | System suggests the correct next office at each step | Pass |
| API-14 | OUT without a destination office is rejected | Pass |
| API-15 | Scan IN by the wrong office (HR) is rejected | Pass |
| API-16 | Second OUT from ENG (folder no longer held) is rejected | Pass |
| API-17 | Tampered QR payload is rejected | Pass |
| API-18 | Expired scan session (10 minutes old; limit is 5) is rejected | Pass |
| API-19 | Final Scan IN at ACC (folder returned) accepted | Pass |
| API-20 | Immediate duplicate Scan IN is blocked | Pass |
| API-21 | Pilot end note states the DV trail is complete | Pass |
| API-22 | No further forwarding suggestion after trail completion | Pass |
| API-23 | Current custodian is ACC | Pass |
| API-24 | Approved Budget route suggests BUD → ACC | Pass |

### 4.3 Document requests

| ID | Test case | Result |
| -- | --------- | ------ |
| API-25 | Request without a required-by date is rejected | Pass |
| API-26 | Request with a past required-by date is rejected | Pass |
| API-27 | ACC cannot submit a DV request to itself | Pass |
| API-28 | Payroll request is rejected (payslip access only in Phase 1) | Pass |
| API-29 | ENG creates a DV request, routed to ACC | Pass |
| API-30 | TRE cannot mark "payment released" before ACC accepts | Pass |
| API-31 | Non-handler office (BUD) cannot accept an ACC request | Pass |
| API-32 | ACC accepts the DV request | Pass |
| API-33 | ACC cannot mark "payment released" (Treasury only) | Pass |
| API-34 | TRE marks "payment released" | Pass |
| API-35 | ENG budget request is routed to BUD | Pass |
| API-36 | Decline without a reason is blocked by the server | Pass |
| API-37 | BUD declines with a reason | Pass |

### 4.4 Reports and access control

| ID | Test case | Result |
| -- | --------- | ------ |
| API-38 | Monthly COA summary loads for admin | Pass |
| API-39 | Export allowed for Accounting admin | Pass |
| API-40 | Annual COA summary loads for admin | Pass |
| API-41 | COA summary blocked for staff accounts (HTTP 403) | Pass |
| API-42 | Audit exceptions load for ACC admin | Pass |
| API-43 | Audit exceptions blocked for staff | Pass |
| API-44 | QR scan monitor loads for admin | Pass |
| API-45 | Document details require login | Pass |

> The remaining assertions (to a total of 61) are the individual OUT / IN / suggestion checks performed on each leg of the DV route in API-12 and API-13.

---

## 5. Web Client Test Results

| ID | Scenario | Expected | Result |
| -- | -------- | -------- | ------ |
| WEB-01 | Admin opens COA reports, Monthly view | Month summary, submission note (10th of following month), export button | Pass |
| WEB-02 | Switch to Annual view | Year input, annual summary and annual note | Pass |
| WEB-03 | Accounting clerk registers a DV | Reference / payee / fund source required; "Received from office" required and excludes ACC | Pass |
| WEB-04 | Submit Accounting DV with all fields | Document created with tracking ID and QR (DOC-2026-000003) | Pass |
| WEB-05 | Decline a request | Reason field required; after decline, "Separate notice required" popup reminds clerk to notify requester by phone or memo | Pass |
| WEB-06 | View document history trail | All 13 scans listed with names and correct Philippine time | Pass |

---

## 6. Mobile Client Test Results

| ID | Scenario | Expected | Result |
| -- | -------- | -------- | ------ |
| MOB-01 | Login as Municipal Accountant (admin) | Municipal dashboard with office status; role intro dialog | Pass |
| MOB-02 | COA reports — Monthly | Monthly/Annual toggle, "September 2026" summary, export "Ready" for ACC admin | Pass |
| MOB-03 | COA reports — Annual | "Annual 2026" title, annual submission note, Year picker opens | Pass |
| MOB-04 | Login as Accounting clerk | Desk screen with received / sent / on-desk counts; times shown in PH time | Pass |
| MOB-05 | Register DV as Accounting | Logbook fields marked required; "Received from office (required)" dropdown lists BUD, ENG, HR, TRE, MAY only (no ACC); Register button disabled until complete | Pass |
| MOB-06 | Decline a request | Dialog shows "Reason (required)"; OK disabled while empty | Pass |
| MOB-07 | Cancel the decline dialog | Request stays **pending** (verified via API) | Pass |

---

## 7. Defects Found and Resolved

| # | Defect | Severity | Impact | Fix | Status |
| - | ------ | -------- | ------ | --- | ------ |
| D-01 | PHP ran in Europe/Berlin while MySQL used Philippine time (6-hour difference) | **High** | Wrong due / overdue computation; mobile scan sessions never expired because the app sent local time without a timezone | PHP timezone set to `Asia/Manila` (configurable via `APP_TIMEZONE`); MySQL session timezone aligned; mobile now sends UTC timestamps | Fixed, retested |
| D-02 | Duplicate-scan check blocked Treasury's second Scan IN when the folder returned from the Mayor | **High** | Valid DV route could not be completed | Duplicate check now compares only against the latest movement of the document | Fixed, retested |
| D-03 | Server accepted a request decline with no reason | Medium | Did not follow client rule that declines must be explained | API returns HTTP 400 when reason is missing | Fixed, retested |
| D-04 | Mobile: pressing **Cancel** on the decline dialog still declined the request | **High** | Accidental declines | Cancel now aborts; OK disabled until a reason is typed | Fixed, retested |
| D-05 | Mobile COA subtitle said "Monthly…" even in Annual mode | Low | Misleading label | Subtitle changed to "Monthly or annual handoff metrics…" | Fixed |
| D-06 | Mobile Year picker opened at 2010–2024, hiding the current year | Low | Extra scrolling | Range limited to the last 5 years | Fixed |

---

## 8. Observations and Follow-up Fixes

The observations below were logged during the first test pass and **resolved the same day**.

| # | Observation | Resolution | Status |
| - | ----------- | ---------- | ------ |
| O-01 | Flutter `widget_test.dart` looked for the text "SmartFlow", but the logo is split into "Smart" + "Flow", so the widget test failed | Test updated to match the current logo (with SharedPreferences mock); `flutter test` passes | Resolved |
| O-02 | A fulfilled DV request was labeled "Closed" instead of "Payment released" | Web and mobile now show **"Payment released"** for fulfilled disbursement requests ("Closed" for other categories) | Resolved |
| O-03 | A DV that completed its trail (returned to ACC) still showed a due date and counted as active / could become overdue | New trail-completion rule: DV is complete when it is back IN at ACC after TRE and MAY; Approved Budget is complete when IN at ACC after BUD. Completed folders show **"Completed"**, have no due date, and are excluded from active counts, clerk desk tray, overdue alerts, system status, and head analytics delay counts. The Approved Budget no longer suggests a further forward from ACC | Resolved |
| O-04 | Dev tools (`dev-reset-system.php`, `dev-purge-demo-documents.php`) were enabled by default | Dev tools are now **forced off whenever `APP_ENV=production`**, even if `ALLOW_DEV_TOOLS` is left as `true` | Resolved |
| O-05 | `flutter analyze` reported 3 deprecation notices (`value` → `initialValue`) | Replaced with `initialValue` (keyed so the dropdowns still update); analyzer reports no issues | Resolved |

### Re-test after follow-up fixes

| ID | Test case | Result |
| -- | --------- | ------ |
| API-46 | Completed DV flagged `trail_complete` | Pass |
| API-47 | Completed DV has no due date and is not overdue | Pass |
| API-48 | Completed DV not listed in ACC clerk desk tray | Pass |
| API-49 | Completed DV not counted as active at ACC (admin dashboard) | Pass |
| API-50 | Department head queue shows the DV as "Completed" | Pass |
| API-51 | BUD Scan OUT Approved Budget → ACC | Pass |
| API-52 | ACC Scan IN Approved Budget | Pass |
| API-53 | Approved Budget trail complete at ACC with no further suggestion | Pass |

Full suite re-run: **69 of 69 checks passed**. System status, municipal alerts, office alerts, and head analytics endpoints were also smoke-tested (HTTP 200). Web production build and `flutter test` / `flutter analyze` completed without errors.

---

## 9. Conclusion

After correcting the six defects in Section 7 and the five observations in Section 8, SmartFlow passed **all 69 automated API checks**, **all 6 web scenarios**, and **all 7 mobile scenarios**. The system correctly enforces the client-validated workflow: the full DV custody route with a mandatory return to Accounting, the Approved Budget route, the physical-holder rule, signed and time-limited QR scans, two-layer document requests (Accounting accepts, Treasury releases payment), required decline reasons with a separate-notice reminder, and Accounting-only COA export.

The system is considered **ready for User Acceptance Testing (UAT)** with LGU users, subject to testing native QR camera scanning on a physical Android device and building the mobile app with `--dart-define=ENV=production` (keeps users signed in) and setting `APP_ENV=production` in the server `.env` for the pilot.
