# Design assets

| File | What |
|---|---|
| [Capstone SmartFlow.pdf](Capstone SmartFlow.pdf) | 32 Figma screens — open in a PDF viewer, not as text |
| [PDF-README.md](PDF-README.md) | How to view / extract the PDF |
| [diagrams/](diagrams/) | ERD + IPO exports |
| [use-cases/](use-cases/) | Use-case HTML / markdown — open **CLEAN** or **DIAGRAM** in a browser |

## Design tokens (one system)

**Source of truth:** `mobile/flutter/lib/theme/smartflow_theme.dart` (`SfColors` / `SfGradients`)

| Mirror | Path |
|---|---|
| Live web portal | `web/src/index.css` (`:root` `--sf-*`) |
| Mobile HTML mock (phone / Flutter twin) | `mobile-mock/css/tokens.css` |
| Web HTML mock (desktop / React twin) | `web-mock/css/tokens.css` |

Type: **Source Sans 3** (UI) + **Source Serif 4** (wordmark / titles). CTAs: blue primary, navy for auth/ceremonial.

Backup slide for defense: [use-cases/SMARTFLOW-USE-CASE-DIAGRAM.html](use-cases/SMARTFLOW-USE-CASE-DIAGRAM.html)
