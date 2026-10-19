# SmartFlow Design System

Context snapshot: **15 October 2026**. Covers the React web portal and Flutter mobile app.

## Status and how to use this document

This document records the current visual foundation, the user's accepted preferences, the implemented Home and Requests design pass, and remaining proposals. On **15 October 2026**, after initially asking for discussion and context documents, the user explicitly requested applying the design to the actual system. Home and Requests now use that direction on both web and mobile. Shared Flutter theme/components also update screens that consume them; broader page composition is not automatically complete.

On **17 October 2026**, the user requested implementing the remaining polish. Scan, Register, Profile/account security and administration Users/Offices/Alert time limits now extend the quiet hierarchy on web and Flutter; native custody reports received a small composition refinement. Scan leads with folder title, location/status and the permitted next action; Register groups identity/logbook/physical contents and makes the saved label useful; account details and sign-in/security have distinct groups. Web form labels are associated with their fields, long content wraps, and native action groups accommodate enlarged text. Existing Home/Requests navigation, raised Scan, single receipt confirmation, stale/recovery and permission guards remain. The unavailable native camera is not mounted after manual lookup. See the [polish report](../.runtime/ui-polish-2026-10-17/report.md) for current verification and device/font limits. Documents, History and Alerts retain their earlier usability refinements; this does not claim a new full composition pass on those pages.

Use [PRD.md](PRD.md) for product rules, [ARCHITECTURE.md](ARCHITECTURE.md) for client structure, and [TESTING.md](TESTING.md) for verification. A visual treatment must preserve custody, request, and role semantics.

The later [five-item remediation](../.runtime/gap-remediation-report.md) applies unavailable/retry states to secondary Users/reports/Analytics, gives phone folder details a direct Retry, keeps query-specific rows/counts separate, preserves full receipt-history evidence and removes silent native exception truncation. Scan's effective destination determines Receive availability; its explanation stays visible when receipt is blocked. These are applied behavior/error-state refinements, not authorization for unrelated page redesign or route/visibility policy changes.

The [follow-up review](C:/Users/nljhn/.codex/state/plugins/codex-security/scans/SmartFlow/artifacts-d1d4e1406d787ced8fe0eadea031db09727deb9cb1717568f26d45c4c687ab24/artifacts/post-remediation-review.md) is historical: the subsequent [follow-up remediation](../.runtime/followup-remediation-report.md) repaired QR/Analytics failed-read presentation, selected web request freshness and native exceptions Retry. The later [polished-flow pass](../.runtime/polished-flow-report.md) handles exact created/recovered-ticket reveal, native request query states and web Scan saved/unverified detail plus shared filing confirmation. Current checks passed 517 API, 74 web, 152 full Flutter and 42 synthetic router tests; final analysis/builds and APK installation passed. Protected native visual review still needs sign-in. These are scoped interaction fixes, not a broader composition redesign.

| Label | Meaning |
|---|---|
| Current | Present in the inspected implementation |
| Accepted preference | Explicitly requested or retained by the user in this conversation |
| Proposed | A design recommendation awaiting visual review and implementation authorization |
| Open | An unresolved choice or a discrepancy requiring reconciliation |

## Product identity and audience

SmartFlow supports the Municipality of Urbiztondo's inter-office physical-folder workflow. Staff need to find a folder, understand its custody, and record the next physical handoff. Heads need an office queue and follow-up context. Municipal administrators need oversight, accounts, reports, and audit information.

The applied Home/Requests direction is a **modern municipal workspace**: official, readable, organized, and calm. The municipality seal, navy identity, and operational meaning remain recognizable. Decorative elements must serve orientation or comprehension. Extending the composition to other page families remains proposed.

## Accepted preferences

These are concrete constraints from the user's review, rather than inferred aesthetic choices:

