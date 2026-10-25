# Working policy confirmations — 16 October 2026

Source: the project user's answers in the SmartFlow conversation. These are user-confirmed working requirements, not a claim of a new client interview, client UAT or production acceptance. Preserve the original client questionnaire answers as historical evidence.

## Confirmed rules and current implementation

| Topic | User confirmation | Current implementation / boundary |
|---|---|---|
| Physical registration | Yes: the office physically holding the folder registers it. | Matches staff-only registration at the caller's assigned office. A request or lookup does not establish physical custody. |
| Visibility | Yes: staff primarily monitor their own office; requesters see status/location of related folders; Accounting Head has municipal oversight. | Office queues and municipal oversight support these use cases. The Accounting Head is represented by an Accounting administrator; an ordinary head role remains office-scoped. Direct detail/history lookup is broader and is not proven compliant with a restrictive interpretation of this rule. |
| Payment-release recording | Explicitly clarified: Treasury normally records release; admin override is permitted. | Matches the existing accepted-DV Treasury-or-admin completion rule. Acceptance/linking and physical custody remain separate. The recorded event does not execute payment or approve the DV financially. |
| DV route | Exceptions occur “minsan.” | Keep the usual ENG → BUD → ACC → TRE → MAY → TRE route and optional final Accounting return as guidance. Do not introduce mandatory intermediate-stage blocking merely from the nominal route. Existing sender/receiver, stale-movement, return and completed-trail rules remain mandatory. |

## Details not established by these answers

- The role-level visibility confirmation does not establish which fields or complete history may be disclosed on direct lookup of an unrelated folder, or approve unrestricted enumeration. `documents-show.php` and `documents-movements.php` currently require authentication without a matching office/request relationship check. Keep this implementation discrepancy visible; do not report the entire access matrix as enforced.
- Occasional routing exceptions do not define every permitted skip/backtrack, approving actor or reason/evidence requirement. Do not invent an exception approval flow, fabricate custody events or remove completion safeguards. The present guidance-based behavior can remain while examples are collected during workflow review.
- This confirmation resolves the working holder-office rule despite conflicting older Budget/Engineering questionnaire answers. It does not decide the separate Approved Budget return route after Accounting.

## Source comparison

- [Registration](../../backend/backend/api/documents-create.php) and [movement authority](../../backend/backend/api/movements-helper.php).
- [Office scope](../../backend/backend/api/office-access-helper.php), [office queues](../../backend/backend/api/office-documents.php), [direct details](../../backend/backend/api/documents-show.php) and [direct history](../../backend/backend/api/documents-movements.php).
- [Request completion](../../backend/backend/api/document-requests-update.php) and [routing/completion helpers](../../backend/backend/api/routing-helper.php).
- [Product requirements](../PRD.md), [security context](../SECURITY.md) and [original client summary](../client/CLIENT-DISCOVERY-RESPONSES-SUMMARY.md).

This pass records the decisions and compares source. No executable code, permissions, records or deployment changed; no fresh runtime tests are claimed.
