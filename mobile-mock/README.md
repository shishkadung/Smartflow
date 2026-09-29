# SmartFlow — Mobile HTML mock (Flutter twin for Figma)

Static **390px app screens** (UI only — no phone bezel) that mirror the **live Flutter app** (`mobile/flutter/`).

> Desktop / React mocks: **`web-mock/`**

## Figma import (html.to.design)

**Do not import `index.html` or `galleries/admin.html` (etc.)** — those use iframes. html.to.design shows “Not Found!” and gallery padding looks like a white border.

| Do this | File |
|---------|------|
| Auth (4) | `galleries/auth-figma.html` |
| Employee (10) | `galleries/employee-figma.html` |
| Head (4) | `galleries/head-figma.html` |
| Admin (6) | `galleries/admin-figma.html` |
| Extras (12) | `galleries/extras-figma.html` |

These boards **inline** the phone UIs (no iframes), with **zero page padding**. Use the **html.to.design browser extension** for `file://` / local pages. Frame look is white app content only (no device bezel). Browse `index.html` in Chrome for the iframe viewer only.

**Extras board** covers: signup step 2 · scan blocked · history trail · requests create/mine · account & security · employee/head/admin menus · head register · admin profile · admin system.

Rebuild after UI edits:

```bash
node mobile-mock/_build-batch.js
```

## Twin rules

| Piece | Flutter | Mock |
|-------|---------|------|
| Colors | `smartflow_theme.dart` | `css/tokens.css` |
| Top chrome | `SfShellTopBar` | `.sf-shell-chrome` |
| Bottom nav | `SfBottomNav` | `.sf-bottom-nav` |

## Re-sync chrome after Flutter UI changes

```bash
node mobile-mock/scripts/sync-flutter-twin.js
```
