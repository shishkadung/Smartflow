# SmartFlow — Client Handover Pack

Documents for the Municipality of Urbiztondo (Municipal Accountant's Office and the participating offices).

## What's in this folder

| File | For | Contents |
|---|---|---|
| [01-getting-started.md](01-getting-started.md) | Everyone | What SmartFlow does, offices and roles, sign in, request access, password reset, navigation, profile |
| [02-clerk-guide.md](02-clerk-guide.md) | Clerks (staff) | Daily routine, Register, Scan (Mark IN / OUT / Return), Requests, History, Alerts |
| [03-department-head-guide.md](03-department-head-guide.md) | Department Heads | Office overview and queue, Analytics, follow-ups |
| [04-admin-guide.md](04-admin-guide.md) | Municipal Accountant / Admin | Dashboard, Users, Offices, Thresholds, COA reports, QR monitor, System |
| [05-troubleshooting.md](05-troubleshooting.md) | Everyone | Messages and what to do |
| [06-enhancements-setup.md](06-enhancements-setup.md) | Admin / LGU IT | Enhanced queues and exports, mail setup, API activation, and physical-phone checks |
| [07-backups-and-phone-testing.md](07-backups-and-phone-testing.md) | Admin / LGU IT | Complete system snapshots, isolated restore verification, and the phone test APK |
| [reference/SYSTEM-TEST-REPORT-2026-09-28.md](reference/SYSTEM-TEST-REPORT-2026-09-28.md) | Admin / LGU IT | System test results |
| [reference/SmartFlow_Use_Case_Diagram.png](reference/SmartFlow_Use_Case_Diagram.png) | Admin / LGU IT | What each role can do |
| `images/` | — | Screenshots used in the guides (sample data) |

**Suggested printouts:** every user gets Part 1 + Part 5, plus the guide for their role.

---

## Team checklist before handing this over

These are for the SmartFlow team, not the client. Remove this section from the copy you give them.

- [x] **Web "Open printable label" / "Copy print link"** now include the sign-in token (fixed 2026-10-01 in `web/src/api.js`). Rebuild and redeploy the web portal so the LGU gets the fix.
- [ ] **Optional: add a "Reprint label" button** in History (web + Android). Today a label can only be printed right after registering; expired or lost labels can only be worked around by typing the Document ID.
- [ ] **Remove demo and test accounts** (for example `neil.admin`, `neil.acc.staff`, and the `neil.*.head` accounts listed in the test report) and any account still on the default password. Create the real Admin account during setup and hand over the login in person.
- [ ] **Fresh secrets on the LGU server:** new `.env` from `.env.example` (database password, `TOKEN_SECRET`, `APP_ENV=production`). Never give the team's own `.env`.
- [ ] **Deployment guide:** `docs/product/PRODUCTION-DEPLOYMENT.md` is not included yet. It does not cover deploying the web portal, mixes Linux and Windows commands, and mentions the default demo password. Finalize it for LGU IT before adding it here.
- [ ] **Android signing:** agree on who keeps the release keystore and its passwords if the LGU will maintain the app.
- [ ] **Support contacts:** fill in the section below.
- [ ] **Export to PDF** for printing (open each file in Markdown preview and print to PDF, or convert with Pandoc).

---

## Support contacts

| For | Contact |
|---|---|
| Account approval, roles, time limits | Municipal Accountant / SmartFlow Admin: ____________________ |
| Server, network, backups | LGU IT: ____________________ |
| SmartFlow development team | smartflow2k26@gmail.com |
