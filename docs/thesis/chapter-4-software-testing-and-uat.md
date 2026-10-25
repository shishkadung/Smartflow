# 4.4 Software Testing Plan

This section describes the testing plan for verifying SmartFlow against Functional Requirements FR-1 through FR-7. It follows the testing phase of the Waterfall development approach discussed in Section 4.1 and covers the implemented React web portal, Flutter Android application, shared PHP API running on Apache, and MySQL-compatible database. Testing addresses physical folder registration and custody, formal requests, monitoring, alerts, analytics, and custody reports for Engineering, Human Resources, Budget, Accounting, Treasury, and the Mayor's Office.

SmartFlow has received school system-check approval. This approval is recorded separately from client User Acceptance Testing (UAT), ISO/IEC 25010:2023 questionnaire responses, and any subsequent LGU acceptance. The procedures below define the testing and evaluation activities; completed outcomes will be supported by dated test records and actual participant responses. Planned client evaluation is not presented as completed UAT.

Testing is organized into unit, integration, system, and acceptance levels. Defects are documented, corrected, and retested at the affected level, followed by relevant regression checks. Each test record identifies the build, environment, test case, input, expected result, actual result, outcome, and supporting evidence. Internal automated checks, researcher demonstrations, and client evaluation results are reported separately.

| Test level | Purpose | Primary focus |
| --- | --- | --- |
| Unit testing | Check isolated logic and components using controlled inputs | Input validation, QR parsing, session state, movement guards, date rules, and recovery behavior |
| Integration testing | Check communication and consistency across connected components | React or Flutter, PHP authorization, database transactions, and response handling |
| System testing | Check complete workflows against FR-1 through FR-7 | Role-specific scenarios, custody history, requests, alerts, reports, and failure recovery |
| User Acceptance Testing | Evaluate how intended LGU users perform relevant tasks and assess applicable quality criteria | Guided orientation, role-specific tasks, observed outcomes, feedback, and the finalized questionnaire |

*Table 4.2 Overview of the SmartFlow Software Testing Plan*

Mutating test cases will use synthetic records in an isolated test database or demonstration environment. The operational database, real accounts, and existing sessions will be preserved. A browser fixture can support interface review, but it does not establish that the real API and database integrations have passed. Actual device, network, browser, and hosting coverage will be stated in the test records rather than assumed.

## 4.4.1 Unit Testing

Unit testing checks individual functions, validation rules, and client components with controlled inputs or mocked dependencies. Cases that require a real PHP endpoint and database transaction are classified as integration tests. This distinction prevents an entire registration or handoff transaction from being reported as an isolated unit test.

### Objectives

1. Check validation and client session behavior for valid, invalid, expired, or changed login contexts.
2. Check document fields, tracking and QR parsing, and feedback for incomplete or invalid inputs.
3. Check role, movement-state, destination, and confirmation guards before a custody action is submitted.
4. Check date boundaries, threshold comparisons, and presentation of unavailable, empty, or stale data.
5. Check contents validation and recovery behavior after an uncertain creation or movement response.

### Scope of Unit Testing

| Unit or component | Controlled inputs | Expected result |
| --- | --- | --- |
| Authentication and session state | Valid and invalid form values; mocked expired or replaced sessions | Clear validation; protected state remains associated with the correct login |
| Registration validation | DV or Approved Budget fields; missing required values; invalid contents | Required fields and physical-count confirmation are enforced before submission |
| Tracking and QR parser | Supported signed payload; malformed input; unsupported content | Valid input is parsed; invalid input produces an understandable message |
| Movement controls | Role, latest custody, destination, return reason, and receipt-confirmation states | Only permitted actions can be submitted; cancelled confirmation submits nothing |
| Deadline and threshold logic | Date-only due dates; processing and receipt limits; completed or filed states | Boundary conditions and the applicable type of delay are distinguished |
| Read-state feedback | Successful empty response; initial failure; failed refresh | Verified empty results remain distinct from unavailable or retained stale data |
| Recovery state | Saved operation ID; timeout; delayed result; changed login | Uncertain outcomes are checked without creating a fresh operation automatically |

*Table 4.3 Unit Testing Scope for SmartFlow*

### Method and Tools

