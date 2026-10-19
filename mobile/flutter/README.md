# SmartFlow Flutter

Rebuild aligned with **Capstone SmartFlow.pdf** (clerk · head · admin flows).

## Setup

1. Install [Flutter SDK](https://docs.flutter.dev/get-started/install), version **3.44.0 or newer** with **Dart 3.12.0 or newer**. The current dependency lock was validated on Flutter 3.44.0 / Dart 3.12.0.
2. From this folder:

```bash
flutter create . --project-name smartflow --org com.urbiztondo
flutter pub get
```

If `flutter create` asks to overwrite files, choose to keep existing `lib/` and merge Android config.

3. Edit API URL in `lib/config/api_config.dart` or:

```bash
flutter run --dart-define=API_BASE=http://10.0.2.2/your-path/backend/backend/api
```

4. Seed backend: run `..\..\scripts\setup-smartflow.ps1` or open `dev-seed-demo-users.php` once (accounts only — no sample documents).

## Pilot logins

| Username | Role |
|----------|------|
| kristofer.eng | Clerk |
| neil.eng.head | Head |
| neil.admin | Admin |

Password: `smartflow123`

Dependency versions, compatibility changes, and validation results are recorded in [the October 2, 2026 upgrade report](../../docs/testing/flutter-dependency-upgrade-2026-10-02.md).
