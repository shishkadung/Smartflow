# SmartFlow: final weeks plan (26 October to 12 November 2026)

Defense: **12 November 2026**. Prepared 26 October 2026. Scope for the defense is a demo-ready system, real UAT data and a finished manuscript. Production hosting (host, HTTPS, signed APK, new database with real accounts) is safe to do after the defense with the client; the questionnaire itself accepts a remote demonstration ([appendix](../thesis/appendix-iso-25010-survey.md)). The older defense notes contain retired commands: read [CORRECTIONS-2026-10-25.md](CORRECTIONS-2026-10-25.md) first.

## Done on 25–26 October

| Item | Evidence |
|---|---|
| Production configuration guard, web `.htaccess`, deployment guide | `scripts/test-production-config.php` 84 checks; isolated Apache check; [guide](../product/PRODUCTION-DEPLOYMENT.md) |
| Stale defense, README and technical docs corrected | [CORRECTIONS-2026-10-25.md](CORRECTIONS-2026-10-25.md), [DEFENSE-CHECKLIST.md](DEFENSE-CHECKLIST.md) |
| Full system snapshot before touching XAMPP | `backups/smartflow-system-20261026-001736-2a1619`, isolated restore verified (15 tables, 530 rows, QR key, uploads) |
| Reviewed code deployed to local XAMPP (22 files) | Backup `.runtime/code-sync-backups/20261026-001910-775`; 101 of 101 code files match source; `.env` and `.qr-secret` unchanged; unauthenticated probes 401 / 200 / 403 as expected |
| Local Git repository | First commit `722fa45`; secrets, backups, uploads and the 84 MB design PDF are excluded |
| Dependency audit | `npm audit --omit=dev`: 0 vulnerabilities. Two high advisories in the Vite dev server only (not in the built site); the dev server listens on all interfaces, so run `npm run dev` only on a trusted network |
| UAT scoring workbook | [UAT-ISO25010-Encoding.xlsx](../testing/UAT-ISO25010-Encoding.xlsx), formulas checked against an independent calculation |

## Schedule

| When | What | Who |
|---|---|---|
| 26–27 Oct | Sign in on web and phone with an existing account and walk through Dashboard, a folder lookup and Requests (smoke test after the XAMPP update) | You |
| 26–28 Oct | Ask the client and adviser for the open decisions: does Approved Budget end at ACC or return to ENG; what may other offices see; adviser approval of the Likert scale and the number of respondents | You |
| 27–31 Oct | Book respondents: the Municipal Accountant and a few heads and clerks (about 4 to 7). Choose live remote demo, on-site demo or recorded video, and say which in Chapter 4 and 5 | You |
| 28 Oct–4 Nov | Run the UAT with the [office pilot record](../testing/OFFICE-PILOT-2026-10-17.md) and the questionnaire; encode answers in the workbook the same day. UAT must finish by 4 November so Chapter 5 and 6 can be written | You and the team |
| 4–6 Nov | Write Chapter 5 (Tables 5.2 and 5.4 from the workbook, discussion, limitations) and Chapter 6; replace figure placeholders with screenshots | You; draft help available |
| **6 Nov** | **Code freeze.** No source changes after this date unless a defect blocks the demo. Commit the final state | Everyone |
| 6–9 Nov | `scripts\backup-system.ps1` then `scripts\verify-system-backup.ps1`; two full rehearsals on the device you will bring; backup screenshots of every step | You |
| 10–11 Nov | Final rehearsal only. Charge devices, close other apps, check hotspot or network, keep the backup snapshot path handy | You |
| 12 Nov | Defense | |

## Rules until the defense

- Do not purge, reseed or restore the working demo database. Rehearse with the prepared `DEMO -` records ([sample-data guide](../client/DEMO-DATA-2026-10-22.md)).
- After 6 November change nothing in `backend`, `web` or `mobile` without a blocking reason; commit every change (`git commit`) so you can roll back.
- Phone and tablet builds use `FORCE_LOGIN_ON_START=false` so the saved sign-in survives (see [Testing](../TESTING.md)).
- Say what was and was not done: tested with automated checks and sample data; user acceptance results are only those collected from real respondents; not deployed to a production host.

## Still open (not blockers for the defense)

Production host and HTTPS; Android release key and signed APK; a fresh production database with real accounts (never the demo database); direct-lookup visibility policy; Approved Budget end point; exceptional DV routes; shared-device recent folders; report archiving; the 15-year retention policy; the Vite dev-server advisories (upgrade after the defense, with the full test suites).