The researchers will use the existing JavaScript test tooling and Flutter/Dart tests to check isolated logic, components, and screens with controlled responses. PHP helper logic that can be isolated will be checked using deterministic inputs. Fixtures will represent valid cases, rejected inputs, boundary conditions, and delayed responses. Mocked success will not be treated as evidence of a successful database write.

### Sample Unit Test Cases

| ID | Test case | Input or condition | Pass criteria |
| --- | --- | --- | --- |
| UT-01 | Login form validation | Missing username or password | Required-field feedback appears before submission |
| UT-02 | Login-context guard | A response arrives after the reviewed login changes | The old response does not replace the new user's state |
| UT-03 | Registration validation | Required DV or Approved Budget fields are missing | Submission is blocked with field-specific guidance |
| UT-04 | Invalid QR parsing | Malformed or unsupported payload | No custody action is recorded; readable feedback appears |
| UT-05 | Custody-action guards | Wrong role, wrong custody state, or missing destination | The action remains unavailable or invalid |
| UT-06 | Cancelled receipt confirmation | User dismisses the physical-receipt dialog | No movement request is submitted |
| UT-07 | Date and read-state boundaries | Due-day boundary or failed data read | Deadline behavior is correct; failure is not shown as a verified zero |
| UT-08 | Contents validation | Missing required counts or discrepancy explanation | Invalid receipt or registration contents are rejected |
| UT-09 | Uncertain-operation recovery | Timeout with an existing saved operation ID | Recovery retains the operation identity and prevents an automatic duplicate creation |

*Table 4.4 Sample Unit Test Cases*

### Acceptance Criteria for Unit Testing

Unit-level results are acceptable when the selected normal, negative, and boundary cases produce their expected outcomes and identified critical or high-severity defects have been corrected and retested. Test reports will state the cases executed and their actual results. A planned case will not be reported as passed before execution.

## 4.4.2 Integration Testing

Integration testing checks the interaction of the web or Android client, PHP API, and database. It verifies server authorization, transaction consistency, and how clients handle successful, rejected, stale, or uncertain responses.

### Objectives

1. Verify staff registration, generation of a unique document ID and signed QR label, and the initial IN custody record.
2. Verify confirmed OUT and subsequent destination IN events and their appearance in location and history views.
3. Verify that request acceptance and folder linking remain separate from physical custody and payment-release recording.
4. Verify office-scoped listings and role-specific actions at both client and API boundaries.
5. Verify alerts, report calculations, export authority, and recovery using known sample records.

### Integration Scenarios

| ID | Integrated path | Verification |
| --- | --- | --- |
| IT-01 | Web or Android login, PHP authentication, and database session | The correct role and office are returned; invalid or inactive accounts are denied |
| IT-02 | Holding-office staff registration, database transaction, and QR label | One folder and initial IN are created; the unique ID and signed QR resolve to the same folder |
| IT-03 | Staff OUT, destination IN, and refreshed monitoring/history | The destination, actor, timestamp, and current custody agree across permitted views |
| IT-04 | Receive confirmation and counted contents | Actual receipt counts and discrepancy notes are saved; cancellation or rejection leaves custody unchanged |
| IT-05 | Request creation, acceptance, linking, and closing | Ticket transitions follow displayed status/revision guards and do not create IN or OUT events |
| IT-06 | Accepted DV ticket and payment-release action | Treasury can record payment release under the existing rule; administrator override and unauthorized-role rejection are checked |
| IT-07 | Latest custody, configured limits, and alert response | Processing, unconfirmed receipt, and explicit deadlines follow their applicable rules |
| IT-08 | Period summary, known records, and authorized export | Counts reconcile with expected records; CSV and printable output preserve period and scope |
| IT-09 | Timeout, duplicate submission, stale state, or changed login | No duplicate custody event or creation is introduced; saved outcomes can be reconciled |

*Table 4.5 Integration Test Scenarios*

### Method

Tests will run against an isolated database containing known sample folders, users, offices, requests, and movements. Real endpoint responses and transaction outcomes will be compared with predetermined expected results. Browser and Android checks will identify the actual client, device or emulator, API address, and network used. Communication failures will be simulated without modifying the municipality's operational records.

Registration already records the folder's initial IN at the registering office. A later receipt test therefore requires a preceding OUT to the receiving office. QR or ID lookup alone must not record a handoff. Rejected actions must leave custody unchanged, although a rejection may produce a separate audit entry.

