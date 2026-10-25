# SmartFlow Flutter

Rebuild aligned with **Capstone SmartFlow.pdf** (clerk · head · admin flows).

## Setup

1. Install [Flutter SDK](https://docs.flutter.dev/get-started/install), version **3.44.0 or newer** with **Dart 3.12.0 or newer**.2. From this folder:

```bash
flutter create . --project-name smartflow --org com.urbiztondo
flutter pub get
```

If `flutter create` asks to overwrite files, choose to keep existing `lib/` and merge Android config.

3. Edit API URL in `lib/config/api_config.dart` or:

```bash
flutter run --dart-define=API_BASE=http://10.0.2.2/your-path/backend/backend/api
```

4. Backend: use the existing API and accounts. `setup-smartflow.ps1` is retired and `dev-seed-demo-users.php` no longer runs over HTTP; check reachability with `..\..\scripts\fix-api.ps1` (read-only).

## Accounts

Sign in with an existing approved account (clerk, head or admin). The older shared `smartflow123` logins do not exist in the local demo database, and a shared default password must never exist on a deployed system.

## Release build

A release APK/AAB needs the private signing key (`android/keystore.properties`; template `keystore.properties.example`) and an https API:

```bash
flutter build apk --release --dart-define=ENV=production --dart-define=API_BASE=https://HOST/api --dart-define=FORCE_LOGIN_ON_START=false
```

The build refuses to run without the key. `ENV=production` honors an explicit https `API_BASE`; otherwise it uses `https://smartflow.urbiztondo.gov.ph/api`. See [Production deployment](../../docs/product/PRODUCTION-DEPLOYMENT.md).

Tested toolchain and commands are in [Testing](../../docs/TESTING.md); the version floor is Flutter 3.44 / Dart 3.12 (current checks run on Flutter 3.47).