1. Keep the raised central Scan control in the mobile bottom navigation.
2. Remove the full-width gray strip above that navigation while retaining the raised control itself.
3. Remove the office-header workload line such as "0 on desk · 0 incoming".
4. Avoid duplicating the Home Scan action when Scan is already available in navigation.
5. Give Home Requests and Register folder the same navigation-row style, with an icon, title, and trailing chevron. Register belongs beside or beneath Requests; the phone uses stacked rows.
6. Keep a consistent visual language across web and mobile, including other pages and role-specific screens.
7. On web Requests, New request precedes Inbox / My requests in the controls row. On phone web, it appears above those tabs.
8. Respect a discussion-only or documentation-only request until the user authorizes implementation. The later 15 October instruction authorized the actual Home/Requests pass on both platforms; it did not change product workflows or permissions.
9. The subsequent authorized simplification uses one physical-receipt dialog, consistent Scan/Documents handoff controls and a contextual Back to request. Keep actual counts, explicit confirmation, reasons and stale/busy guards within that simpler flow.
10. The **17 October 2026** desktop-sidebar review selects a navy web sidebar, promotes admin Custody reports into primary navigation immediately below Dashboard, and restores the web label Thresholds in navigation and the page title. The user's subsequent refinement removes the Administration heading/dropdown: its links stay visible and aligned after a divider. This supersedes the earlier web Alert time limits label and report placement under Administration. Phone web retains the center Reports action and fourth-slot Alerts; native retains its accepted navigation composition. See the [admin-sidebar report](../.runtime/admin-sidebar-2026-10-17/report.md).
11. The subsequent **17 October 2026 web caption cleanup** removes generic descriptions beneath authenticated page titles. Move longer Thresholds timing/deadline semantics into page-specific ? Help; retain concise calendar-hour field hints, including `48 hours = 2 days`. Keep Monitoring only role cues, holder-office registration instructions, required field guidance and error/stale/action/confirmation/saved-outcome messages where users need them. Authentication/status guidance and native copy remain outside this cleanup. Existing frames, spacing and navigation remain accepted. See the [caption-cleanup report](../.runtime/caption-cleanup-2026-10-17/report.md).
12. On **18 October 2026**, the user confirmed simplicity, consistency, hierarchy, feedback, accessibility and responsiveness as the basis for the web review, with findings before changes and the same visual identity as mobile. Related panels and controls should share sizing, spacing and typography; different content can retain useful column proportions. Desktop tables/sidebar and phone stacking remain appropriate. The subsequently authorized [web layout refinement](../.runtime/web-layout-refinement-2026-10-18/report.md) implements the reviewed Requests, Documents controls, Thresholds headers and Register office-context changes. Fresh browser acceptance remains pending because local browser use is disabled; this is not a completed whole-portal accessibility or responsive audit.
13. On **19 October 2026**, the user rejected decorative colored side stripes and the yellow **Check email** label, then authorized replacing only the obvious decorative accents found in the [accent review](../.runtime/accent-review-2026-10-19/report.md). Office identifiers now use neutral navy/slate styling; office cards, sidebar/list selection and native queue/alert/report rows omit decorative edge stripes. Web Check email and Requested role use plain metadata text. Existing layouts, active backgrounds/focus, meaningful status/warning/error colors, native blue active navigation and the raised navy Scan remain. The [implementation report](../.runtime/accent-cleanup-2026-10-19/report.md) records exact scope and verification; broader badge/panel neutralization remains proposed.
14. The subsequent **19 October web Offices layout** applies the user-approved preview: visible Office and Document type columns, aligned Processing/Record receipt hour columns, plain office codes and one Edit/Add limits link per office. Multiple rules share one office row group; absent custom rules remain explicit rather than showing zero. At widths up to 1000px, office groups stack with visible numeric field labels and their action after all rules. This supersedes the earlier hidden Office heading and code-badge composition on this web page. The existing shell/frame, rule values, loading/error/empty states and Thresholds links remain. See the [Offices report](../.runtime/offices-layout-2026-10-19/report.md); native composition is unchanged.

## Current foundations

### Applied usability refinement

After reviewing the Documents, Requests, History, Alerts and time-limit screenshots on 15 October 2026, the user authorized applying the recommended simplification to the system. The web and native clients now use clearer task grouping and labels; this pass does not change custody or financial authority.

- Web keeps the daily Dashboard, Documents, Requests, History and Alerts destinations visible. The latest 17 October preference places admin Custody reports immediately below Dashboard in primary navigation. Users, Offices, Thresholds, QR monitor and System remain visible after a divider, without an Administration heading/dropdown; the account menu provides Profile. Web uses Thresholds as the navigation and page label. Native uses its existing device-appropriate menu, Alert time limits label and raised navigation control.
- Documents puts the folder title, current holding/sending office, receipt state and deadline ahead of reference/origin metadata. Web search and office filtering share a compact row. Full details/contents, custody journey and QR remain available as secondary disclosures; applicable staff handoff controls and discrepancy warnings remain visible. Opening the full exact folder history remains a direct action.
- Requests starts with active work (pending and accepted). Past requests retains closed, declined and cancelled tickets; All, Pending and Overdue remain available. Web uses a labelled Show selector; native uses its compact status choices. Web New request precedes Inbox/My requests; native uses the persistent lower-right action described below. Brief copy explains the office inbox versus tickets authored by the user. Full purpose and next step/outcome precede metadata and full notes. Filtered pages still come from the server.
- History offers two explicit views: Folder history and Office activity. The former retains the complete chronological folder evidence, while the latter supplies the full paged office/day log. Recent-ID and desk previews no longer compete with those tasks. Direct folder links and office-log error/retry states remain.
- Alerts uses Receipt not recorded instead of No IN scan. Deadline severity and custody/receipt state remain distinct. Server detail explains the applicable deadline; an OUT alone does not prove physical nonarrival. Failed initial loads show unavailable/retry, and failed refreshes identify retained data as potentially stale.
- Thresholds on web and Alert time limits on native edit an existing rule with both processing hours and hours allowed to record receipt after sending. Web keeps concise calendar-hour field hints and places the longer explanation of continuous hours, individual folder deadlines and alert-only effects in page-specific ? Help. Native retains its existing explanatory copy. Failed rule reads disable saving until a successful reload.

The earlier Home/Requests design and single-receipt simplification remain in force. The 17 October polish above implements the selected Scan/Register/Profile and administration composition work; the remaining role-specific pages are separate. The [usability report](../.runtime/usability-clarity-report.md) remains dated evidence for its earlier scope.

### Colors