Alert checks will compare the returned overdue results with latest custody, configured office/type processing and receipt limits, and explicit deadlines. The current alert endpoints calculate results when queried; testing will not assume that each alert is stored as a separate notification record or delivered through an external channel.

Custody-report checks will reconcile distinct folders with movement during the selected month, quarter, or year and distinct folders handled per office. Office counts may overlap when the same folder visits several offices. The summary currently uses a 72-hour OUT-to-IN classification, separately from configurable alert limits. Its existing On time category can include IN-only folders, while Unforwarded refers to an OUT awaiting receipt. These definitions must be documented and clarified with the client; they do not establish completed work, payment release, or financial compliance. Folders without movement during the selected period are not included in that activity total.

Exports will be checked as CSV and printable summaries, including Print or Save as PDF through the client. The test plan does not assume a native Excel workbook or a financial journal export. Municipal report preview is administrator-only, while supported exports require an Accounting administrator. Analytics timing checks will be documented separately from custody-summary percentages.

### Acceptance Criteria for Integration Testing

Integration results are acceptable when the executed transactions preserve authorization and data consistency, displayed results match the recorded outcomes, and rejected or uncertain operations do not create duplicate or unauthorized writes. Failures will be corrected and retested, with the relevant regression cases repeated. Device and hosting combinations not exercised will remain identified as unverified.

## 4.4.3 System Testing

System testing checks the complete application against FR-1 through FR-7 using scenarios that reflect the six-office scope. It covers normal use, invalid actions, incomplete recording, and service failures. Each test will have an expected result that can be observed or reconciled with the isolated records.

### Objectives

1. Demonstrate the implemented functions associated with FR-1 through FR-7.
2. Verify the distinction between a request ticket, physical custody, filing or route completion, and recorded payment release.
3. Verify role-specific tasks, feedback, complete history, and recovery under failure conditions.
4. Assess readiness for structured client evaluation without treating school approval as a completed client acceptance result.

### Mapping of System Tests to Functional Requirements

| FR | Requirement summary | System test focus |
| --- | --- | --- |
| FR-1 | Register held physical folders and generate a unique ID and signed QR | Staff authority, holder-office fields, contents, and label usability |
| FR-2 | Record physical handoffs and custody history | Confirmed IN/OUT, actor, office, time, destination, receipt evidence, and duplicate/stale guards |
| FR-3 | Show folder location, current work, and status | Office and municipal monitoring; clear unavailable, empty, and stale states |
| FR-4 | Identify overdue processing, pending receipts, and explicit deadlines | Applicable limits, due-day handling, and eligible completed/filed suppression |
| FR-5 | Provide custody summaries and authorized exports | Period activity counts, office totals, classification definitions, CSV, and print output |
| FR-6 | Support office processing and bottleneck analysis | Recorded processing time, delayed work, period selection, and applicable final filing evidence |
| FR-7 | Support structured user acceptance and quality evaluation | Usable role-specific tasks, evaluation records, and the selected ISO/IEC 25010:2023 criteria |

*Table 4.6 System Testing Mapped to FR-1 through FR-7*

### Sample System Test Cases

| ID | Scenario | Expected system behavior |
| --- | --- | --- |
| ST-01 | DV route through ENG, BUD, ACC, TRE, MAY, and TRE, with optional final ACC return | Confirmed handoffs preserve the trail; route/custody completion remains separate from the ticket's payment-release action |
| ST-02 | Request for a folder held by another office | Required date and purpose are saved; acceptance/linking does not register or move the folder; holder-office registration remains applicable |
| ST-03 | Approved Budget from BUD to ACC | Authorized staff registration and handoffs appear in permitted monitoring and history views |
| ST-04 | OUT awaiting receipt or attempted unsupported handoff | The latest recorded state is shown honestly; wrong-destination receipt or forwarding without custody is rejected |
| ST-05 | Duplicate or stale movement | The second conflicting action is rejected or reconciled without a duplicate event |
| ST-06 | Processing, receipt, and manual deadline cases | The correct type of overdue status appears; date-only deadlines include the due day |
| ST-07 | Custody summary and export for a known period | Counts match expected activity; exports enforce Accounting-administrator authority and retain custody-support scope |
| ST-08 | Staff, head, and administrator permissions | Staff perform physical registration/IN/OUT/filing; heads and administrators retain their separate monitoring, request, checklist, and management authority |
| ST-09 | Missing read, failed refresh, or uncertain write | Errors and retry/recovery remain usable; unknown data are not shown as fresh zeros or silently resubmitted |
| ST-10 | Complete history and recorded filing | Relevant full movement history, receipt evidence, reasons, and explicit filing records remain available; computed completion does not invent filing |

