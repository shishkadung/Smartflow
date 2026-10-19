# SmartFlow office-to-office pilot

Prepared **17 October 2026**, Asia/Manila. The project user selected **web + Android across ENG, HR, BUD, ACC, TRE and MAY**. This is the pilot runbook and unsigned acceptance record. Actual office UAT has **not started**. Current local rehearsal evidence is recorded separately in [the rehearsal report](../../.runtime/pilot-2026-10-17/report.md).

## Purpose and completion rule

Demonstrate that staff can track two sample physical folders across offices, keep accurate receipt/history evidence, and handle their separate request tickets on web and Android. A participant must perform the actions and confirm that the displayed state matches the sample packet in their hands.

An automated API rehearsal or a mocked browser/widget check is technical evidence. Mark a manual row Passed only after a participant performs it on the stated client and the observer records the outcome. Pending, blocked and failed rows do not count as passes. This pilot is not a production approval, financial approval or payment execution.

## People, environment and equipment

Assign a facilitator/observer and a staff participant for each of the six offices. Also assign an office head and an Accounting administrator to review monitoring, history and reports. An ordinary head remains office-scoped; municipal Accounting oversight uses the Accounting admin role.

Use a separately identified staging API/database with synthetic accounts and paper props marked **PILOT / NO REAL TRANSACTION**. Do not add test handoffs, accounts or payment-release declarations to the working municipal database. Do not reset, reseed, restore over, deploy to or sign out existing operational sessions as a pilot setup step. The transient API rehearsal script below removes its own data; it does not provision an interactive staging deployment.

Before the first handoff, the facilitator completes this record:

| Setup item | Actual value / responsible person | State |
|---|---|---|
| Facilitator, observer, six staff participants, head and Accounting admin | To assign; names/initials only | Pending |
| Staging web URL and exact API base | To verify against intended isolated deployment | Pending |
| Staging database identity and its separation from operational data | To verify with environment owner; never record credentials | Pending |
| Web source/build identity; Android APK hash and configured API base | Record exact artifacts used; do not assume an older installed APK is current | Pending |
| Desktop browser/version and Android model/version | At least one real Android phone plus web workstation; record each device | Pending |
| Android installation/session plan | Use a dedicated pilot device/session; no operational app data reset | Pending |
| Connectivity, camera permission and label scan | Same staging environment reachable by web and phone | Pending |
| Label printer and phone/web file-save destinations | Print and read back actual saved outputs | Pending |
| Two labelled sample packets | Ordinary packet and DV packet, each with main document 2 pages + supporting schedule 3 pages | Pending |
| Run date/time and evidence folder | Asia/Manila; screenshots must contain synthetic data only | Pending |