The implementations already share most base colors. These values describe existing source, not a newly generated theme.

| Purpose | Value | Current use |
|---|---|---|
| Navy / main ink | `#0B1F3A` | Municipal identity, desktop web sidebar, headings, primary signed-in buttons |
| Blue | `#1D4ED8` | Interactive accent, links and selected indicators |
| Additional blue | `#2563EB` | Existing accent variant |
| Page background | `#EEF2F7` | Signed-in web override and Flutter scaffold |
| Surface | `#FFFFFF` | Cards and form surfaces |
| Muted text | `#526176` | Supporting descriptions and metadata |
| Success | `#15803D` | Completed/success states |
| Error / overdue | `#B91C1C` | Failures and overdue emphasis |
| Gold | `#B8860B` | Existing theme accent; use should remain restrained |
| Web surface border | `#DCE3EC` | Signed-in shared layout override |
| Flutter shared card border | `#DCE3EC` | `SfFormCard`, navigation rows and metric strip; some older local separators retain other values |

The **19 October accent cleanup** uses navy/slate office names, codes and initials instead of assigning a separate accent color to ENG, HR, BUD, ACC, TRE and MAY. Department palette constants can remain in source, but current office identity widgets use the neutral treatment. Semantic status colors remain separate and always include readable status text.

Web has legacy base variables plus later overrides. Flutter has shared tokens plus local widget styles. They are separate implementations; exact token parity is not yet centralized.

Current request badges use **Pending amber, Accepted blue, Closed/Payment released green, Declined red, and Cancelled muted** in both clients. An accepted ticket can still show a separate red overdue warning. Accepted is a request decision, not completion or financial approval.

### Typography

The **19 October mobile flow alignment** retains the accepted native composition while making request decisions explicit: scrollable named Accept/Cancel/Close/Payment release dialogs, optional stage-specific notes, full custody/payment warnings and linked-folder context. Dialog actions retain readable labels, system-scaled text and 48px touch targets. Native History adds a chronological explicit Filed event and wraps its heading/loaded-folder controls at enlarged text. These are scoped interaction/evidence changes; initial Documents tray selection and the compact request list remain unchanged. See the [alignment evidence](../.runtime/mobile-flow-alignment-2026-10-19/report.md).

The subsequent user-selected **19 October mobile hierarchy refinement** makes verified-empty staff Dashboard sections quiet informational rows while retaining separate folder/incoming sections, full copy and framed stale-empty guidance. Small section-gap reductions bring activity earlier; matching Home Requests/Register navigation rows remain. Requests groups the selected-view explanation and complete handoff rule beneath Inbox/My requests without changing controls, scaling, fixed New request or keyboard clearance. Scan puts existing terminal guidance beside location/status before contents, with a separate Route complete pill for the already-permitted optional Accounting return. The three presentation-only changes retain actions, authority and recovery. See the [refinement report](../.runtime/mobile-hierarchy-refinement-2026-10-19/report.md) for fresh checks and role/device limits.

- Web declares Source Sans 3 with Segoe UI and sans-serif fallbacks.
- Flutter builds its text theme with `GoogleFonts.sourceSans3TextTheme`.
- Current shared web page title: 28px on desktop, 24px at the phone breakpoint; Home/Requests use weight 650. Desktop admin headings share weight 650 and zero heading padding. An optional operational cue uses the existing 14px supporting style with a 5px top margin; generic page descriptions are removed by the accepted web caption cleanup.
- Current Flutter `SfPageTitle` uses themed `headlineSmall`: 26 logical pixels, weight 700, line height 1.15; subtitle 14.
- Current web shared section heading: 16px; Home queue headings 17px on desktop and 16px on phone, with weight 650. The Requests details heading is 15px/600. Flutter themed sections use `titleMedium`, 16/700.
- Web request row purpose is 15px/600; full purpose is 16px, reducing to 15px on phone. Flutter request row purpose is 16/700 and limited to two preview lines; full purpose remains available in details.
- Shared web buttons are 14px; inputs are 14px on desktop and 16px on phone.
- Local screens still have individual weights and sizes. A shared family alone does not establish a complete type hierarchy.

**Current in Home/Requests:** folder titles and request purpose carry the primary record hierarchy; codes, dates, route metadata and helper copy are smaller and subdued. The shared Flutter theme establishes page/section/body levels. **Remaining proposal:** review local styles on other page families rather than assuming every screen already follows the same hierarchy.

### Spacing and surfaces

- Current web shared page/column gap: 20px, reducing to 16px on phone. Home/Requests and desktop admin pages use an 18px page rhythm; phone Home/Requests retain 16px. Home queue columns are 24px apart, Requests list/detail columns 22px.
- Current web shared cards: 20px padding, reducing to 16px on phone; 12px radius; border; no general card shadow.
- Current Flutter shared form card: 18 logical pixels of default padding and 12px radius, including flat rows.
- Current navigation rows: web shared minimum 72px; Home uses 76px on desktop and 70px on phone, with 10px radius. Flutter shared rows have minimum 68 logical pixels and 12px radius.
- Web shared controls have a 44px minimum height; Flutter themed filled/outlined controls have a 48 logical-pixel minimum.
- Flutter dialogs and bottom sheets use the same white surface as cards, with transparent Material surface tint; they avoid a separate lavender overlay surface.