*Table 4.7 Sample System Test Cases*

The DV path is tested as the usual workflow and as route guidance. Existing custody and completion guards will be preserved without inventing strict stage enforcement. A route-gap flag is a review cue rather than proof that an authorized exception is invalid. Similarly, a missing human scan is a recording limitation; it does not justify marking a failed required system behavior as passed.

Access tests will identify the endpoint and permitted view being exercised. Office-scoped lists and role-restricted writes will be verified separately from direct folder detail/history lookup, whose broader unrelated-folder visibility remains a policy detail. The report will not claim that every direct lookup is restricted to the caller's office.

### Alpha Review and Defect Handling

Researcher checks and the completed school system review will be documented using their actual records. Any additional adviser observation will identify its date, scope, and findings. Defects will be classified by severity and assigned a correction and retest record. School system approval will not be presented as proof that every device, hosting environment, or client workflow has already passed.

### Acceptance Criteria for System Testing

System testing is acceptable when the required executed scenarios meet their expected outcomes, critical and high-severity defects affecting those scenarios are resolved and retested, and the evaluation build is stable enough for the planned client tasks. Each case will be recorded as Pass, Fail, Blocked, or Not Applicable, with a reason where needed. An unmet requirement will remain a failure rather than being reclassified as a limitation merely to obtain a pass.

# 4.5 User Acceptance Testing and Evaluation

This section presents the planned client UAT and quality-evaluation procedure for SmartFlow. Functional UAT will examine whether intended users can perform relevant office tasks. A separate questionnaire will collect perceptions of the applicable quality characteristics selected from ISO/IEC 25010:2023. Task completion, system-generated activity measures, and questionnaire ratings will be reported as distinct forms of evidence.

The school system-check approval is already recorded. The final instrument, participant plan, and evaluation procedure will be coordinated with the adviser using the school's prescribed testing guide and coordinator instructions. The existing approval and any required survey clearance will be documented before questionnaire administration. This procedure does not imply that the survey, client acceptance, or deployment has already occurred.

## 4.5.1 Purpose of UAT

1. Determine whether intended users can complete their relevant tasks after a standard orientation, while recording any assistance required.
2. Confirm whether folder location, custody history, requests, alerts, and reports match the users' operational needs.
3. Collect structured feedback using the selected ISO/IEC 25010:2023 characteristics and subcharacteristics.
4. Document client observations, requested corrections, and the acceptance decision of the Municipal Accountant or designated LGU representative using the agreed procedure.

## 4.5.2 Participants and Setting

Participants will be drawn from the offices and roles relevant to the six-department scope. The final number, selection method, role distribution, and inclusion criteria will be established with the adviser and recorded in the evaluation protocol. Representation across the six offices will be proposed; the study will not assume that all employees must answer or that any particular sample size has already been approved.

| Participant role | Relevant evaluation activities |
| --- | --- |
| Frontline staff or clerks | Register folders already held by their office; perform confirmed receive/forward actions; inspect contents and history; use requests |
| Department heads | Review office dashboard, queue, alerts, analytics, and their permitted request or checklist actions |
| Municipal Accountant using the Accounting administrator role | Review municipal monitoring, custody reports, audit exceptions, and authorized exports |
| Designated system administrator | Review applicable account, office, threshold, and system-management functions |

*Table 4.8 Proposed UAT Participant Roles*

The Municipal Accountant's administrator role does not authorize physical registration or IN/OUT actions. Those tasks will use staff accounts from the relevant holding or sending/receiving office. A participant with more than one responsibility will be identified by the role used for each task.

Sessions may be arranged by office or role so that participants do not need to attend simultaneously. The actual location, date, build, devices, browsers, network, and mode of participation will be recorded. Any remote demonstration or alternative arrangement will follow the agreed evaluation procedure and be reported accurately. The study will not claim municipal-LAN deployment or hands-on Android use where only a demonstration occurred.