Resolve the API base before any sign-in. A physical phone cannot use its own localhost to reach the PC; the emulator's `10.0.2.2` is emulator-specific. The protected port-8000 launcher is loopback-only. A Vite development proxy is not a deployed production proxy. Android's allowed HTTP hosts can differ from an arbitrary LAN address. Use an already reviewed reachable staging configuration; do not bypass certificate warnings, disable network protections or edit global device settings to make a test pass. See [Architecture](../ARCHITECTURE.md#local-runtime-and-addresses).

Use separate browser profiles or dedicated devices for simultaneous participants. Ordinary tabs within one profile share login storage and propagate account changes; use them only for the same identity. Sequential account switching is acceptable if each participant verifies the new office/role and opens fresh reviewed details before acting. Every participant checks office, role and tracking ID before confirming. Keep credentials, bearer tokens, QR payloads/signing material and real personal data out of the acceptance record.

## Suggested session order

1. Verify the setup and show the difference between a folder, a request ticket and payment-release recording.
2. Run ordinary-folder scenario A. HR and ENG establish receipt, filing and independent ticket closure.
3. Run DV scenario B. The other four offices join the nominal route; Treasury records the separate simulated release.
4. Run cross-client checks C and inspect complete history and reports together.
5. Record failures, blocked items and participant decisions before signing. Allow extra time for setup and defects; a suggested 90–120 minute session is a planning allowance, not a measured duration.

The client assignments below exercise both web and Android on one shared staging dataset. On a later pass, exchange web/Android assignments for receipt and forwarding to cover the opposite client direction. Record which pass actually ran.

## Scenario A — ordinary folder, request, receipt and filing

Use a named type such as `Others: Pilot correspondence`. HR physically holds the five-page packet before registration. Use the actual generated tracking ID and request code throughout; leave the fields below blank until created. Set the required-by date to the pilot date or a later local date through the normal request UI.

Folder ID: ______  Request code: ______  Required by: ______

| ID | Participant / client | Action and expected outcome | Result / evidence |
|---|---|---|---|
| A1 | ENG staff / web | Create **From office → HR** with a complete purpose and required-by date. One general request appears in My requests and HR Inbox. No folder/custody is created by requesting. | Pending |
| A2 | HR staff / Android | Accept with review notes. Ticket becomes Accepted. No physical handoff occurs. | Pending |
| A3 | HR staff / web | Register the packet already held by HR, recording main document 2 pages and supporting schedule 3 pages with the physical-count confirmation. Link the accepted ticket through the supported registration/link action. Expect one folder, one initial HR IN, unchanged Accepted status and preserved review notes. | Pending |
| A4 | ENG staff / web and Android | Open the exact linked folder from Requests, inspect location/history, then **Back to request**. Outside-tray detail stays read-only. Web restores committed tab/filter/search/page/selection; Android preserves the view and refreshes the ticket before reopening details. | Pending |
| A5 | HR staff / web | Scan/look up the ID first and inspect history: lookup adds no event. Explicitly forward to ENG. HR OUT is recorded once; ENG sees incoming/awaiting receipt, with HR as sender. | Pending |
| A6 | ENG staff / Android | Open Receive and cancel once. No event or receipt is recorded. Reopen, count the actual 2 + 3 pages and confirm physical receipt once. One ENG IN appears with actual counts; the other client observes the same saved outcome after refresh. | Pending |
| A7 | ENG staff / web | Cancel File once and verify it remains active. Reopen File and explicitly confirm the reviewed folder. Folder becomes filed/completed, history remains intact and the ticket remains Accepted. Filing adds no IN/OUT. | Pending |
| A8 | HR staff / Android | Close the ticket with outcome notes after the requested work is done. Original acceptance and separate closing actor/time/notes remain visible. Request closure adds no custody event. | Pending |

Expected final custody: **HR IN → HR OUT → ENG IN**, exactly **3 movements**. Explicit filing is a separate recorded state. Expected final request: **Closed**, with separate review and outcome evidence.

## Scenario B — DV route and separate payment-release ticket

ENG physically holds the five-page DV packet before registration. Use synthetic reference/payee/fund-source values, clearly labelled as pilot content. This scenario follows the normal route; it does not establish that every intermediate hop is mandatory.

Folder ID: ______  Request code: ______  Reference: ______

| ID | Participant / client | Action and expected outcome | Result / evidence |
|---|---|---|---|
| B1 | ENG staff / Android | Register a Disbursement Voucher with required metadata and the 2 + 3 page inventory. One initial ENG IN and one tracking ID/label are created. Save/print the label and read it back on web/phone. Opening/scanning the label alone adds nothing. | Pending |
| B2 | ENG staff / web; ACC staff / web | ENG creates a By type DV request routed to Accounting. ACC accepts with review notes. Ticket remains Accepted and custody remains ENG IN. | Pending |
| B3 | ENG staff / Android | Explicit OUT to BUD. The receiving office sees incoming; no BUD receipt exists yet. | Pending |
| B4 | BUD staff / web | Receive the actual packet with counts and confirmation; then explicitly OUT to ACC. Each action adds exactly one event. | Pending |
| B5 | ACC staff / Android, then web | Receive with counts. Link the exact accepted DV ticket using Accounting's handling evidence. Linking preserves acceptance and adds no movement. | Pending |
| B6 | ACC staff / Android | OUT to TRE with the reviewed custody state. | Pending |
| B7 | TRE staff / web | Receive with counts; verify this first Treasury receipt has not completed the nominal trail. OUT to MAY. | Pending |
| B8 | MAY staff / Android | Receive with counts, then OUT to TRE. | Pending |
| B9 | TRE staff / web | Receive with counts after Mayor receipt. Physical DV trail is complete; active processing/overdue queues reflect completion. Ticket remains Accepted. There is no separate explicit DV File step. | Pending |
| B10 | TRE participant / Android | In this synthetic scenario only, record **Payment released** on the accepted ticket with outcome notes. Expect Treasury actor/office/time, preserved Accounting review, and unchanged folder movements. This records the declaration; it executes no payment. | Pending |
| B11 | TRE staff / web; ACC staff / Android | Optional final return: explicitly send to ACC and receive there with counts. Final Accounting receipt completes the optional trail. Ordinary further forwarding from completed Treasury stays restricted by current completion rules. Record Not run if omitted. | Pending |

Nominal custody: **ENG IN → ENG OUT → BUD IN → BUD OUT → ACC IN → ACC OUT → TRE IN → TRE OUT → MAY IN → MAY OUT → TRE IN**, exactly **11 movements**, or **13** with B11. Acceptance, linking and payment release add no IN/OUT. Treasury normally records ticket release; the existing admin override remains a separate authority and is not permission for admin custody writes.

## Checks C — both clients and operational evidence

Run deliberate conflicts, network-loss tests and extra movements only in the isolated synthetic environment. Use a separate scratch folder when a check would change the expected A/B history above. Never remove pages from the main pilot packets merely to match an error fixture.

| ID | Check and expected outcome | Result / evidence |
|---|---|---|
| C1 | On web and Android, sign in as head and admin: registration/IN/OUT/filing controls remain unavailable; request, checklist, deadline/report authority retains its existing distinct scope. Check denial at the API in the technical rehearsal, without exposing credentials. | Pending |
| C2 | Reopen the folder on the other client after each saved handoff. Compare ID, sender/destination, receipt status, counted pages and full history. Record refresh delay; current clients poll about every 15 seconds, so do not assume instantaneous synchronization. | Pending |
| C3 | Scratch incoming packet: actual pages differ from its registered inventory. Confirm requires the complete discrepancy reason, and history on both clients retains actual versus registered counts and the full reason. Cancellation makes no write. | Pending |
| C4 | Scratch unreceived OUT: sending-office staff correct the destination with a reason and confirmation. History appends old/new destination evidence; original OUT ID/time/counts stay unchanged. Old destination cannot receive, new destination can; correction after receipt is rejected. | Pending |
| C5 | Review the same scratch action on two clients; save on one, then attempt the old reviewed action on the other. Stale evidence is rejected and no second handoff is silently recorded. Do not refresh/rebase the evidence during the old confirmation. | Pending |
| C6 | Simulate lost connectivity on a pilot client only. Initial read fails honestly; a failed refresh marks retained data stale. For an uncertain write, check the saved outcome before any explicit retry using the same saved operation. A read retry never repeats a confirmed write. Restore the temporary network override. | Pending |
| C7 | Compare full Folder history and Office activity with the exact A/B event sequences. Verify long purposes, review notes, closing notes, receipt evidence and destination corrections remain readable. Dashboard previews are not complete logs. | Pending |
| C8 | Head reviews its office Dashboard/Analytics. Accounting admin reviews municipal monitoring and exports a custody summary. Save/open the actual output on the intended platform and print a label/report; record layout and file location. Check filing time and terminal receipt semantics, not monetary totals. | Pending |
| C9 | Review a separately prepared, legitimately overdue synthetic ticket and a due-today ticket. Accepted unfulfilled work remains overdue; the due day is included. Do not change the device/server clock or backdate working records to manufacture this case. Automated date controls are separate evidence. | Pending |
| C10 | If recovery email is in pilot scope, use designated synthetic addresses and verify actual delivery plus manual code entry. Never copy reset codes/tokens to this report. Otherwise record Not run; automated checks do not establish delivery. | Pending |

No row above establishes a complete direct-folder visibility policy. Unrelated authenticated detail/history access remains broader than the confirmed own-office/requester use cases; settle permitted access/fields with the system owner before production acceptance. Occasional DV exceptions are confirmed, but exact exception authority/evidence and the Approved Budget route after Accounting remain open decisions. See [policy confirmations](../product/POLICY-CONFIRMATIONS-2026-10-16.md) and [PRD open decisions](../PRD.md#open-decisions-and-known-documentation-drift).

## Stop and recovery rules

Stop the affected scenario on a wrong office/identity/destination, unclear API target, unexpected missing/duplicate event, unavailable current custody, stale review evidence, unresolved write outcome, count mismatch without a reason, or a discrepancy between the physical packet and displayed state. Preserve the packet at its actual holder and record the last confirmed action.

Check an uncertain creation/movement using its saved outcome. Do not create a new operation ID, repeat a POST automatically, fabricate a receipt, erase a history row, alter timestamps or restore a database to make the story look complete. Only resume from a verified current state. Log the incident below with synthetic IDs and sanitized evidence.

| Incident | Scenario/step and client | Expected / observed | Last confirmed state | Impact / owner / resolution |
|---|---|---|---|---|
| None recorded yet | — | — | — | — |

## Acceptance and sign-off

A/B pass only when all required steps are performed on the assigned web/Android clients, exact movement sequences match, ticket and custody transitions remain independent, both clients show matching verified data, and all material defects have been resolved and retested. B11 is optional and must be labelled if not run. C checks require their own outcomes; a skipped device/export/network check stays unverified.

The facilitator records one decision: **Passed**, **Passed with explicitly listed limitations**, **Failed**, or **Blocked**. Record which scenario/client a limitation affects. Unresolved custody integrity, duplicate writes, wrong-identity actions or required-role access failures prevent a pass. Broader production release also needs the intended hosting/security, operational recovery, realistic load and visibility-policy acceptance; this runbook does not silently waive those gates.

| Sign-off | Participant initials / date | Decision and evidence |
|---|---|---|
| ENG staff | Unassigned | Pending |
| HR staff | Unassigned | Pending |
| BUD staff | Unassigned | Pending |
| ACC staff | Unassigned | Pending |
| TRE staff | Unassigned | Pending |
| MAY staff | Unassigned | Pending |
| Office head | Unassigned | Pending |
| Accounting administrator | Unassigned | Pending |
| Facilitator / project owner | Unassigned | Pending |

## Safe local technical rehearsal

From the project root, after confirming the reviewed local MariaDB host:

```powershell
$env:TEST_DB_HOST = '127.0.0.2'
& C:\xampp\php\php.exe scripts/test-office-pilot.php
```

This new focused runner uses the existing private-file-free [test fixture](../../scripts/stabilization-test-helper.php), generated guarded disposable schema, synthetic identities and actual copied endpoints. It never selects the operational database or uses operational keys/uploads. It stops its own PHP server and removes its exact owned schema/temp copy in cleanup. It does not start/stop MariaDB, provision a persistent staging deployment or exercise real UI/hardware.

For representative web interactions, use the existing [safe browser fixture](../TESTING.md#safe-browser-review-fixture). Its Accounting identity and in-memory data cannot stand in for the shared six-office pilot. Focused web/Flutter tests use mocks and are separately reported. See [Testing](../TESTING.md) for commands and isolation rules.
