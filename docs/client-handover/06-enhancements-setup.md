# Enhanced queue, recovery, and exports — activation notes

The web and Flutter source in the original folder includes the October 3 enhancements. The existing XAMPP API was updated with explicit user approval on October 3; 16 live API checks passed. Review [the validation report](../testing/enhancements-2026-10-03.md) for evidence and remaining mail/phone checks.

## Apply the prepared local API update

The approved XAMPP update is complete. Its historical QR key was replaced, so **download existing QR labels again from Documents**. The live API accepts new labels and rejects labels signed with the old key.

From the project root, this command only validates the target path, source files, and explicitly configured QR key:

```powershell
./scripts/sync-enhancements-to-xampp.ps1 -ValidateOnly
```

For a later approved update, the same script without `-ValidateOnly` selectively copies 17 API files to `C:\xampp\htdocs\Smartflow\backend\backend\api`. It preserves database configuration, uploads, and existing environment values, and adds missing mail settings migrated from source. If a weak secret is explicitly configured in `QR_SIGNING_SECRET`, preflight stops before copying files so IT can replace that setting. A strong server signing key is retained; an absent or historical weak `.qr-secret` file is upgraded to a random persistent key. Download affected QR labels again after an upgrade.

Retain the private signing key across later deployments and backups. All API instances serving the same documents must use the same key. Do not publish `.env`, `.qr-secret`, or the API rate-limit cache. The included Apache rules deny HTTP access to these files.

## Recovery email configuration

Set these values privately in the API `.env` using credentials from your mail provider account:

```dotenv
APP_ENV=production
ALLOW_DEV_TOOLS=false
MAILTRAP_API_TOKEN=<live sending token>
MAILTRAP_API_URL=https://send.api.mailtrap.io/api/send
MAIL_FROM_ADDRESS=<sender on a verified sending domain>
MAIL_CA_BUNDLE=<optional absolute path to a trusted CA bundle>
```

Use values without surrounding quotes, consistent with this project's environment parser. Preserve the actual database and allowed web-origin settings. If PHP already has a trusted CA store, leave `MAIL_CA_BUNDLE` blank. TLS verification must remain enabled.

The currently configured sandbox URL returned 404 and has no inbox ID. [Mailtrap sandbox requests](https://docs.mailtrap.io/developers/email-sandbox/send-test-emails) require an inbox ID and capture test messages inside Mailtrap. For delivery to an owned Gmail inbox, use [Mailtrap live email sending](https://docs.mailtrap.io/developers/email-sending) with a valid sending token and verified sender.

After configuring live sending, request recovery for a controlled test account, confirm actual inbox delivery, enter the received code, and confirm the old session cannot access protected records. Production recovery messages intentionally do not reveal whether an account exists or whether provider delivery was accepted. A successful recovery-request screen alone does not prove email delivery.

## Build for the physical Android phone

The rebuilt debug APK targets the Android emulator by default. For a phone on the same Wi-Fi as the XAMPP PC, rebuild from `mobile/flutter` with the PC's real LAN address:

```powershell
flutter build apk --debug --dart-define=API_BASE=http://<PC-LAN-IP>/Smartflow/backend/backend/api
```

The phone must be able to reach that API address. After the backend update, check login, document receiving/forwarding, camera QR lookup, CSV save and opening, Print / Save PDF, recovery code entry, and profile photo selection/removal. Test losing and restoring connectivity: existing document data should remain visible, while handoff actions remain unavailable until a fresh read succeeds. Check that the printed report's totals and date range match the selected period.

## Day-to-day changes

Use **Urgency** to find overdue and early-due documents first, or **Longest wait** for waiting folders. The journey shows recorded custody events and the expected receiving office. Refresh before handing over a folder when the portal displays a connection warning.

Accounting administrators can use **Download CSV** and **Print / Save PDF** in custody reports. Android CSV export opens a file picker; printing opens the system print flow. Administrator QR monitoring also offers a real scan-audit CSV download. Printed custody summaries supplement the financial reports required by your office.