Participants will receive an explanation of the study and the voluntary nature of their participation. Responses and identifying information will be handled confidentially. If names, office details, or signatures are collected, the study will describe those measures without claiming complete anonymity. Demonstration tasks will use isolated sample records rather than fictitious actions in operational custody data.

## 4.5.3 UAT Task Script

The researchers will provide a standard orientation and assign tasks according to each participant's actual role. Participants will evaluate the features they have used or meaningfully observed. Assistance, incomplete tasks, errors, and suggested improvements will be recorded without directing participants toward favorable ratings.

| Step | Task | Actor | Expected observable outcome |
| --- | --- | --- | --- |
| 1 | Sign in with an assigned demonstration account | All participating roles | The correct office and role workspace opens |
| 2 | Register a sample DV or Approved Budget already held by the office | Authorized holding-office staff | Required fields and contents are checked; one folder, initial IN, tracking ID, and signed QR are created |
| 3 | Look up the registered folder using QR or ID | Permitted users | The correct folder opens without recording another handoff |
| 4 | Confirm forwarding to another office | Sending-office staff with current custody | One OUT records the reviewed destination; cancellation records nothing |
| 5 | Confirm physical receipt and actual contents | Staff of the addressed receiving office | One IN records receipt counts and any required discrepancy explanation |
| 6 | Create or review a formal request and its linked folder | Requester or permitted handler | Date, purpose, notes, and linked-folder context remain available; ticket decisions do not move the folder |
| 7 | Review current location, full history, and office work | Staff, head, or administrator according to access | Recorded custody, receipt evidence, and monitoring data agree |
| 8 | Review prepared overdue examples | Relevant staff, head, or administrator | Processing delay, pending receipt, and explicit deadline status are understandable |
| 9 | Review a known period's custody report and export it | Accounting administrator for export | Counts reconcile with expected sample records; CSV or printable output opens with the correct scope |
| 10 | Use a prepared, accepted DV request satisfying existing guards to record simulated payment release | Treasury user or administrator under the existing rule | The ticket outcome is recorded separately from custody, filing, and financial approval |
| 11 | Review applicable management or account functions | Authorized participant | Relevant controls and messages are understandable; changes use demonstration data only |
| 12 | Sign out | All participating roles | The presented session ends and protected functions require sign-in |

*Table 4.9 Structured UAT Task Script*

The task sequence will use known sample data and respect custody prerequisites; participants will complete only applicable steps. Functional task results will identify Pass, Fail, Blocked, or Not Applicable and record the reason, assistance, and observed errors. Time on task will be recorded only where included in the agreed procedure. A critical failure will be corrected and retested before acceptance is recommended.

## 4.5.4 Evaluation Instrument and Analysis

The study will use a researcher-prepared or adapted questionnaire informed by selected characteristics and subcharacteristics of the ISO/IEC 25010:2023 product quality model. ISO/IEC 25010:2023 defines nine product quality characteristics: functional suitability, performance efficiency, compatibility, interaction capability, reliability, security, maintainability, flexibility, and safety (ISO/IEC, 2023). These names replace the earlier eight-characteristic structure in the draft; listing the model does not mean that all nine have already been selected for this study.

The adviser consultation will establish the applicable criteria, item wording, respondent groups, scale, and analysis procedure using the school's prescribed guide. The mapping between each selected characteristic, its subcharacteristics, questionnaire items, and supporting tasks or tests will be retained with the instrument. The questionnaire will not be described as an ISO-issued or already validated instrument merely because it references the standard.

Questions will be assigned to respondents who can reasonably assess them. Technical criteria, such as maintainability or security mechanisms that cannot be established from ordinary screen use, will be supported by documented technical checks or appropriately qualified evaluators as required by the agreed plan. End-user impressions will not be presented as proof that a technical control is effective.

The draft response scale is five points: 5 = Strongly Agree, 4 = Agree, 3 = Neutral, 2 = Disagree, and 1 = Strongly Disagree. The final labels and any Not Applicable option will follow the finalized instrument. Missing or inapplicable answers will not be scored as zero. Valid response counts will be reported for the items analyzed.

For an item summarized using the frequency-weighted mean, the computation is:

WM = sum(f_k x s_k) / sum(f_k)