**Current direction:** compact metadata and toolbars while preserving readable text and touch targets. Web Home uses a quiet metric strip with top/bottom rules and white folder lists separated by horizontal dividers; Requests uses one list surface rather than a bordered card around every ticket. Flutter uses grouped request rows with separators, a quiet metric strip, and matching Home navigation rows. Platform units and density differ while preserving the grouping. Reserve elevation for an actual hierarchy cue, including the accepted raised Scan control.

### Icons

Web uses `SfIcon` with shared SVG paths. Flutter uses the `SfIcons` Material mapping. They represent corresponding destinations but are not identical drawing assets. Match meaning, visual weight and alignment. Reuse the existing icon systems rather than introducing unrelated icon sets per page.

## Current layout patterns

### Shell and navigation

Desktop web uses a navy side navigation and office top bar. Admin Custody reports is a primary destination immediately below Dashboard. Users, Offices, Thresholds, QR monitor and System appear as regular aligned links after a divider; there is no Administration heading or dropdown. The latest [sidebar preference](../.runtime/admin-sidebar-2026-10-17/report.md) supersedes the earlier report grouping and web time-limit label while preserving report and rule permissions.

The subsequent user-authorized **18 October Requests workspace correction** bounds the desktop shell to the viewport at the existing 768px boundary. The office header and branding stay outside content scrolling; long navigation scrolls below the branding and main content has its own scrolling fallback. The header and grid row share 64px normally and 56px in the existing short-desktop mode. Account/help overflow remains available. This shell correction applies to protected desktop pages; phone shell rules and page frames remain. See the [correction report](../.runtime/requests-workspace-correction-2026-10-18/report.md) for automated checks and the pending actual-browser acceptance.

Phone web and Flutter use role-based bottom navigation. On **17 October 2026**, the user first placed Alerts fourth, then requested swapping Profile and Menu: Profile now opens from the top-right header, and Menu opens the existing role tools sheet from the fifth bottom slot. Alerts remains immediately right of the center action. The implemented order is:

| Role | Native and phone web bottom navigation |
|---|---|
| Staff | Home, Documents, Scan, Alerts, Menu |
| Head | Home, Queue, Scan, Alerts, Menu |
| Admin | Home, History, Reports, Alerts, Menu |

The later [Profile/Menu swap](../.runtime/profile-menu-swap-2026-10-17/report.md) supersedes the fifth-slot Profile placement in the [Alerts-position report](../.runtime/alert-nav-position-2026-10-17/report.md). Profile keeps its role-specific destination; Menu retains its existing sheet, destinations and badges. A tools destination selects Menu; Profile selects its header action. Existing center controls, active styling, safe areas and role permissions remain. Desktop web navigation and account controls keep their existing composition. Navigation visibility does not establish route authorization.

Preserve the physical device safe areas, readable labels, current office context, and selected destination. The raised center item is Scan for staff/head shells and Reports for the administrator shell. A gray band above the bar is not part of the accepted staff Scan treatment.

The **17 October navigation follow-up** makes the reserved space above the white row transparent, as the user requested after reviewing a white-surface alternative. The page extends into the 26px raised-control clearance, while the opaque icon/label row and system inset stay outside the page viewport. Preserve existing bottom content spacing so the last action scrolls above Scan. The raised control retains its geometry and complete hit area. The bottom navigation owns its Android system-bar annotation with dark navigation icons. See the [navigation report](../.runtime/navigation-2026-10-17/report.md) for full regressions, white-page/enlarged-text/keyboard previews and protected emulator evidence.

The user then selected **color-only active regular tabs**: blue icon and label, muted gray when inactive, with no filled selection pill. The raised Scan keeps its navy/white action treatment and uses a blue label when active. Its painted circle is now 50px inside the existing 56px slot, with a 24px icon, 2px rim and softer shadow. Original bar height, label alignment, hit bounds and transparent-clearance layout remain. See the [selection refinement](../.runtime/navigation-balance-2026-10-17/report.md) for current checks and device review.

The subsequent user-authorized **18 October mobile layout refinement** keeps bottom labels on one line with up to 1.3× label scaling, matching the installed Flutter Material navigation pattern; full names remain in tooltips and screen-reader labels, and page text keeps the system scale. Regular targets are at least 48px high, and the raised center retains its circle, slot and transparent clearance. The office header allows two lines at large text. Enlarged Menu rows use more label width, a smaller base title size that still follows system scaling, and omit redundant chevrons while retaining badges and callbacks. See the [mobile refinement report](../.runtime/mobile-layout-refinement-2026-10-17/report.md); its evidence folder retains the date work began.

### Page width inventory (current web)

The **17 October admin alignment preference** gives desktop admin pages one outer frame, with common left/right title and content edges. It applies within `app-shell--admin` at the existing desktop shell boundary of 768px. Dashboard, Custody reports, Documents, Requests, History, Alerts, Users, Offices, Thresholds, QR monitor and System share a 1440px maximum frame, an 18px page gap and the same heading typography/padding. Keep each page's inner composition and readable form/text widths; equal outer edges do not require equal columns or section heights. See the [admin page-alignment report](../.runtime/admin-page-alignment-2026-10-17/report.md).

