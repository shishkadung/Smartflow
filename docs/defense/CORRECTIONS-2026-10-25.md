# Defense documents: corrections as of 25 October 2026

The older defense notes were written in September, before the safeguards, demo database and routing rules below existed. Use this page first. It overrides any command, account or route in `START-HERE`, `PRE-DEFENSE-BUKAS`, `DEMO-SCRIPT`, `DEMO-SCENARIOS-COMPLETE` and `SYSTEM-PANEL-RECOMMENDATIONS`. The current presentation material is the [six-department projector script](../client/SIX-DEPARTMENT-PROJECTOR-DEMO-SCRIPT.md) with its [sample-data guide](../client/DEMO-DATA-2026-10-22.md).

## Commands that no longer work (do not run or paste them)

| Old instruction | Current state |
|---|---|
| `scripts\setup-smartflow.ps1` | Retired. It stops with an error because it used to replace accounts and purge folders. |
| `dev-purge-demo-documents.php?all=1`, `dev-seed-demo-users.php`, `dev-replace-team-users.php`, `dev-reset-*.php`, `dev-api-health.php` in a browser | Maintenance scripts are refused over HTTP. They run only from the command line, with `ALLOW_DEV_TOOLS=true` in a development `.env` and `--allow-maintenance`. Never run a purge, reset or reseed against the working demo database. |
| `scripts\run-defense-demo.ps1` | Still starts, but only runs the read-only `fix-api.ps1` reachability check and prints reminders. |
| `scripts\sync-backend-to-xampp.ps1` as a routine "fix" | Code deployment is a separate, reviewed step: run it with `-WhatIf` first and expect it never to copy `.env`. It does not repair data problems. |
| `cd "...\Capstone -Neil"` or `"...\Capstone 1 -Neil"` | The project is at `C:\Users\nljhn\Downloads\SmartFlow`. |
| `thesis-work\2026-09-29_SmartFlow-Figures\...png` | That folder is not in this checkout. Export the figure again from the thesis documents or the Figma file. |
| `SMARTFLOW_ALLOW_DEV_TOOLS = false` "in config.php" | Maintenance is controlled by `APP_ENV` and `ALLOW_DEV_TOOLS` in the private `.env`; the HTTP route is closed regardless. |

Safe preparation: start XAMPP (Apache and MySQL), run `.\scripts\fix-api.ps1` (read-only), then open the web portal or app with an existing account. Build phone apps with `FORCE_LOGIN_ON_START=false` so a saved sign-in survives (see [Testing](../TESTING.md)).

## Accounts

The `smartflow123` team logins in the older notes (`kristofer.eng`, `angel.bud`, `neil.admin`, and so on) predate 22 October. The local demo database now has generic demo accounts whose credentials are in an access-restricted file under `backups/` and must stay off the projector and out of documents. A shared default password such as `smartflow123` must not exist on any deployed system. Use staff accounts for physical actions (register, OUT, IN, file); head and admin accounts are monitoring-only for custody.

## Routes and scope

- **Disbursement Voucher:** ENG → BUD → ACC → TRE → MAY → TRE, with an optional return to ACC. Treasury and the Mayor's Office are part of the system, not outside it.
- **Approved Budget:** the system completes the folder at ACC after BUD. The older "BUD → ACC → ENG" return is an open client decision (see the PRD's open decisions) and is not part of the completion rule. Scenario B in the older scripts ends with ACC → ENG; rehearse it first or end that demo at ACC.
- **Admin dashboard:** the web administrator pages exist (Dashboard, Custody reports, Users, Offices, Thresholds, QR monitor, System). They are not a future phase.
- **Known limits to state honestly:** no push/SMS (in-app status only), physical scan discipline is still required, and payment release is recorded on the request ticket, not executed by SmartFlow. The system has been verified with automated tests and sample data; office-level user acceptance testing and production hosting have not been done.
- **"Ready to deploy?"** Answer: pilot-ready software. A supported host, HTTPS, signed Android release, real accounts and the office acceptance run are still to do. See [Production deployment](../product/PRODUCTION-DEPLOYMENT.md).