where f_k is the number of valid responses at score s_k and s_k is the numerical scale value. The denominator is the total number of valid responses to that item. Frequencies and percentages will also describe the response distribution. Characteristic-level and overall aggregation will follow the analysis plan established with the adviser, with any weighting stated explicitly.

Verbal interpretation ranges and any acceptance threshold will be established before analysis under the school's evaluation procedure. They will not be invented after viewing results or attributed to ISO/IEC 25010:2023 without support. The final instrument and scoring method will appear in the Appendices and match the method used in Chapter 5.

System-generated figures, such as activity counts, office processing times, and custody classifications, may supplement the discussion where actually measured. They will retain their definitions, period, and limitations and will not be substituted for missing questionnaire responses or described as a financial completion rate.

## 4.5.5 Acceptance Criteria and Sign-Off

The following criteria will guide the UAT outcome and the acceptance recommendation:

1. Applicable core tasks in Table 4.9 have been performed and documented by the relevant participant roles.
2. Required functions remain demonstrable, and critical defects affecting the evaluated workflows have been resolved and retested.
3. Valid questionnaire responses have been collected under the finalized procedure and summarized using the agreed analysis method.
4. Remaining limitations, failed or blocked cases, participant suggestions, and unresolved policy details are disclosed in the evaluation record.
5. The Municipal Accountant or designated LGU representative's acceptance decision and conditions are recorded through the agreed school/client procedure, including a sign-off form where required.

School system approval, a positive survey mean, and LGU acceptance will be recorded separately. No signature, acceptance decision, or completed response will be inferred from a demonstration or from the names printed on a form.

## 4.5.6 Transition to Results

Chapter 5 will present actual implementation screenshots, executed test results, participant information appropriate to the study, and the ISO/IEC 25010:2023 evaluation findings after data collection. It will identify the evaluated build, sample, dates, tasks, response counts, calculations, and limitations. Until the client evaluation is completed, this section remains a procedure for the planned activity and does not claim that SmartFlow has already been accepted for daily municipal use.

### Reference

International Organization for Standardization and International Electrotechnical Commission. (2023). ISO/IEC 25010:2023: Systems and software engineering — Systems and software Quality Requirements and Evaluation (SQuaRE) — Product quality model. https://www.iso.org/standard/78176.html

---

## Historical manuscript review notes

The notes below preserve an earlier PDF review and are not part of the updated Sections 4.4 and 4.5. Their historical wording does not establish completed UAT, deployment, current survey criteria, or permission to invent results. The ready-to-copy excerpt is maintained in files/SmartFlow_Sections_4_4_and_4_5_Updated.md.

## Capstone 2 manuscript checklist — findings from `new ver_SmartFlow_Capstone2.docx.pdf`

Working notes for the team after reviewing the Capstone 2 PDF against the **live** SmartFlow stack (`web/` React, `mobile/flutter/`, `backend/backend/api/`) and defense docs. Use this when filling the Word/PDF manuscript — **not** as thesis body text.

**Source reviewed:** `new ver_SmartFlow_Capstone2.docx.pdf` (77 pages)  
**Live demo reference:** [docs/defense/START-HERE.md](../defense/START-HERE.md) (6 offices, DV path ENG→BUD→ACC→TRE→MAY→TRE)

### Critical — must fix before oral defense

| # | What we saw in the Capstone 2 PDF | What to fix |
| - | -------------------------------- | ----------- |
| 1 | **Abstract empty** — page only has leftover `Font: Times New Roman; Size: 12` | Write Abstract (problem, SmartFlow solution, method, key results once Ch5 has numbers) |
| 2 | **Chapter 5 empty** — headings 5.1–5.3 only; no screenshots, no ISO tables, no discussion | Fill Ch5: module screenshots + ISO/IEC 25010 WM tables + interpretation |
| 3 | **Chapter 6 + References + Appendices A–D + CVs** are TOC stubs only | Write conclusions/recommendations; paste references; attach questionnaires, sample reports, screenshots, CVs |
| 4 | **§4.5 UAT** says numerical results / weighted means are “in Chapter 5,” and cutoffs “will be used in the final manuscript” | Either complete Ch5 with real scores **or** do not claim completed UAT results until data exist |
| 5 | Roles story clashes with demo — PDF implies incomplete RBAC / “future enhancement,” extra roles (e.g. COA auditor, accounting personnel as separate app roles) | Align to live roles only: **`admin`** (Municipal Accountant), **`staff`** (clerk), **`head`** (department head). Navigation shells already exist |
| 6 | Pilot offices often still **ENG · HR · BUD · ACC only** | Align scope, defs, UAT participants, and ST scenarios to **six offices:** ENG, HR, BUD, ACC, **TRE**, **MAY** (client discovery + live seed) |
| 7 | DFD / Level-1 language invents **“City Clerk,” “Municipal Approval Committee,” approval workflows** | Rewrite DFDs/activity text as **custody tracking** (register → scan IN/OUT → alerts → COA *support* reports). SmartFlow does **not** digitally approve payments or DVs |

