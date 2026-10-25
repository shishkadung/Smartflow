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
4. Sign in with an existing approved account. The older shared `smartflow123` logins do not exist in the local demo database, and a shared default password must never exist on a deployed system.

Vite proxies `/smartflow-api` → `http://localhost/Smartflow/backend/backend/api`.

Camera QR scan needs **localhost or HTTPS**. On a phone over HTTP LAN, type/paste the QR text or Document ID instead.

## UX notes (aligned with Flutter)

- Top-bar **?** = page help (fixed slot)
- Office code badge → **Profile**
- Nav: Home · Scan · Register · Requests · History · Alerts (+ admin Users / COA / QR)
- Admin home stays quiet — sign-up CTA only when pending

## Production build

The portal is a static build served from the site root, with the API at `/api` beside it. Set the API base at build time (`public/.htaccess` is copied into `dist/` and provides the page-refresh fallback and headers):

```powershell
cd web
Copy-Item .env.production.example .env.production   # VITE_API_BASE=/api
npm ci
npm run build
```

Build in PowerShell or from `.env.production`, not an inline `VITE_API_BASE=/api` in Git Bash, which rewrites `/api` into a Windows path. Upload the contents of `dist/`, including the hidden `.htaccess`. Without `VITE_API_BASE` the built portal calls `/smartflow-api`, which exists only behind the Vite dev proxy. Full steps, Apache requirements and verification checks are in [Production deployment](../docs/product/PRODUCTION-DEPLOYMENT.md#web-portal-deployment).
