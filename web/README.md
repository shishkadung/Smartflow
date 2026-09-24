# SmartFlow web (React)

Browser app for **iPhone Safari, Android Chrome, and desktop**. Same PHP API as Flutter — secured QR, IN/OUT scans, requests, dashboards.

Pilot offices: **ENG · HR · BUD · ACC · TRE · MAY**. DV path: ENG → BUD → ACC → TRE → MAY → TRE.

## Run locally

1. XAMPP Apache + MySQL on (API health OK).
2. From this folder:

```powershell
cd web
npm install
npm run dev
```

3. Open **http://localhost:5173**
4. Pilot login: `engineering.staff` / `smartflow123` (also `treasury.staff`, `accountant.main`, …)

Vite proxies `/smartflow-api` → `http://localhost/Smartflow/backend/backend/api`.

Camera QR scan needs **localhost or HTTPS**. On a phone over HTTP LAN, type/paste the QR text or Document ID instead.

## UX notes (aligned with Flutter)

- Top-bar **?** = page help (fixed slot)
- Office code badge → **Profile**
- Nav: Home · Scan · Register · Requests · History · Alerts (+ admin Users / COA / QR)
- Admin home stays quiet — sign-up CTA only when pending

## Production build

```powershell
cd web
npm run build
```

Copy `web/dist` to the server (or XAMPP `htdocs/smartflow-web`). Set `VITE_API_BASE` to the live API URL before building:

```powershell
$env:VITE_API_BASE="https://your-domain/Smartflow/backend/backend/api"
npm run build
```