| Scope / page family | Maximum content width |
|---|---:|
| Desktop admin outer frame, at 768px and above | 1440px |
| General signed-in workspace / Home, outside that override | 1240px |
| Documents, Requests, History, outside that override | 1440px |
| Register, Profile, Thresholds, outside that override | 1040px |
| Alerts, System, outside that override | 960px |
| Scan before lookup, outside that override | 760px |
| Scan with folder result, outside that override | 1240px |

Other roles and phone web retain their existing frames; all maximums remain constrained by the available viewport. Inner field and explanation widths stay independent of the outer frame. The current content workspace breakpoint is 1101px: Documents uses a table and Requests uses inline details above that width. At 1100px and below, Documents uses cards and Requests uses the details dialog. Other shell and stacking rules exist at 900px, 767px and 760px; do not assume one breakpoint controls all navigation and content.

### Home

The page title is **Dashboard** across staff, head and admin on both platforms, following the user's 15 October naming review. Office/role identity stays in the shell header.

Current composition: page title, grouped office metrics, matching Requests/Register navigation rows, folders at the office, incoming folders, and platform refresh information where present. Web removes the generic title description; native retains its current subtitle. Home has no duplicate Scan action. Register includes supporting copy that the folder must already be at the office.

**Implemented refinement:** folder titles appear before subdued IDs/metadata; related metrics remain quiet; incoming and currently held folders stay distinct. Web section headings sit outside the white folder-list surfaces, and native mobile uses its touch-friendly stacked records. Successful zero counts have compact empty states. Failed initial dashboard loads, including head/admin follow-up changes on both clients, show unavailable content and retry rather than a false zero workload. Failed refreshes label previously loaded data as potentially stale and preserve the last-success context.

The later mobile refinement compacts only the staff Dashboard's successful-empty folder/incoming cards, retaining both sections and their counts. Initial errors remain unavailable; retained refresh results and historical empty lists are labelled accordingly. Home and Menu now share the Register folder label/icon and Requests inbox icon.

### Requests

Current desktop composition after the usability refinement:

```text
Requests                               Last successful update
[New request] [Inbox | My requests] [Show: Active requests]
[Search requests + Search]
[Request list]                         [Full details + action footer]
```

Current phone web composition is stacked, with New request above Inbox/My requests and full request details in a scrollable dialog with actions in its footer. The Flutter request screen uses a persistent labelled + New request action in the lower-right; tickets share a grouped white list surface with separators and open full details through the existing native interaction.

The subsequent user-selected **18 October Flutter action placement** moves + New request from the heading to the lower-right, above the complete raised Scan/navigation clearance. The labelled button remains available while scrolling. All list states reserve a text-scaled scroll tail so final ticket/paging actions can scroll above it. The role shell handles keyboard resizing; the create button hides while the keyboard is open and returns on dismissal. This supersedes the earlier native heading/before-tabs placement. Concise ticket-versus-handoff guidance and the selected-view explanation remain, control gaps/search padding are tighter, and Inbox/My requests can wrap within taller tabs at enlarged text. Search, filters, paging, full details, return context and all request actions retain their existing behavior. Phone web keeps its existing composition. See the [placement report](../.runtime/request-create-position-2026-10-18/report.md).

**Implemented refinement:** update information joins the web heading, controls form one toolbar, and New request remains before Inbox/My requests. Ticket rows put purpose before subdued route/type/deadline metadata; selection uses a subtle blue fill and leading indicator. Full purpose/reasons remain in details, with reachable permitted actions. Request load failures do not masquerade as an empty successful list. Automatic first-record selection has not been introduced; it remains an open product/design choice.

The initial **18 October web layout refinement** matched desktop header typography/padding and minimum height, retained the narrower-list/wider-details proportions, added named keyboard-focusable scroll regions and expanded the search row. Inbox/My requests use native grouped toggle buttons with an explicit pressed state. Its populated-screenshot follow-up identified competing shell/panel scrolling and a terminal-request footer without actions; see the [historical refinement and follow-up](../.runtime/web-layout-refinement-2026-10-18/report.md).

The subsequently authorized **18 October Requests workspace correction** replaces viewport-subtraction panel limits with remaining-space flex sizing inside the bounded desktop shell. Above 1100px, the paired panels stretch together, retain their shared 72px minimum headers and reserve an 18rem usable workspace minimum. List/paging and full information/stale guidance/Retry scroll independently when needed. Main content can scroll when controls, error banners or enlarged text need more room; opening New request or using a desktop window at most 560px high restores natural panel contents so forms and actions remain reachable. Desktop action footers and phone dialog footers are rendered only when the reviewed user has existing permitted actions; busy/stale buttons remain disabled. Search overrides the inherited 160px button minimum while its input stays flexible. At 1100px and below, the list retains natural height and details open in the existing dialog. The [correction report](../.runtime/requests-workspace-correction-2026-10-18/report.md) records fresh verification; browser pixels, zoom, focus and scrolling remain unverified while browser use is disabled.

