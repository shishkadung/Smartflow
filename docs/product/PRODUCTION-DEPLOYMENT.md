# SmartFlow Production Deployment Guide

This guide covers deploying SmartFlow to a production environment for the Municipality of Urbiztondo.

**25 October application hardening:** Android release builds require the release signing configuration and no longer fall back to the debug key or an unsigned release. Keep `keystore.properties` and keystore files private and backed up; debug builds remain available without them. Release resources deny cleartext without development-host exceptions. `ENV=production` now honors an explicit `API_BASE` and requires an HTTPS base URL without embedded credentials, query or fragment. The existing intended hostname remains the default. Confirm the actual host before building; no server was provisioned or updated by these source changes.

**25 October configuration and web hardening:** `APP_ENV=production` now fails closed. `config.php` (through `production-config-guard.php`) answers "Server configuration is incomplete" and does no database work until CORS lists exact https origins, `LOG_LEVEL` is info/warning/error, `ALLOW_DEV_TOOLS` is off and the database user is not `root` and has a password. A web request to a non-local host with a missing `.env` or an unset/unrecognised `APP_ENV` (for example the typo `prod`) is refused the same way, so an unprovisioned server cannot fall back to the wildcard-CORS, debug-logging, root-database development defaults. `backend/backend/api/.env.production.example` is the template. The web build now ships `.htaccess` (single-page-app fallback, API and certificate paths excluded, dotfile blocking, security and cache headers) and has a deployment section below. Source and tests only: nothing was deployed, and no host was provisioned.

Updated **23 October 2026** for the PHP security update. The local XAMPP runtime is now **PHP 8.3.36, Windows VS16 x64 Thread Safe**, verified through Apache's actual `apache2handler` SAPI. PHP 8.3 keeps the existing phpMyAdmin 5.2.1 within the PHP range currently published for the 5.2 branch, while PHP 8.2 reaches upstream security end of life on 31 December 2026. A separate hosting deployment must verify all applications sharing its server. See [phpMyAdmin requirements](https://www.phpmyadmin.net/downloads/) and [PHP support dates](https://www.php.net/supported-versions.php).

The configured production hostname below is an **intended target**, not proof of deployed hosting. Current local code deployment uses `C:\xampp\htdocs\Smartflow\backend\backend\api`; the local sync helper does not install PHP or configure a production host. Confirm the actual hosting operator, runtime, paths and HTTPS configuration separately. Read [Architecture](../ARCHITECTURE.md), [Security](../SECURITY.md) and the [dated deployment checklist](../../.runtime/php-security-update-2026-10-23/deployment-checklist.md) before applying these examples.

Local activation evidence records all 38 prior extensions plus Apache's SAPI module, phpMyAdmin HTTP 200, verified outbound HTTPS through cURL, and `session.upload_progress.enabled=0`. All 15 recorded database-table hashes, session rows and 102 protected API files (including 97 PHP files) remained unchanged; the verification probe was removed. The prior runtime and binding configuration remain outside the web root at `C:\xampp\php-backup-20261023-8.2.12` and `C:\xampp\php-upgrade-config-20261023`. See [activation result](../../.runtime/php-security-update-2026-10-23/activation-result.json), [web runtime verification](../../.runtime/php-security-update-2026-10-23/runtime-active-web.json) and [preservation evidence](../../.runtime/php-security-update-2026-10-23/preservation.json). These local checks do not establish a separate production host's security.

## Pre-Deployment Checklist

