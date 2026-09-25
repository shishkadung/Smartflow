# SmartFlow — iOS notes

The Dart app in `lib/` is shared with Android. This `ios/` folder is the **native shell** (permissions, CocoaPods, signing).

## Updated for current app (2026)

- **Podfile** — present (was missing); installs pods for `mobile_scanner`, `image_picker`, etc.
- **Info.plist** — camera + photo library (QR upload / profile photo); ATS allows LAN HTTP for XAMPP pilot
- **Bundle ID** — `com.urbiztondo.smartflow`
- **Min iOS** — 15.5 (required by `mobile_scanner` 6.x / ML Kit 7)

Dart UI changes do **not** need a full `ios/` rewrite. Rebuild on a Mac after `flutter pub get`.

## Build on a Mac (required)

You cannot produce an `.ipa` / run on iPhone from Windows.

```bash
cd mobile/flutter
flutter pub get
flutter run -d <iphone-or-simulator> \
  --dart-define=API_BASE=http://YOUR_PC_LAN_IP/Smartflow/backend/backend/api
```

Or:

```bash
cd ios
pod install
open Runner.xcworkspace
```

Sign with your Apple team in Xcode → Runner → Signing & Capabilities.

### API URL tips

| Target | Example |
|--------|---------|
| iOS Simulator + XAMPP on same Mac | `http://127.0.0.1/Smartflow/backend/backend/api` |
| Physical iPhone + PC XAMPP (same Wi‑Fi) | `http://192.168.x.x/Smartflow/backend/backend/api` |
| Production | `--dart-define=ENV=production` (HTTPS host in `api_config.dart`) |

Default `API_BASE` in code is still the **Android emulator** URL (`10.0.2.2`) — always pass `--dart-define=API_BASE=...` for iOS.

### Before App Store / TestFlight

1. Point API to HTTPS; set `ENV=production`.
2. Consider tightening ATS (`NSAllowsArbitraryLoads` → false) once HTTPS works.
3. Apple Developer account + certificates.

## Capstone / client demo

Prefer **web** screen recording for remote UAT if you have no Mac yet. iOS is optional parity, not required for the survey.