Full purpose, required-by date, requester, handler, review/closing notes, status and linked folder must remain readable. Accept request, close request and Treasury's Mark payment released have different meanings. Linking a folder does not finish a request.

From office hides the access-type field and creates a general pull to the selected existing other office. Switching from Budget/DV/Others must not carry that hidden category into the new ticket. Existing historical tickets retain their recorded type.

The [follow-up remediation](../.runtime/followup-remediation-report.md) shows initial review, closing/payment release and cancellation notes with their own recorded actor/office/time on both clients. Older mixed notes retain available recorded metadata under a generic label explaining that its stage is unknown. Failed exact-ticket rereads keep the web detail readable while disabling decisions, linking and register-from-request; a list refresh alone does not re-enable them. Retry request details verifies that selected ticket again.

**Current follow-up navigation:** the linked-folder primary action opens that exact record in Documents; View custody history is secondary. Staff see applicable own-office actions from current server detail, while head/admin and out-of-tray tracking detail remain read-only. A successful tracking fallback does not hide an office permission error or grant an operational action.

**Current return context:** Documents reached from a linked request provides Back to request alongside the existing Back to list. Web restores committed tab/filter/search/page/selection from validated Requests URL parameters. Native pops to the retained request view and reloads the ticket before reopening details; the displayed decision is refreshed rather than blindly reused. A directly opened Documents record retains its ordinary list navigation.

Newly created and recovered requests reveal the exact permitted ticket, with an explicit return to the previous request view. Old search/status/page filters cannot hide the successful result. Native rows, counts and available actions follow their loaded account/query; a failed changed-query read shows unavailable content, while a failed same-query refresh labels retained data stale and blocks decisions until verification succeeds.

### Documents and Scan

Current desktop Documents shows tracking ID, title/reference, office, status, wait and deadline in a table; selecting a record opens adjacent custody details. Back to list clears selection. Phone uses cards and moves focus into details.

The **18 October web control refinement** gives Documents Sort by the shared 44px minimum control height, 10px corners, border/type tokens and a visible focus ring. Existing tray/filter behavior remains.

Current Scan begins with tracking-ID lookup, followed by camera/upload alternatives. A result expands the desktop workspace to lookup plus folder/next-action panels. Smaller screens stack the result above lookup. Looking up a record does not record IN or OUT.

The 15 October clarity follow-up groups **Overdue** with the Documents tray choices as one exclusive view. It covers active overdue folders across trays, respecting the current office scope; its helper text explains this. Details label the holder as Current office and keep an overdue badge separate from the custody status. Read-only native details show custody rather than Send/Receive instructions. The inline journey contains movements; **Open full activity history** also provides registration and linked request activity. Native pagination controls appear only when more than 50 records require paging. See the [clarity report](../.runtime/design-mockups/clarity-report.md).

The user-selected **18 October native View dropdown** replaces the wrapped Documents tray chips with one labelled selector: Incoming, At your office, Forwarded, Completed and Overdue. Municipal scope retains At offices and omits Incoming. Positive counts appear beside labels; known-zero counts are omitted and unavailable counts show `—`. Full labels can wrap at enlarged text. Selecting a view keeps the existing search-commit, debounce cancellation and page-reset behavior; Overdue remains exclusive and spans active trays. Existing unavailable/stale guidance and custody permissions remain. Web keeps its existing controls. See the [dropdown report](../.runtime/documents-view-dropdown-2026-10-18/report.md).

**Current recording correction:** eligible sending-office staff can open **Correct recorded destination** for the latest unreceived OUT. The form shows the recorded destination, requires a new office, a full reason and explicit confirmation, and explains that no receipt/additional handoff is recorded. Changed/received details reject stale submission; an uncertain outcome uses recovery rather than an automatic write retry. Journey/history shows the old/new destination, reason, correcting person and time. Keep this distinct from Return for correction, which records an actual physical OUT after receipt. Correction is a secondary action and never appears for read-only viewers.

**Current handoff simplification:** Receive opens one shared physical-check dialog, with page counts, discrepancy reason and explicit confirmation. The duplicate pre-dialog receipt checkbox is removed. Web Scan/Documents reuse [FolderHandoff](../web/src/components/FolderHandoff.jsx); native screens use the existing destination dialog with consistent suggested-office data and send wording. Filing, correction and history retain their separate meanings. None of these controls creates a receipt before the confirmation completes.

Documents and Scan confirm filing separately and retain the reviewed movement through confirmation; web shares [FolderFiling](../web/src/components/FolderFiling.jsx). Cancelling makes no write. Web Scan keeps a saved action visible if its follow-up detail read fails, labels custody unverified and offers Retry current details while disabling another physical action. Retry reads only. A stale filing conflict reloads the folder for another review, without automatically submitting the action again. Filing remains a staff action for an eligible folder currently held by the office.

Native Documents binds rows, counts and last-update text to its loaded account/tray/search/page. A failed changed-query read cannot show the old tray's records; a failed same-query refresh labels retained records stale and blocks physical actions until verification succeeds.

An explicit named Others folder keeps its own workflow even when its name contains voucher, disbursement or approved budget. Do not show a financial destination suggestion, financial-stage completion or DV-only return for that name; explicit filing ends its work and uses neutral filed wording.

