# Web user flow — sign in → Dashboard → Requests → Documents → Scan

Status: **derived from source** (`web/src/App.jsx`, `LoginPage.jsx`, `tracking.js`, `RequestsPage.jsx`, `ScanPage.jsx`) on 19 October 2026. It has not yet been walked in the browser, so treat it as a map of intended routing, not acceptance evidence. Web only; phone web and native are out of scope.

Goal: a signed-in person moves from the sign-in page to their own Dashboard, then through Requests, Documents and Scan without leaving their role's allowed pages. Route guards are client convenience only; the API remains the authorization boundary.

Legend: rectangle = screen, diamond = decision, rounded = action, hexagon = system step.

## 1. Sign in and landing

```mermaid
flowchart TD
    S((Open SmartFlow web)) --> L[Sign in page<br/>/ or /login]
    L -->|Forgot password?| FP[Forgot password<br/>/forgot-password]
    L -->|Request access| SU[Request access<br/>/signup]
    L -->|Check access request| SP[Check access request<br/>/signup/pending]
    FP -->|emailed reset link| RP[Reset password<br/>/reset-password]
    RP -->|new password saved| L
    SU -->|Submit| SP
    SP -->|approved| SA[Approved<br/>/signup/approved] --> L
    L -->|Submit username + password| V{{API validates login}}
    V -->|rejected| E[Inline error, stay on Sign in]
    E --> L
    V -->|accepted| D{Deep link to /documents saved?}
    D -->|yes| DOC[Documents with the saved query]
    D -->|no| R{Role}
    R -->|staff| H1[Staff Dashboard /home]
    R -->|head| H2[Head Dashboard /head]
    R -->|admin| H3[Admin Dashboard /admin]
```

Notes
- An unauthenticated visit to any protected page redirects to `/`. Only a `/documents…` target is remembered and restored after sign-in.
- Unknown paths (`*`) redirect to `/`.
- **Expired session (tested 19 Oct):** an invalid token on any protected request clears the stored login and returns to Sign in, where the API text "Missing or invalid token" is shown.
- **Walked in the browser 19 Oct** with staff (ENG, BUD), head (ACC) and admin test accounts: sign in → Dashboard → Requests (create, accept, close, cancel) → Documents (OUT, IN with page count, filing) → Scan page, plus role guards. See `WEB-UX-OBJECTIVES-2026-10-18.md` for observations.
- **Not yet tested:** forgot password with a real email (it writes to the database and sends email; ask before running), and Decline of a request.

## 2. Role guard on every protected page

```mermaid
flowchart LR
    P[Protected URL] --> A{Signed in?}
    A -->|no| L[Sign in]
    A -->|yes| G{Page allowed for role?}
    G -->|yes| OK[Render page]
    G -->|no| HOME[Replace with own Dashboard<br/>staff /home · head /head · admin /admin]
```

| Page | staff | head | admin |
|---|---|---|---|
| Dashboard | `/home` | `/head` (+ `/head/analytics`) | `/admin` |
| Requests, Documents, Scan, History, Alerts, Profile | yes | yes | yes |
| Register | yes | redirected | redirected |
| Users, Offices, Thresholds, Custody reports, QR monitor, System | redirected | redirected | yes |

Registration, IN/OUT and filing remain staff-only on the API; the guard here only mirrors that.

## 3. Main working path

```mermaid
flowchart TD
    DASH[Dashboard] -->|sidebar / bottom nav| RQ[Requests<br/>/requests]
    RQ -->|choose tab: Inbox / My requests / filters| LIST[Server-paged ticket list<br/>next-step cue per row]
    LIST -->|select a ticket| DET[Request details<br/>verifies exact ticket first]
    DET -->|read fails| RT[Retry request details]
    RT --> DET
    DET -->|permitted action| ACT[Accept / decline / close / link / record release<br/>with confirmation]
    ACT -->|saved or stale guard| DET
    DET -->|Open linked folder| FOL[Documents, exact folder<br/>/documents?id=…]
    FOL -->|Back to request| DET
    FOL -->|authenticated 404 only| RO[Read-only out-of-tray fallback]
    FOL -->|403| NO[Access denied, no fallback]
    DASH -->|sidebar / bottom nav| DOCS[Documents<br/>/documents]
    DOCS -->|pick folder| FOL
    DASH -->|staff / head / admin| SC[Scan<br/>/scan]
    SC -->|scan or type folder ID| LK{{Lookup, read only}}
    LK -->|found| REC[Folder record]
    LK -->|not found / error| SCERR[Message, scan again]
    SCERR --> SC
    REC -->|Open the full record| FOL
    REC -->|staff: explicit confirmation| MOVE[Record IN / OUT / filing]
    MOVE -->|saved| REC
    MOVE -->|uncertain write| UNK[Show saved-outcome check, never auto-retry]
    UNK --> REC
    FOL -->|staff, expected movement| MOVE
```

Notes
- Looking up a folder (Scan or Documents) verifies it only. A physical handoff is recorded by the confirmed IN, OUT or filing action, never by accepting or linking a request.
- Requests keeps tab, filter, search, page and selection in its URL, so Back to request restores them.
- Linked-folder fallback only after an authenticated 404; a 403 is never bypassed.
- Head and admin see Scan and Documents as monitoring only on the client; this is presentation, not server authorization.

## 4. Sign out

Profile menu → Sign out revokes the presented session on the server, then returns to `/`. Password change or deactivation also revokes sessions; reactivation does not revive old tokens.

## Open items
1. Walk sections 1–3 in the browser and record any difference from this map.
2. Test expired session and forgot password (needs the user's go-ahead).
3. Objective 3 viewport acceptance of Requests is separate (see `WEB-UX-OBJECTIVES-2026-10-18.md`).
