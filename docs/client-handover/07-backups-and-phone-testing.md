# System backups and Android phone testing

## Create and verify a complete system snapshot

From the original project root:

```powershell
./scripts/backup-system.ps1
./scripts/verify-system-backup.ps1 -Snapshot './backups/<snapshot-folder>'
```

The first command captures the running XAMPP database, API environment, QR key, and uploads. The second restores that snapshot into a new temporary database, compares table structures and all row data, checks QR signature continuity and copied upload files, then removes the temporary database. It does not replace the live database or live API configuration.

The current verified snapshot is `backups/smartflow-system-20261003-055437-aeff3f`. Backups include credentials and user data, so keep this folder private. It is ignored by Git and restricted to the current Windows user and SYSTEM. Keep a protected off-PC copy as well. Existing `backup-database.ps1` and `restore-database.ps1` are older database-only tools; use the new system snapshot tools for a complete recovery check. Actual live disaster recovery remains a separate maintenance operation with a backup of the current state and explicit approval.

Do not rotate or discard the QR key during recovery. Restoring the matching key preserves the signatures of existing labels, while normal QR expiry still applies. Restore the matching upload directory along with the database so profile image paths resolve.

## Install the phone test APK

Use `mobile/flutter/build/app/outputs/flutter-apk/app-phone-debug.apk`. This build uses:

```text
http://192.168.1.10/Smartflow/backend/backend/api
```

Connect the phone to the same Wi-Fi as this PC, keep XAMPP Apache and MySQL running, and first verify that the phone can open the API's public offices URL:

```text
http://192.168.1.10/Smartflow/backend/backend/api/offices-list.php
```

Then install the APK and check these flows using a controlled test account and folder:

- Sign in, close/reopen the app, and confirm the session persists.
- Open Documents and check incoming, held, forwarded, and completed trays.
- Scan a newly downloaded QR label with the physical camera.
- Forward the test folder, receive it with actual-folder confirmation, and check the recorded journey.
- Lose and restore connectivity; custody actions must wait for a fresh record.
- Save a CSV using the Android file picker and open it with a spreadsheet app.
- Open Print / Save PDF and check period, totals, office scope, and preparer.
- Select, save, and remove a profile photo.

If the PC address changes, rebuild from the project root:

```powershell
./scripts/build-phone.ps1
```

Or provide an explicit API address:

```powershell
./scripts/build-phone.ps1 -ApiBase 'http://<PC-LAN-IP>/Smartflow/backend/backend/api'
```

The helper creates a separate `app-phone-debug.apk` while retaining the previous `app-debug.apk`. Email delivery setup is deferred; do not treat a successful recovery-request screen as proof of inbox delivery.