**Proposed refinement:** broader status-summary and metadata composition remains separate work. Keep the scanner usable when camera permission is unavailable through existing lookup/upload alternatives.

### Register

The user-selected **18 October native Register refinement** brings the first form fields higher. The title is Register folder, with one visible rule to register an unlabelled folder already held by the office. A compact reminder keeps existing-ID → Scan/Documents and another-office → Request guidance visible; the office-specific Tips retain their existing content and start collapsed. Quiet locked office text replaces the bright badge. The repeated Folder details heading/required-field description is removed because each input retains its required label. The title example is shorter and the input starts at one line, expanding to two for longer text.

Creation recovery, linked-request receipt/link wording, draft messages, Accounting sender/retry/restriction, type-specific fields, validation, physical contents confirmation and the submit flow keep their existing behavior. Web and the rest of the native form composition are unchanged. See the [Register report](../.runtime/register-layout-2026-10-18/report.md).

The subsequent **18 October Register details cleanup** shortens the empty date action to Choose date and moves the existing office-alert-limit explanation below it. One Contents & page counts introduction replaces duplicate headings/instructions; keep the missing-required-attachment `0` rule and office ownership of requirements visible. Registration checklist status/refresh are compact, with failed reads kept distinct from verified-empty checklists. The full physical-count confirmation uses a leading checkbox and remains tappable as one row. Published checklist selection/replacement, draft/count reset, manager checklist composition, validation and the full-width navy Register action retain their behavior. See the [details report](../.runtime/register-details-2026-10-18/report.md).

### Other pages and roles

The **18 October web layout refinement** unifies Thresholds panel-header structure, spacing, typography and divider treatment, allowing long rule/office text to wrap and removing the desktop header minimum when the panels stack. Web Register now presents the full authenticated registering-office name/code as quiet labelled locked context, using the existing Profile assignment styling instead of an editable-looking input. Required fields, draft/recovery, permissions and save guards remain. See the [report](../.runtime/web-layout-refinement-2026-10-18/report.md) for fresh automated checks and the unavailable browser-review boundary.

The **18 October native UX feedback fixes** address four findings from the [read-only review](../.runtime/mobile-ux-review-2026-10-18/report.md). Head Queue distinguishes initial unavailable, verified empty and retained stale results, provides Retry queue and last-success information, and uses Clear search for search misses while retaining the chosen filter. Staff/head/admin Profile snapshots share unavailable/stale/retry/progress cues without blocking account/security navigation; a failed admin status check remains unknown and does not retain a fresh-looking green online claim. Signup decisions reserve the pending action before confirmation, show Approving/Rejecting feedback and disable conflicting decisions until the submitted result settles. Existing session/freshness guards, permissions and navigation remain. The [implementation report](../.runtime/mobile-ux-fixes-2026-10-18/report.md) records current tests and device limits. The Alerts composition suggestion remains proposed.

| Area | Design priority |
|---|---|
| Register | Clear field groups, office/type eligibility, required fields, folder contents, success with QR |
| History | Readable custody timeline, office/destination context, correction reasons, selected record |
| Alerts | Severity plus explanation and useful navigation; genuine unavailable state |
| Profile | Clear account summary and distinct account/security actions |
| Head queue / analytics | Fast office scanning, overdue emphasis, readable reporting periods |
| Admin accounts / offices / thresholds | Administrative scope, reversible state feedback, validated forms |
| COA / QR monitor / System | Honest loading/error/empty states, report period and export context |

Match the shared visual hierarchy in these pages. Do not give monitoring screens write capabilities solely to make their layout resemble staff pages.

Web QR monitoring and head Analytics now show initial failures as unavailable with Retry, retain visibly stale same-query data after refresh failure and hide old-query data after outcome/month changes. Empty all-clear wording requires a successful read; QR export requires verified data. Native Retry exceptions clears its prior error when the reread succeeds. The [follow-up report](../.runtime/followup-remediation-report.md) records this behavior separately from earlier 327/58/128 remediation evidence; it is not a broader page-composition pass.

## Component behavior

| Component | Required behavior |
|---|---|
| Page heading | One visible page title; authenticated web omits generic captions and retains necessary operational cues. Native keeps its current copy. |
| Navigation row | Icon, left-aligned text, optional subtitle, chevron; matching Requests/Register treatment |
| Primary button | Clear action verb and strong treatment; enabled only when prerequisites are met |
| Secondary button | Supporting alternative such as upload, camera or optional forwarding |
| Destructive/correction action | Explicit wording and applicable reason; distinguish from successful completion |
| Status badge | Text label with semantic color; consistent meaning on both platforms |
| Table/list selection | Visible selected state and keyboard/native tap entry point |
| Empty state | State-specific message and useful next step when available |
| Error state | Plain explanation, preserved input where safe, and an appropriate retry/recovery path |
| Dialog/sheet | Scrollable long content, reachable actions, stable focus and draft text |
| Update indicator | Last successful contact/refresh information; failure must not masquerade as a fresh update |
| Signup status | Private status key or fresh legacy credentials; use request code/current credentials after rename, direct unbound historical applicants to administrator assistance, keep proof out of URLs/screenshots |
| Sign out / password change | Show an explicit logout failure/retry if server revocation fails; successful password change clearly asks for sign-in again |

