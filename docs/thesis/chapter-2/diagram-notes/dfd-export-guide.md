# DFD Level 0 & Level 1 — How to Draw (Not dbdiagram)

## Can we use dbdiagram.io for DFD?

**Hindi recommended — hindi tama ang notation.**

| Tool | Best for | DFD shapes |
|------|----------|------------|
| **[dbdiagram.io](https://dbdiagram.io)** | **ERD** (tables, PK/FK) | ❌ Walang process **circle**, external entity **rectangle**, data store **parallelogram** |
| **[mermaid.live](https://mermaid.live)** | **DFD** (Figures 2-2, 2-3) | ✅ Circles `(( ))`, boxes `[ ]`, stores `[/ /]` |
| Word / Draw.io / Lucidchart | Manual thesis figures | ✅ Full control |

**Rule:** **ERD → dbdiagram** · **DFD → Mermaid** (files below)

Kung ilalagay mo ang DFD sa dbdiagram, magmumukha itong **database diagram**, hindi **Data Flow Diagram** — maaaring i-reject ng panel.

---

## Figure 2-2 — DFD Level 0 (Context)

**Files (pick one layout):**

| File | Layout |
|------|--------|
| [`figure-2-2-level-0-template.mmd`](figure-2-2-level-0-template.mmd) | **Like your Word template** — 6 boxes around circle + COA below |
| [`figure-2-2-level-0-clean.mmd`](figure-2-2-level-0-clean.mmd) | **Simpler** — 2 arrows per entity (bidirectional) |
| [`figure-2-2-level-0.mmd`](figure-2-2-level-0.mmd) | Full labels (all flows listed) |

**Steps:**

1. Open [mermaid.live](https://mermaid.live)
2. Delete lahat ng sample code
3. Open `figure-2-2-level-0.mmd` → **Ctrl+A → Ctrl+C**
4. Paste sa mermaid.live
5. **Actions → Export PNG** (landscape kung mahaba)
6. Insert sa Word → caption: *Figure 2-2. Data Flow Diagram (Level 0 / Context Diagram) of the SmartFlow System*

**Checklist (Level 0):**

- [ ] **Isang process** lang: `0 SmartFlow Document Tracking System` (circle)
- [ ] **7 external entities** (E1–E4, E5, E6, E8 — **no E7**) — hiwalay ang 4 clerks
- [ ] **E5** = Municipal Accountant / System Administrator (isang box)
- [ ] **Walang** D1–D8 data stores sa figure na ito
- [ ] **E5 -.-> E8** dashed (COA support file) — hindi mula sa process 0

**Arrow reference:** [`dfd-figure-2-2-four-side-format.md`](dfd-figure-2-2-four-side-format.md)

---

## Figure 2-3 — DFD Level 1

**File:** [`figure-2-3-level-1.mmd`](figure-2-3-level-1.mmd)

**Steps:** Same as Level 0 — copy **.mmd file only**, not the whole `.md` doc.

**Checklist (Level 1):**

- [ ] **5 processes:** 1.0 Register · 2.0 Scan · 3.0 Monitor · 4.0 Reports · 5.0 Config
- [ ] **8 data stores:** D1–D8 (same names as ERD tables)
- [ ] Clerks → **2.0 only** (hindi 1.0 o 5.0)
- [ ] **4.0 → E5** at analytics → **E6**; **E5 -.-> E8** dashed
- [ ] **5.0** touches **D1, D2, D3, D7** lang — hindi D6

**Full rules & alternate diagram:** [`dfd-figure-2-3-level-1.md`](dfd-figure-2-3-level-1.md)

---

## One-page workflow (thesis)

```
Figure 2-6 ERD     →  dbdiagram.io  →  paste DBML from erd-mobile-only-explained.md §1
Figure 2-2 DFD L0  →  mermaid.live  →  figure-2-2-level-0.mmd
Figure 2-3 DFD L1  →  mermaid.live  →  figure-2-3-level-1.mmd
```

---

## Kung gusto mo isang app lang (alternative)

| App | DFD + ERD |
|-----|-----------|
| **Draw.io** (diagrams.net) | Both — manual shapes |
| **Lucidchart** | Both — manual |
| **Eraser.io** | DFD prompts — see [`eraser-figure-2-2-level-0.md`](eraser-figure-2-2-level-0.md) |

Stick sa **dbdiagram (ERD) + Mermaid (DFD)** — pinakamabilis sa project files mo na.

---

## Panel note (kung tatanungin)

> “Ang ERD ay ginawa sa dbdiagram dahil table-based ang notation. Ang DFD ay ginawa sa Mermaid dahil kailangan ng process circles at data store symbols na hindi supported ng dbdiagram.”
