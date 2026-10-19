# SmartFlow bounded stabilization matrix

Frozen scope: **16 October 2026**, authorized by the project user after the workflow follow-up. Feature/design changes are frozen for this pass. This is a release decision aid, not a claim of production or client UAT acceptance.

Implementation gate: **all rows passed**. Fresh full suites: **547 isolated API / 93 web / 243 Flutter**, with clean final Flutter analysis and web/debug-APK builds. Dedicated boundary, backup/restore and both-shell launch results are in the [implementation report](../../.runtime/stabilization-2026-10-16/report.md). No APK install or live account/session action occurred in this pass.

The nine workflow findings and three earlier open groups are the implementation boundary. Existing product authority, custody and request invariants remain unchanged. Newly observed cases enter this pass only when they are a bypass or regression of these fixes.

| Boundary / scenario | Required outcome | Permanent check / evidence | Status |
|---|---|---|---|
| WF-01 queued admin decision; deactivation/logout/expiry during wait | No business write after completed revocation; active-admin control and rollback preserved | Admin session boundary fixture; existing admin-status concurrency suite | Passed; see current implementation report |
| Earlier linked-ticket purpose disclosure | Folder-linked ticket fields obey the union of existing Requests inbox/outbox/admin scope; preserve requester/handler/Treasury evidence | Linked-ticket scope fixture; full API request/custody harness | Passed; see current implementation report |
| Earlier abandoned native login / late failure | Only intended live login attempt applies/persists; late errors do not update disposed UI | Native login lifecycle/staged-persistence tests and session/profile regressions | Passed; see current implementation report |
| Existing-login consequence: old modal / replacement login | Prior confirmation cannot dispatch under replacement session; same-token profile updates preserve workspace; already-dispatched outcomes settle through failed logout | Actual native router/receipt/correction, nested modal, pre-frame and pending-logout regressions | Passed; see current implementation report |
| WF-02 native handoff then Back | Late success/rejection is lifecycle safe, exactly one POST, recovery preserved | Native Scan navigation and retained success-action regressions | Passed; see current implementation report |
| Earlier repeated web camera decode | One reviewed camera lookup cannot unmount an active correction form; explicit next scan remains usable | Actual-page mocked scanner callback regression | Passed; see current implementation report |
| WF-03 report with concurrent custody commit | Denominator, classifications and office totals share one snapshot in JSON/CSV | Report snapshot fixture; existing period/export/error controls | Passed; see current implementation report |
| WF-04 backup with overlapping save/delete | Manifest and continuity evidence describe the actual SQL dump | Actual synthetic backup/restore suite | Passed; see current implementation report |
| WF-07 initialized system with no folders | Restore verifies data/schema/key/uploads and labels original-folder QR not applicable | Actual empty/populated/wrong-key/N/A controls | Passed; see current implementation report |
| WF-05 launch helpers on Windows PowerShell 5.1 and 7 | Both parse and mocked success/failure paths execute correctly | Launch helper suite in both installed shells | Passed; see current implementation report |
| WF-06 legacy restore | Script parses and preserves Unicode/binary SQL bytes on both shells; failed import remains a failure | Synthetic legacy restore suite | Passed; see current implementation report |
| WF-08 Manila month boundary | Head Analytics defaults to the local month, including 00:00 on the first day | Frozen-clock web regression | Passed; see current implementation report |
| WF-09 previous native exit code | Reachability helper result governs launch; unrelated prior exit does not abort success | Mocked defense launcher regression | Passed; see current implementation report |
| Core role/custody/request controls | Staff-only custody, head/admin monitoring, receipts/counts, expected IDs, correction evidence, creation replay, full history, DV release authority remain intact | Full isolated API, web and Flutter suites | Passed: 547 API / 93 web / 243 Flutter |
| Private local launch / code-only deployment tooling | Maintenance/private routes denied; sync does not copy runtime private files or mutate records | Existing developer-security/router/code-sync suites | Passed; see current implementation report |

## Verification environment

Mutation tests must create/select/drop only their own generated disposable schemas, using synthetic accounts/files and private-file-free endpoint copies. An address on the loopback network does not prove that a separate empty server is running: inspect ownership before claiming or stopping one. This pass uses the existing local MariaDB for disposable schemas and does not start/stop that service or select the operational database.

Run the full suite once after the scoped changes and focused regressions pass. Repeat or broaden only for a new change, failure or concrete unresolved concern. Preserve exact outputs and distinguish defect-discovery history from current passing regressions. No automatic retry may create another physical action or creation operation.

## Separate release acceptance

Protected device visuals, camera hardware, actual file-save/printing, email delivery, production HTTPS/proxy/header forwarding, hosting/database compatibility, concurrent-load frequency and client UAT require their own environment evidence. Builds/widget tests do not close these items. The dynamic phone HTTP host versus Android allowlist risk remains an unexercised deployment item.

Broader direct unrelated-folder detail/history access and mandatory DV stage/exception policy remain outside the accepted implementation boundary. Fixing linked-ticket field scope does not establish that the broader visibility decision is closed.