Avoid treating every section, metadata line and action as another bordered card. Avoid multiple equally prominent actions where the workflow has one next step.

## Accessibility and responsive review targets

These are acceptance targets for future design work, not a claim of completed accessibility certification:

- Keyboard operation and visible focus in web tables, controls and dialogs.
- Screen-reader labels for icon-only controls; explicit text for status and errors.
- Reachable dialog actions and focus restoration after closing or returning to a list.
- No page-level horizontal overflow at 320, 360 and 390px; contained table scrolling may be appropriate on narrower desktop panes.
- Flutter layouts must remain usable at 2x text scaling; long office names, titles and reasons must wrap safely.
- Device keyboard and safe-area insets must not hide form actions or the raised Scan control.
- Check actual colors and font rendering for readability rather than assuming the token names prove contrast compliance.
- Review desktop at 1280x720, 1440x900 and 1920x1080, including long purpose text and empty/failed data.

## Applied pass and remaining review sequence

The user changed the earlier preview-only scope on **15 October 2026** by requesting application to the actual system. Home and Requests composition, along with shared Flutter visual foundations, have been implemented. The [implementation report](../.runtime/design-mockups/implementation-report.md) records actual browser/emulator review, builds and test results; keep its final focused verification separate from earlier full-suite results.

1. Review the applied Home/Requests screens with empty/populated data, selected records and long text.
2. Refine those patterns from concrete user feedback while preserving accepted preferences.
3. Extend composition to Documents, Scan, Register, History, Alerts, Profile and role-specific pages within the user's authorized scope.
4. Verify each extension with actual browser/emulator screenshots and relevant [Testing](TESTING.md) checks.

Steps involving other page composition remain proposed. Shared typography/surface inheritance alone does not establish that every page has received a complete design pass.

The later user-authorized 5/7/8/9 follow-up adds scoped correction, navigation, dashboard failure and account-security interactions; it does not authorize a wholesale redesign of the remaining pages. Browser review inspected the correction form and audit history at desktop/phone widths, Request 104 opening its exact outside-tray Documents detail read-only, and admin error/retry without fake zero counts. The follow-up passed 278 isolated API checks, 32 web tests and 103 Flutter tests with analysis/builds passing. The updated APK was installed preserving app data and its emulator landing screen checked; protected emulator screens remain pending user sign-in. Evidence belongs in the [follow-up report](../.runtime/system-gap-followup-report.md). Earlier screenshots/test results remain dated evidence for their original scope.

The subsequent user feedback authorized reducing redundant clicks in both clients. Single-dialog receipt, consistent handoff controls and contextual request return are implemented. This pass passed 41 web tests, web build/scoped lint, 107 full Flutter tests and clean analysis. The debug APK built, installed with `-r` and launched. Browser sample review at desktop/390px covered sole counted receipt, cancellation, request return and shared return controls; receiving-office errors persist across Refresh until Retry successfully reloads choices and re-enables Send. Protected emulator visual review remains pending user sign-in; the actual landing is Get Started/Sign in. See the [flow simplification report](../.runtime/flow-simplification-report.md). This is a scoped interaction pass, not evidence that every page's composition or every system gap is complete.

## Open design questions

- Whether the applied Home/Requests density and hierarchy need adjustment after the user's actual-system review.
- Request default-details behavior and empty-list composition.
- Whether navigation labels such as Dashboard/Home and Queue/Documents should be further harmonized while preserving role meaning.
- Offline font availability and device rendering should be checked before claiming typography parity.
- English is the current visible interface language; a Filipino/bilingual interface and dark theme have not been requested as part of this design pass.

## Implementation sources

- [Web base tokens and legacy styles](../web/src/index.css)
- [Web stylesheet import order](../web/src/main.jsx): index, sf-life, then page-layout
- [Web current signed-in overrides and workspace widths](../web/src/page-layout.css)
- [Web shell/navigation](../web/src/components/Layout.jsx), [icons](../web/src/icons.jsx), [shared UI/dialogs](../web/src/components/ui.jsx)
- [Web Home rows and metrics](../web/src/components/HomeWorkspace.jsx)
- [Web Requests](../web/src/pages/RequestsPage.jsx), [Documents](../web/src/pages/DocumentsPage.jsx), [Scan](../web/src/pages/ScanPage.jsx)
- [Flutter theme](../mobile/flutter/lib/theme/smartflow_theme.dart), [icons](../mobile/flutter/lib/theme/sf_icons.dart)
- [Flutter shared components](../mobile/flutter/lib/widgets/sf_widgets.dart), [shell top bar](../mobile/flutter/lib/widgets/sf_shell_chrome.dart), [scaffold and bottom bar](../mobile/flutter/lib/widgets/sf_page.dart)
- [Flutter staff shell/Home](../mobile/flutter/lib/screens/staff/staff_shell.dart), [Requests](../mobile/flutter/lib/screens/shared/document_requests_screen.dart)

The accepted preferences above come from the user's review in this chat. Historical screenshots and verification reports are under the local `.runtime/` folder; they are evidence of dated checks, not a replacement for current source inspection.
