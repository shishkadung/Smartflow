# SmartFlow Flutter

Rebuild aligned with **Capstone SmartFlow.pdf** (clerk · head · admin flows).

## Setup

1. Install [Flutter SDK](https://docs.flutter.dev/get-started/install).
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

4. Seed backend: run `..\..\scripts\setup-smartflow.ps1` or open `dev-replace-team-users.php` once (accounts only — no sample documents).

## Capstone team logins

| Username | Who | Office | Role |
|----------|-----|--------|------|
| `kristofer.eng` | Fernandez, Kristofer Cyle | ENG | staff |
| `angel.bud` | Buenaventura, Angel A. | BUD | staff |
| `rainier.hr` | Fallarcuna, Rainier B. | HR | staff |
| `krizandra.tre` | Basit, Krizandra Josephine L. | TRE | staff |
| `neil.acc.staff` | Pascua, Neil John A. | ACC | staff |
| `neil.acc.head` | Pascua, Neil John A. | ACC | head |
| `neil.admin` | Pascua, Neil John A. | ACC | admin |
| `neil.may.staff` | Pascua, Neil John A. | MAY | staff |
| `neil.may.head` | Pascua, Neil John A. | MAY | head |

Password: `smartflow123`
