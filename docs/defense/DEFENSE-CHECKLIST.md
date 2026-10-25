# SmartFlow: defense week checklist (1 week)

Updated 25 October 2026. The September version told you to purge and reseed data and to open maintenance URLs; those steps no longer work and must not be used. Read [CORRECTIONS-2026-10-25.md](CORRECTIONS-2026-10-25.md) first. The presentation itself follows the [six-department projector script](../client/SIX-DEPARTMENT-PROJECTOR-DEMO-SCRIPT.md) and its [sample-data guide](../client/DEMO-DATA-2026-10-22.md).

## Day 1–2: environment (changes no data)

```powershell
cd "C:\Users\nljhn\Downloads\SmartFlow"
.\scripts\fix-api.ps1
```

- [ ] XAMPP Apache and MySQL are running
- [ ] `fix-api.ps1` reports "API reachability check passed" (read-only; it does not deploy, sign in or seed)
- [ ] The working demo database stays as it is: do not purge, reseed or restore before the defense
- [ ] Web portal opens and an existing demo account signs in; credentials come from the restricted login sheet and are never shown on the projector
- [ ] Phone or emulator uses a build made with `FORCE_LOGIN_ON_START=false` and the API address the device can reach (emulator `10.0.2.2`; hotspot or LAN address for a phone)

## Day 3: rehearse the main story (DV trail)

Route: **ENG → BUD → ACC → TRE → MAY → TRE**, optional return to ACC. Use **staff** accounts for each physical step; admin and head accounts only monitor. Use the prepared folder `DOC-2026-000009` (ENG → BUD with counted pages) from the sample-data guide, and show the prepared history for the longer journey instead of walking every office live.

| # | View | Action |
|---|------|--------|
| 1 | ENG staff | Look up `DOC-2026-000009`; confirm the lookup records nothing; OUT to BUD |
| 2 | BUD staff | Receive: count the pages and confirm physical receipt; open History |
| 3 | ENG staff | Try the same IN again or an IN at the wrong office: it is rejected with a reason |
| 4 | Admin | QR monitor, Custody reports (Accounting administrator for exports) |

Backup story: a request ticket (acceptance and payment release are separate from handing over the folder).

## Day 4: panel materials

- [ ] Sample-data guide and projector script on a second screen or printed
- [ ] Thesis figures exported from the thesis documents (the old `thesis-work` folder is not in this checkout)
- [ ] One-liner on limits: custody tracking, not financial approval or payment; pilot, not full deployment

## Day 5: what changed since September (say it if asked)

| Change | Why it matters |
|--------|----------------|
| IN only at the OUT destination, with the reviewed movement guard | A stale screen cannot record a wrong or duplicate handoff |
| Staff-only registration, IN, OUT and filing | Heads and admins cannot alter custody |
| Request acceptance, linking and closing are separate from custody | A ticket never moves a folder |
| Unreceived-OUT destination correction with a full audit entry | A mistaken destination is corrected without faking a receipt |
| Production configuration guard | A server with unsafe settings refuses to run instead of silently using development defaults |

## Known gaps (say them honestly)

- No push or SMS notifications (in-app status only)
- Scan discipline is still required; a missed scan is an incomplete trail
- Not deployed: no production host, no signed release build, and the office user-acceptance run is still pending
- Reports support COA preparation; they are not financial statements or compliance certification
