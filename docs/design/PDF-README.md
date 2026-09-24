# SmartFlow design PDF — how to read it

## Do not open the PDF inside Cursor as text

`docs/design/Capstone SmartFlow.pdf` in the editor shows `%PDF-1.7` and binary `stream` data. That is normal. Cursor is a **code editor**, not a PDF viewer.

## View the real design (screens)

| Method | Action |
|--------|--------|
| **Fastest** | File Explorer → double-click `docs/design/Capstone SmartFlow.pdf` |
| **Script** | From project root: `.\scripts\open-design-pdf.ps1` |
| **VS Code / Cursor extension** | Install **vscode-pdf** (see `.vscode/extensions.json`) → open PDF again |

## Text export for AI + search (recommended)

### Option A — PDF viewer in Cursor (best for visuals)

1. Cursor will suggest **vscode-pdf** (see `.vscode/extensions.json`) → **Install**.
2. Reopen `docs/design/Capstone SmartFlow.pdf` → you see all 32 Figma screens.

### Option B — Markdown screen index (best for AI)

[`SmartFlow-Figma-Screens.md`](SmartFlow-Figma-Screens.md) — screen list, flows, and UI tokens.

> Note: The PDF is **image-based**; automatic text extract returns almost nothing. Use the markdown file + PDF viewer together.

```powershell
.\scripts\open-design-pdf.ps1          # open PDF in Edge/viewer
.\scripts\extract-design-pdf.ps1       # re-run if PDF text layer is added later
```

## Folder layout

```
docs/design/
  Capstone SmartFlow.pdf         ← visual source (Figma export)
  PDF-README.md                  ← this file
  SmartFlow-Figma-Screens.md     ← extracted text (after running script)
  diagrams/                      ← ERD + IPO PNG
  use-cases/                     ← HTML use-case slides
scripts/
  pdf-reader/
  open-design-pdf.ps1
  extract-design-pdf.ps1
```
