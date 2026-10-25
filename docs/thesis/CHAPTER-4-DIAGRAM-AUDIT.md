# Chapter 4 Diagram Audit

Reviewed against the client-validated workflow, current Flutter and React clients, PHP API, runtime schema, and accepted role model on 30 September 2026.

## Audit Summary

| Section / Figure | Status | Required Action |
|---|---|---|
| Figure 1.0 - Waterfall SDLC | Retain with minor revision | Keep the figure. Ensure the phases are Requirements, Design, Development, Testing, Deployment, and Maintenance. Remove wording implying iterative sprints. |
| Figure 1.1 - DFD Level 0 | Revised | Use the latest black-and-white context diagram. Update the narrative to match its four external entities and one SmartFlow process. |
| Figure 1.2 - Use Case Diagram | Replace | The embedded figure uses obsolete actors: Accounting, System Admin, and COA Auditor. Replace it with the implementation-based three-role use case diagram. |
| Figure 1.3 - DFD Level 1 | Replace | The embedded figure uses old clerks, approval processes, QR Codes, Transactions, and Scan Logs. Replace it with the current Level 1 DFD. |
| Figure 1.4 - ERD | Regenerate from final schema | Do not finalize until the deployed MySQL `CREATE TABLE` export is confirmed. Use exact table and column names only. |
| Figure 1.5 - Software Architecture | Replace | The figure shows only four departments, an Internet-centered connection, web-only QR generation, real-time monitoring, and PDF/Excel output. Replace with the current three-tier hybrid architecture. |
| Figure 1.6 - Employee Flowchart | Replace | The embedded flowchart is unreadable and uses a generic employee workflow. Replace with the detailed Staff / Clerk flowchart. |
| Figure 1.7 - Department Head Flowchart | Replace | Remove “4 Department Heads” and document approval. Heads process Document Requests and monitor their assigned office; they do not approve financial documents. |
| Figure 1.8 - System Admin Flowchart | Replace | Replace with the Municipal Accountant / Admin workflow and keep authentication in the separate authentication/access flow. |

## Available Replacement Figures

- `thesis-work/2026-09-29_SmartFlow-Figures/Figure_1.2_DFD_Level_0_Context_Diagram.png`
- `thesis-work/2026-09-29_SmartFlow-Figures/Figure_1.2_Use_Case_Diagram_Updated.png`
- `thesis-work/2026-09-29_SmartFlow-Figures/Figure_1.3_DFD_Level_1_Updated.png`
- `thesis-work/2026-09-29_SmartFlow-Figures/Detailed_Staff_Clerk_Flowchart.png`
- `thesis-work/2026-09-29_SmartFlow-Figures/Detailed_Department_Head_Flowchart.png`
- `thesis-work/2026-09-29_SmartFlow-Figures/Detailed_Municipal_Accountant_Admin_Flowchart.png`

## Narrative Corrections

### Section 4.3.1

- A Level 0 context diagram has one process and no internal data stores.
- Remove the sentence claiming that Level 1 has eight stores unless the final accepted Level 1 figure actually has eight.
- Match the external entities and flow labels exactly to the accepted Figure 1.1.
- Do not repeat two near-identical context-diagram explanations.

### Section 4.3.2

- Use only the application roles `staff`, `head`, and `admin` as internal actors.
- COA is not an internal user and does not log in to SmartFlow.
- Include signup approval, password recovery, registration, signed QR printing, scanning, history, requests, alerts, analytics, thresholds, offices, users, QR monitoring, audit exceptions, and reports.
- Replace “verify compliance” with “review custody records and COA-oriented support summaries.”
- Replace “scan logs” with “movements” or “scan audit activity,” depending on context.

### Section 4.3.3

- Decide whether the section contains a DFD Level 1 or an Activity Diagram. Do not caption it as a DFD and describe it as an Activity Diagram.
- If using the current replacement, call it a DFD Level 1 and describe data flows, processes, entities, and stores.
- Remove approval committee, financial approval, generic Transactions, QR Codes, and Scan Logs elements.

### Sections 4.3.4-4.3.5

- Confirm the final MySQL export before stating the number of tables.
- Keep `users`, not `user_accounts`, and `movements`, not `scan_logs`.
- Keep `qr_tokens` only if it exists in the final deployed schema.
- Section 4.3.5 is titled Data Dictionary but currently contains the Software Architecture figure. Add the actual data dictionary or rename/restructure the section.

### Figures 1.6-1.8

- Staff / Clerk: register only when physically holding the folder; otherwise create a Document Request; scan IN/OUT; return with a reason; view history and alerts.
- Department Head: inherits authorized office operations and monitors office queues, requests, delays, and analytics. Approval/rejection applies to Document Requests, not financial documents.
- Municipal Accountant / Admin: review signups; manage users, offices, and thresholds; monitor municipality-wide custody and audit exceptions; generate authorized COA-oriented reports.
- Treasury and Mayor are offices whose users have `staff` or `head` roles, not separate application roles.

## Formatting Problems

- The role flowcharts are too small to read at manuscript size.
- Several captions and paragraphs retain red revision highlighting.
- Figure numbering uses `Figure 1.x` inside Chapter 4. Confirm whether the school template requires `Figure 4.x` or continuous numbering, then apply one convention consistently.
- Captions should identify the figure without repeating long explanations already provided in the body text.