### 1. Server Requirements
- **Web Server**: A supported, patched Apache 2.4 installation or a separately verified equivalent PHP host. Match Windows PHP architecture and TS/NTS build to the serving process; Apache `mod_php` requires Thread Safe. [PHP Windows installation](https://www.php.net/manual/en/install.windows.manual.php)
- **PHP**: A supported branch with current security fixes. The activated local version is 8.3.36; PHP 8.3 receives upstream security fixes through 31 December 2027. The source's language floor of 8.1 does not make unsupported PHP 8.1 a deployment choice. Recheck newer fixed point releases when deploying.
- **Database**: A supported MySQL/MariaDB deployment tested against SmartFlow's actual runtime schema and transactions; the historical 5.7/10.3 version floors are not current hosting acceptance.
- **SSL Certificate**: Valid HTTPS certificate (required for production)
- **PHP Extensions**: PDO MySQL, JSON, mbstring, fileinfo (avatar MIME validation), and cURL (configured email delivery). Verify TLS/CA support for outbound HTTPS and any additional phpMyAdmin requirements independently.

The [21 October PHP advisory](https://www.php.net/archive/2026.php#2026-10-21-5) fixes critical CVE-2026-109618/CVE-2026-109619 in 8.2.35, 8.3.36, 8.4.27 and 8.5.12 for their respective branches. The [23 October follow-up](https://www.php.net/archive/2026.php#2026-10-23-1) recommends `session.upload_progress.enabled=0` pending its regular fix. Verify this in the effective **web SAPI** configuration after restart, including applicable INI overrides; CLI `php -v` alone does not verify the serving runtime. Do not publish `phpinfo()` to collect this evidence.

### 2. Security Configuration
- [ ] For a new installation only, create the server's private `.env` from `backend/backend/api/.env.production.example` and review every value; never copy the development `.env` (it holds `APP_ENV=development`, `ALLOW_DEV_TOOLS=true`, wildcard CORS and debug logging). Preserve the existing `.env` during updates
- [ ] Set `APP_ENV=production` and `APP_TIMEZONE=Asia/Manila`
- [ ] Set `ALLOW_DEV_TOOLS=false` in `.env`
- [ ] Use a dedicated database account (not `root`) with a strong password in `.env`, limited to the SmartFlow database (SELECT, INSERT, UPDATE, DELETE, CREATE, ALTER, INDEX, REFERENCES: the runtime still checks and creates schema objects)
- [ ] Set `CORS_ALLOWED_ORIGINS` to the exact https web origin(s), comma separated, no trailing slash (not `*`)
- [ ] Preserve or securely provision the stable `QR_SIGNING_SECRET` / protected `.qr-secret`; replacing it invalidates existing folder labels. Authentication uses random bearer tokens whose hashes are stored in `auth_tokens`; the example's legacy `TOKEN_SECRET` is not used by the current token implementation
- [ ] Set `LOG_LEVEL=error` or `warning` (not `debug`)
- [ ] Confirm private-file denial and forwarding of authentication headers for JSON, multipart, report exports and labels; exact CORS origins do not replace authentication

The guard is a deployment safety net, not an access control. When it rejects the configuration, every API call returns HTTP 500 with a generic message and the web server error log names the offending settings (names only, never values): `CORS_ALLOWED_ORIGINS`, `LOG_LEVEL`, `ALLOW_DEV_TOOLS`, `DB_USER`, `DB_PASS`, `APP_ENV` or `.env`. Fix the `.env` and retry; do not weaken the guard. Development, test and local (`localhost`, loopback, private-IP, `.test`) use is unchanged. The guard does not check transport: confirm HTTPS, header forwarding and private-file denial on the host separately. Regression suite: `scripts/test-production-config.php` (see [Testing](../TESTING.md)).

### 3. Database Setup
Current `config.php` invokes schema bootstrap, including creation/compatibility checks for `auth_tokens`. The separate SQL file is not a required recurring deployment step and does not replace the full runtime schema. Review schema needs on an isolated copy before a new installation or schema change; current runtime bootstrap needs corresponding privileges. A PHP runtime update must preserve the existing database, accounts, token rows and records, without reimporting, reseeding or restoring them.

### 4. Android App Signing
```bash
# Generate release keystore (one-time)
cd mobile/flutter/android
keytool -genkey -v -keystore smartflow-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias smartflow

# Copy keystore.properties.example to keystore.properties
# Fill in the actual values from keystore generation
```

Do not generate a replacement key for an existing distributed application: preserve its signing identity and update continuity. Missing signing credentials must stop a release build. Check the final APK/AAB certificate against the approved release-key fingerprint before distributing it. An example file or successful debug build is not signing acceptance.

## Deployment Steps

### Backend Deployment

For updates, back up the prior runtime/binding configuration and approved changed code, verify a complete recovery package, and stage/test the new PHP before a bounded web-server restart. Preserve `.env`, stable QR material, uploads and database/session records. Do not copy example settings over existing configuration or rotate keys as part of a runtime update. Record the archive hash and the activated web SAPI version/settings separately from application code deployment.

This local Apache installation needed matching PHP `brotlidec.dll` and `libssh2.dll` loaded before `php8ts.dll`, while retaining Apache's own DLLs. Its `OPENSSL_CONF` server setting now names `C:/xampp/php/extras/ssl/openssl.cnf`; no registry or global environment change was made. Carry these as inspected local binding requirements, not a universal recipe for other hosts. Explicit-config RSA creation/sign verification and a symmetric round trip passed, but default RSA key creation without the explicit configuration remained false; do not claim universal default OpenSSL configuration acceptance.

1. **Upload Files**
```bash
# Example NEW hosting path; confirm the actual target first.
# Upload the CONTENTS of backend/backend/api/ to the "api" folder beside the web portal:
#   backend/backend/api/*  ->  /var/www/html/smartflow/api/
# Deploy reviewed API code plus its server rules (.htaccess) and the two label scripts (qr-*.js).
# Preserve runtime .env, .qr-secret, uploads, logs and backups separately.
#
# Do NOT upload from the development tree:
#   .env, .qr-secret      development configuration and signing key (a new install creates its own)
#   cache/, logs/, uploads/   local rate-limit files, logs and avatars
#   dev-*.php except dev-tools-policy.php, and users-email-migration.php
#                         maintenance scripts; refused over HTTP and by .htaccess, and not needed on a server.
#                         config.php requires dev-tools-policy.php, so that one file must stay
#   *-migration.sql       old migrations; the runtime creates and repairs its schema
#   backups/, .runtime/, docs/, scripts/, node_modules   never belong on the web host
# Intended example target: /var/www/html/smartflow/api/
```

2. **Configure Environment**
```bash
cd /var/www/html/smartflow/api
# New installation only: create .env if none exists, using private provisioning.
# Existing installation: retain its reviewed .env and apply only intended changes.
nano .env
# Update all values for production
```

3. **Set Permissions**
Apply permissions for the confirmed host/service account. Keep code read-only to the runtime where practical, give only required write access to runtime storage, and protect `.env`, `.qr-secret`, uploads and backups from unrelated users. Do not apply a recursive public-read permission recipe over existing private files. Verify HTTP private-file denial separately from filesystem permissions.

4. **Configure Apache**
```apache
# VirtualHost configuration
<VirtualHost *:443>
    ServerName smartflow.urbiztondo.gov.ph
    DocumentRoot /var/www/html/smartflow
    
    SSLEngine on
    SSLCertificateFile /path/to/cert.pem
    SSLCertificateKeyFile /path/to/key.pem
    
    # The portal's .htaccess (SPA fallback, headers) and the API's .htaccess both need AllowOverride.
    <Directory /var/www/html/smartflow>
        AllowOverride All
        Require all granted
    </Directory>
    <Directory /var/www/html/smartflow/api>
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
```

5. **Test API Health**
```bash
# Use the confirmed hosting URL. No login or maintenance action is submitted.
curl -i https://smartflow.urbiztondo.gov.ph/api/auth-session.php
# Expected without credentials: 401 JSON, not a server-generated HTML error.
```

Privately verify the actual serving PHP version, extensions and `session.upload_progress.enabled=0`, effective private-file denial, and header forwarding. Do not probe reset/restore/maintenance routes, even with HEAD. Fresh acceptance must distinguish local checks from production-hosting evidence.

### Web Portal Deployment

The portal is a static build served from the site root (`https://HOST/`) with the API beside it at `https://HOST/api`; this is also the Android app's default production address. A different layout needs a different `VITE_API_BASE` and the equivalent rewrite rules.

1. **Build** on a build machine with Node and the committed lockfile. Use PowerShell or a `.env.production` file: Git Bash rewrites a value such as `/api` into a Windows path and compiles that into the bundle.
```powershell
cd web
Copy-Item .env.production.example .env.production   # VITE_API_BASE=/api; edit if the API path differs
npm ci
npm run build
```
`VITE_API_BASE` is compiled into the JavaScript. Without it the portal calls `/smartflow-api`, which exists only behind the Vite development proxy. Confirm the build used the intended base (it lists a file when the bundle contains `/api`):
```powershell
Select-String -Path dist\assets\*.js -Pattern '/api`\.replace' -List | Select-Object Filename
```
2. **Upload the contents of `web/dist`** to the site root, including the hidden `.htaccess` (Vite copies it from `web/public/.htaccess`). FTP clients and file managers often hide dotfiles; check it arrived.
3. **Apache** needs `mod_rewrite` and, recommended, `mod_headers`, with `AllowOverride All` on the site root (see the VirtualHost above). The file provides:
   - a single-page-app fallback so refreshing `/documents` or opening a deep link serves `index.html`; `api/` and `.well-known/` are excluded, and a path that looks like a file (for example a removed `/assets/old.js`) stays a real 404;
   - 403 for dotfiles and dot-folders such as `.vite/manifest.json`;
   - `nosniff`, `X-Frame-Options: SAMEORIGIN`, a referrer policy and a permissions policy that allows the camera for this origin only (the QR scanner);
   - one-year immutable caching for hashed assets, and revalidation for `index.html` and the unhashed `qr-*.js`/icon files so a release is picked up.

   Another web server (nginx, IIS) must reproduce these rules. Add `Strict-Transport-Security` only after HTTPS works for every host name. Browser camera scanning needs HTTPS (or `localhost`).
4. **Verify** without signing in (replace `HOST`):
```powershell
curl.exe -i https://HOST/documents                 # 200 text/html: the portal, not a server 404
curl.exe -i https://HOST/assets/missing-file.js    # 404, not HTML
curl.exe -i https://HOST/.htaccess                 # 403
curl.exe -i https://HOST/api/auth-session.php      # 401 JSON from the API
```
Then sign in with a real account, open a deep link (for example the Requests page) and refresh it. The `.htaccess` was exercised on an isolated Apache 2.4 instance with synthetic files on 25 October 2026 (deep links, API and certificate paths, missing assets, dotfiles, headers and caching); that is not evidence about your host.

### Mobile App Deployment

1. **Build Release APK**
```bash
cd mobile/flutter
flutter build apk --release --dart-define=ENV=production --dart-define=API_BASE=https://your-confirmed-host.example/api --dart-define=FORCE_LOGIN_ON_START=false
```

2. **Build App Bundle (for Play Store)**
```bash
flutter build appbundle --release --dart-define=ENV=production --dart-define=API_BASE=https://your-confirmed-host.example/api --dart-define=FORCE_LOGIN_ON_START=false
```

3. **Distribute**
- Upload APK to internal testing or distribute directly
- For Play Store: Upload app bundle to Google Play Console

### Database Backup Setup

The checked-in system tools currently use reviewed Windows/XAMPP paths; configure and verify an intended hosting target separately. A system snapshot includes database, private environment, stable QR key and uploads. A database-only dump is insufficient for full-system recovery.

```powershell
.\scripts\backup-system.ps1
.\scripts\verify-system-backup.ps1 -Snapshot "backups\<created-system-snapshot>"
```

Verification imports only to its own generated temporary schema, checks the snapshot and removes that schema; it never restores the live database. Backup creation also imports the actual dump to build consistent manifest hashes and continuity-folder evidence, so the backup account needs create/drop permission and scratch capacity for one temporary restore. An empty-folder installation reports original-folder QR verification as not applicable while still checking schema, data, key and uploads. Current automated evidence uses synthetic snapshots without mutating operational records, accounts or sessions; production capacity, concurrent DDL and independently changing uploads still need their own acceptance. See [Testing](../TESTING.md), the [stabilization matrix](../testing/STABILIZATION-MATRIX-2026-10-16.md) and the [implementation report](../../.runtime/stabilization-2026-10-16/report.md).

For scheduling, use the intended host's scheduler with these tested platform requirements; a Linux crontab entry invoking a Windows `.ps1` is not a validated deployment procedure. The legacy `backup-database.ps1` and manually confirmed `restore-database.ps1` are database-only tools. Restore now preserves known-good UTF-8 SQL bytes, but Unicode capture by the legacy backup wrapper is not established by that restore test. A live recovery plan must restore the matching database, configuration, signing key and uploads together after a verified isolated rehearsal.

## Post-Deployment

### 1. User Account Setup
- For a new installation, replace demo/default credentials and provision approved LGU users with their proper office roles
- An existing-runtime update preserves accounts and sessions; do not reset passwords or re-create users as a verification step. Password changes and deactivation intentionally revoke sessions

### 2. Monitor Logs
Review restricted server logs privately and record sanitized outcomes. Do not paste raw logs, environment values, session tokens or personal data into deployment reports. Keep production diagnostic verbosity limited by the reviewed `LOG_LEVEL`.

### 3. Rate Limiting
- The authenticated request gate defaults to 60 writes and 240 reads per minute per user, configured with `RATE_LIMIT_PER_MINUTE` and `RATE_LIMIT_READ_PER_MINUTE`.
- Public endpoints do not all share that gate. Rate-limit files are local to the server, so this is not a distributed or universal limit.

### 4. Token Management
- Tokens expire after 24 hours by default
- Users will need to re-login after token expiry
- Revoked tokens are immediately invalidated

## Security Notes

### Critical Security Settings
1. **HTTPS Required**: Production mode validates the configured HTTPS API, and Android release resources deny cleartext without development-host exceptions. Debug resources retain the reviewed local endpoints. iOS ATS exceptions still require review before a separate iOS release. Verify the actual release artifact and host transport separately
2. **Dev Tools Disabled**: All `dev-*.php` endpoints return 403
3. **CORS Restricted**: Configured origins control browser response access; every protected API still needs its own authentication and authorization
4. **Secure Tokens**: Stored in database with SHA-256 hashing
5. **Rate Limiting**: Prevents API abuse

### What to Keep Secret
- `.env` file (contains database credentials)
- `.qr-secret` / configured QR signing material (retain across updates)
- `keystore.properties` (contains signing keys)
- `smartflow-release.jks` (the keystore file itself)
- Database backups (contain user data)

### Regular Maintenance
- Review logs weekly for suspicious activity
- Apply security releases promptly and review the supported PHP branch and any newer point release at deployment time
- Backup database before any schema changes
- Rotate SSL certificates before expiry

## Troubleshooting

### API Returns 500 "Server configuration is incomplete"
- The production configuration guard refused the `.env`. Read the web server error log for the setting names it lists (`CORS_ALLOWED_ORIGINS`, `LOG_LEVEL`, `ALLOW_DEV_TOOLS`, `DB_USER`, `DB_PASS`, `APP_ENV`, `.env`) and compare the file with `.env.production.example`
- `.env` must sit in the API folder beside `config.php`, use plain `NAME=value` lines (no comment after a value) and set `APP_ENV=production` exactly
- A `Database connection failed` message is different: the guard passed and the database host, name, user or password is wrong

### Portal Page Refresh or Deep Link Shows 404
- The portal's `.htaccess` is missing from the site root (hidden file not uploaded), `mod_rewrite` is off, or `AllowOverride` is `None`. See Web Portal Deployment above

### API Returns 403
- Review the endpoint's session, active-account, role, office and workflow requirements. `ALLOW_DEV_TOOLS=false` is expected in production and must not be enabled to bypass a normal denial
- Check CORS separately for browser response-access problems; it is not the normal API role-authorization mechanism

### App Won't Connect
- Ensure HTTPS is properly configured
- Check `network_security_config.xml` allows your domain
- Verify `ENV=production` in build command

### Database Connection Failed
- Check database credentials in `.env`
- Verify MySQL service is running
- Check firewall allows localhost connections

## Rollback Procedure

For a PHP/application-code failure, restore the recorded prior runtime binding and reviewed code package, then verify the serving process and normal reads. Preserve the current database, private settings, QR key, uploads and sessions. A runtime rollback does not require a database restore.

A local Git repository exists since 26 October 2026 (no remote; secrets, backups, uploads and local evidence are ignored): tag the commit you build the release from and keep the system snapshot (`scripts\backup-system.ps1`) beside it. There is no earlier release tag. The local XAMPP sync target is not a production rollback tool.

If separate data recovery is intentionally required, first verify an isolated full-system restore using the matching database, private configuration, QR key and uploads. Restoring an operational database is a distinct consequential action, not a routine deployment repair.

Native review updates preserve app data and explicitly set `FORCE_LOGIN_ON_START=false`. Do not uninstall, clear data or switch accounts merely to validate the PHP change. Release signing and production API configuration require their own checks.

## Support Contact

For deployment issues:
- Technical: smartflow2k26@gmail.com
- Municipal IT: [LGU IT Contact]
