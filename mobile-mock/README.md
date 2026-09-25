# SmartFlow — Mobile HTML mock (Flutter twin for Figma)

Static **414px phone frames** that mirror the **live Flutter app**
(`mobile/flutter/`). Use these screens as the visual source when building **mobile** Figma frames.

> Desktop / browser Figma mocks live in **`web-mock/`** (twins of `web/` React).

## Twin rules (keep in sync with Flutter)

| Piece | Flutter source | Mock |
|-------|----------------|------|
| Colors / type | `lib/theme/smartflow_theme.dart` | `css/tokens.css` |
| Navy top chrome | `lib/widgets/sf_shell_chrome.dart` (`SfShellTopBar`) | `.sf-shell-chrome` |
| Overview card | `SfPageOverviewCard` in `clerk_widgets.dart` | `.sf-overview-card` |
| Desk stats | `SfDashboardStatRow` | `.sf-stat-cell` + `__sublabel` |
| Bottom nav | `SfBottomNav` in `sf_page.dart` | `.sf-bottom-nav` |
| Captions | `utils/format_time.dart` + role overview cards | page copy |

## Role bottom nav (live)

| Role | Tabs |
|------|------|
| **staff** | Home · **Scan** · Alerts · Menu |
| **head** | Home · **Queue** · Alerts · Menu |
| **admin** | Home · **Scan** · COA · Menu |

Top bar (all roles): seal · **office name** · SmartFlow wordmark · help · requests (⇄) · office badge.

## Quick start

Double-click **`index.html`** in Chrome (no server).

Or: File → Open → `mobile-mock/index.html`.

## Re-sync after Flutter UI changes

```bash
node mobile-mock/scripts/sync-flutter-twin.js
```

Then hand-fix any screen that needs content-level twinning.

## Import into Figma

1. Open a screen full-size in Chrome.
2. DevTools → right-click `#figma-export` → **Capture node screenshot**.
3. Or use **html.to.design** with the local file URL.

Frame: **414 px** wide; height grows with content.
