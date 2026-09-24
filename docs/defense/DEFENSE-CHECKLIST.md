# SmartFlow — Defense week checklist (1 week)

Use this before panel demo. Sync backend after every PHP change.

## Day 1–2 — Environment

```powershell
cd "C:\Users\nljhn\Downloads\Capstone 1 -Neil"
.\scripts\sync-backend-to-xampp.ps1
.\scripts\setup-smartflow.ps1
```

- [ ] XAMPP Apache + MySQL running
- [ ] `http://localhost/Smartflow/backend/backend/api/dev-api-health.php` → success
- [ ] Purge test data (localhost only): `dev-purge-demo-documents.php?all=1`
- [ ] `flutter run` on the phone/emulator you will use in defense

## Day 3 — Rehearse main story (Scenario A — **DV trail**, client priority)

**ENG → BUD → ACC** (use `accounting.staff` for ACC scans, not `accountant.main`)

| # | User | Action |
|---|------|--------|
| 1 | `engineering.staff` | New → **DV** → Register → OUT → **BUD** |
| 2 | `budget.staff` | IN → OUT → **ACC** |
| 3 | `accounting.staff` | IN → History timeline |
| 4 | `accountant.main` | Admin COA report (no scan) |

**Backup — Budget request (Scenario B):** see [DEMO-SCRIPT.md](DEMO-SCRIPT.md) Part 3. Use **Accept** (not Approve), **required-by date** on new requests.

**Optional:** Reject flow — Angel Reject with notes → Neil **declined** on Home hint + My requests.

Password: `smartflow123` (say: pilot only, not production).

## Day 4 — Panel materials

- [ ] Open `docs/design/use-cases/SMARTFLOW-USE-CASE-DIAGRAM.html` in browser (backup slide)
- [ ] `docs/defense/DEMO-SCRIPT.md` printed or on second screen
- [ ] One-liner limitations (see prior Q&A): movement support, not financial audit; pilot not full deploy

## Day 5 — What we fixed for defense

| Fix | Why it matters |
|-----|----------------|
| **IN only at OUT destination** | Stops wrong office receiving in the log |
| **BUD → ACC → ENG** in demo/docs | Matches LGU + routing suggestion |
| **My requests outcomes** | rejected / approved / fulfilled visible |
| **Home hint** on request updates | Requester sees decline without push notif yet |
| **Dev purge** | localhost or admin only |

## Known gaps (say honestly if asked)

- No push/SMS notification on reject (in-app status only)
- Scan discipline still required (staff can skip)
- Web admin dashboard = future phase
- Production: change passwords, `SMARTFLOW_ALLOW_DEV_TOOLS = false` in `config.php`

## Accounts (pilot)

| Role | Username |
|------|----------|
| ENG staff | `engineering.staff` |
| ENG head | `head.engineering` |
| Budget | `budget.staff` |
| HR | `hr.staff` |
| Accounting clerk (scans) | `accounting.staff` |
| Accountant / admin (COA) | `accountant.main` |
