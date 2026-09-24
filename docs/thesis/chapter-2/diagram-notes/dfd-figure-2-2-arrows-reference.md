# Figure 2-2 — Exact arrows and labels (copy onto diagram)

Use this table on **Eraser / Word / Lucidchart**.  
**Rule:** arrow points **to** where data **goes**.

---

## Process

| Shape | Label |
|-------|--------|
| **Ellipse / circle** | **0 SmartFlow Document Tracking System** |

---

## All arrows (17 lines — or 13 if clerks use bidirectional)

### E1 — Frontline Clerk, Engineering (top)

| # | From → To | Label on arrow |
|---|-----------|----------------|
| 1 | **E1 → 0** | Scan data |
| 2 | **0 → E1** | Scan confirmation |

*Or one bidirectional:* **E1 <> 0** · `Scan handoff (Engineering)`

---

### E2 — Frontline Clerk, Human Resources (left)

| # | From → To | Label |
|---|-----------|--------|
| 3 | **E2 → 0** | Scan data |
| 4 | **0 → E2** | Scan confirmation |

*Or:* **E2 <> 0** · `Scan handoff (Human Resources)`

---

### E3 — Frontline Clerk, Budget (right)

| # | From → To | Label |
|---|-----------|--------|
| 5 | **E3 → 0** | Scan data |
| 6 | **0 → E3** | Scan confirmation |

*Or:* **E3 <> 0** · `Scan handoff (Budget)`

---

### E4 — Frontline Clerk, Accounting (bottom, above E5)

| # | From → To | Label |
|---|-----------|--------|
| 7 | **E4 → 0** | Scan data |
| 8 | **0 → E4** | Scan confirmation |

*Or:* **E4 <> 0** · `Scan handoff (Accounting)`

---

### E5 — Municipal Accountant / System Administrator (lower center)

| # | From → To | Label |
|---|-----------|--------|
| 9 | **E5 → 0** | Document registration |
| 10 | **E5 → 0** | Dashboard and report request |
| 11 | **E5 → 0** | Mark document completed |
| 12 | **E5 → 0** | User account data |
| 13 | **E5 → 0** | Office configuration |
| 14 | **E5 → 0** | Processing time thresholds |
| 15 | **0 → E5** | QR code / tracking code |
| 16 | **0 → E5** | Municipal dashboard |
| 17 | **0 → E5** | Delay alerts |
| 18 | **0 → E5** | COA flow summary report |
| 19 | **0 → E5** | Export file (PDF / Excel) |
| 20 | **0 → E5** | Audit logs |
| 21 | **0 → E5** | System status reports |
| 22 | **0 → E5** | Configuration saved confirmation |

**Cleaner (4 arrows — OK for thesis):**

| From → To | Label |
|-----------|--------|
| **E5 → 0** | Registration, report requests, and system configuration |
| **0 → E5** | QR code, municipal dashboard, and COA export |
| **0 → E5** | Audit logs and system status reports |
| **0 → E5** | Configuration saved confirmation *(optional)* |

---

### E6 — Department Head (upper left)

| # | From → To | Label |
|---|-----------|--------|
| 17 | **E6 → 0** | Office dashboard request |
| 18 | **0 → E6** | Office dashboard |
| 19 | **0 → E6** | Overdue flags |

*Or 2 arrows:* **E6 → 0** `Office dashboard request` · **0 → E6** `Office dashboard and overdue flags`

---

**Removed:** separate **E7 System Administrator** — admin arrows are on **E5** above.

---

### E8 — Commission on Audit (below E5) — **not** connected to 0

| # | From → To | Line style | Label |
|---|-----------|------------|--------|
| 24 | **E5 → E8** | **Dashed** | COA support file |

**Do not draw:** 0 → E8, E8 → 0, E8 → E5 (unless you add optional audit inquiry).

---

## Fix your Eraser diagram (vs screenshot)

| Wrong in preview | Correct |
|------------------|---------|
| **0 → E1** only `Scan handoff Eng` | **E1 → 0** `Scan data` and **0 → E1** `Scan confirmation` (or bidirectional `Scan handoff (Engineering)`) |
| **E6 → 0** only `Office dashboard` | **E6 → 0** `Office dashboard request` · **0 → E6** `Office dashboard` (and optional `Overdue flags`) |
| Separate **E7 Admin** box | **Remove E7** — route config arrows through **E5** |
| **0 → E5** `QR dashboard` + `COA report export` + **E5 → 0** `Requests` | Directions OK; use full labels above |
| **E5 → E8** dashed `COA support file` | **Correct** — keep |

---

## Entity box labels (exact text)

| ID | Text inside rectangle |
|----|------------------------|
| E1 | Frontline Clerk — Engineering |
| E2 | Frontline Clerk — Human Resources |
| E3 | Frontline Clerk — Budget |
| E4 | Frontline Clerk — Accounting |
| E5 | Municipal Accountant / System Administrator |
| E6 | Department Head |
| E8 | Commission on Audit (COA) |

---

## Figure caption (Word)

*Figure 2-2. Data Flow Diagram (Level 0 / Context Diagram) of the SmartFlow System*

---

## Short comment under figure (optional)

The context diagram shows external entities that exchange data with the SmartFlow process. Frontline clerks send scan data at document handoffs; the system returns scan confirmation. The Municipal Accountant / System Administrator (one person in the pilot) registers documents, receives dashboards, alerts, COA flow summary reports, and exports, and also sends configuration data while receiving audit logs and system status. The Department Head receives office-level monitoring data. COA receives support files from the Accountant outside the system. Internal data stores are shown in Figure 2-3.
