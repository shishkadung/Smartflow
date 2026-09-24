# SmartFlow — Jetpack Compose

Native Android rebuild matching **Capstone SmartFlow.pdf** and the PHP API.

## Open in Android Studio

1. **File → Open** → select this `android` folder.
2. Let Gradle sync (JDK 17).
3. Edit API URL in `app/build.gradle.kts` → `buildConfigField("API_BASE", ...)`.
4. Run on emulator (`10.0.2.2` = host localhost).

## Features (rebuild v1)

- Login + 3-step sign-up
- **Clerk:** dashboard stats, scanner (manual ID), alerts, profile
- **Head:** dashboard, document queue, alerts, profile
- **Admin:** dashboard, pending approvals, system status, profile

## Demo accounts

Same as Flutter — `engineering.staff` / `head.engineering` / `accountant.main` · password `smartflow123`.

## Note

Generate Gradle wrapper via Android Studio on first open, or run from Android Studio's **Gradle sync** (creates `gradle/wrapper` automatically).