### Important — should fix (paper vs live system)

| # | What we saw | What to fix |
| - | ----------- | ----------- |
| 8 | Capstone 1 leftovers: “follow-up interviews **are planned**”; Ch2 “**will use**” ISO / “**planned** web dashboard” | Past tense + present system: React admin + Flutter already implemented |
| 9 | Broken TOC / page map (e.g. Ch5 listed ~p.50 but mid-file is still Ch4; duplicate page refs for diagrams) | Regenerate TOC; add real **List of Tables** and **List of Figures** pages |
| 10 | Figure/table numbering chaos in Ch4 (`Figure 1.0`, `Table 1.0`…) | Renumber as **Figure 4.x / Table 4.x**; add 5.x after Ch5 content exists |
| 11 | Live features understated or missing in scope/objectives/UAT script | Mention where appropriate: **profile + email + avatar**, Account & security / change password, forgot-password, signup + admin approval, **document requests (Layer A)**, **QR image upload** on scan, admin **COA reports**, **QR monitor**, audit exceptions |
| 12 | Payroll framed as a core tracked folder type | Match client: **payslip access only / no payroll folder QR** (see START-HERE limitations) |
| 13 | Stack inconsistency — Ch3 has Flutter + React + PHP/MySQL; Ch4 testing tables lean Flutter-only | State hybrid stack everywhere; add React paths for registration/admin/COA where the demo uses web |
| 14 | Duplicate As-Is / To-Be blocks in Ch3 and Ch4 | Keep once; cross-reference the other chapter |

### Minor — polish

| # | What we saw | What to fix |
| - | ----------- | ----------- |
| 15 | **UrbizTondo** (capital T) in Acknowledgment | Standardize **Urbiztondo** |
| 16 | Typos / leftovers: `perseverance,and`, `ce ntralized`, `TTracking`, truncated UT-07 text, broken WM formula layout, encoding glitches | Proofread pass |
| 17 | Approval sheets still blank panelist lines | Expected until signed; don’t present as “final bound” without noting pending signatures |
| 18 | ERD narrative lists many DB “roles” as if separate tables | Match live schema: `users.role` string + `offices` (see `api-schema.sql`) |

### Already solid in the PDF (keep / lean on in defense)

- Chapter 1 problem framing and **COA support ≠ financial statements**
- Chapter 2 related literature (filled)
- Chapter 3 stack + **HMAC-SHA256 signed QR**, expiration, duplicate-scan blocking, state rules (aligns with `qr-token-helper.php`)
- Chapter 4 testing *structure* (unit → integration → system → UAT design) once Ch5 has scores/screenshots
- Waterfall SDLC (matches panel revision ask)

### Also fix when pasting Chapter 4 into Word

Keep this checklist in the repo; do **not** paste it into the bound manuscript. Before paste:

1. Confirm ST-01 / UAT script match the live DV demo path.
2. After real UAT, replace “results in Chapter 5” wording with actual WM values and cutoffs.
3. Renumber tables if Word already has Table 4.x elsewhere.

### Suggested fill order

1. Abstract (short)  
2. Chapter 5 screenshots + ISO tables (even draft scores labeled “pilot”)  
3. Chapter 6 + References  
4. Align Ch1 scope + Ch3/Ch4 offices/roles/DFD with the six-office demo  
5. Appendices (questionnaire, sample COA export, UAT sign-off form)  
6. Regenerate TOC / List of Tables / List of Figures  

---

*Copy Sections 4.4–4.5 into Capstone 2 Chapter IV after Section 4.3. Renumber tables if the manuscript already uses Table 4.x. Do not leave blank Chapter 5 while §4.5 claims completed evaluation results.*
