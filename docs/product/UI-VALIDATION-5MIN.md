# SmartFlow — UI validation (5 minutes)

Run this on **emulator or phone** after a hot restart (`R`). XAMPP on. Password: `smartflow123`.

Goal: prove Messenger-style chrome (⇄ Requests + ENG menu) and bottom `Home · Scan · Alerts · Menu`.

---

## A. Auth hero (45 sec)

1. Sign out → **Get Started**
2. Confirm: **Urbiztondo seal**, trust strip, navy **Sign in**
3. **Login** → seal still there · Sign in works

| Pass? | Check |
|:-----:|-------|
| [ ] | Seal visible |
| [ ] | Auth panel slides in (subtle) |

---

## B. Clerk navigation + path (3–4 min)

Login: `engineering.staff`

**Header:** `⇄` Document requests · `ENG` **Profile**  
**Bottom:** Home · **Scan** (raised) · Alerts (badge) · Menu (Register · History)

| Step | Action | Pass if |
|------|--------|---------|
| 1 | **Home** | Seal · Start here |
| 2 | Header **⇄** | Opens document requests |
| 3 | **ENG** | Opens **Profile** (account · logout) — not the Menu sheet |
| 4 | **Menu** tab | Register · History only |
| 5 | **Scan** | LIVE SCAN · gold frame |
| 6 | Mark OUT → BUD | One primary · toast |
| 7 | **Alerts** tab | Red badge when overdue |

| Pass? | Check |
|:-----:|-------|
| [ ] | ENG → Profile; Menu tab → tools |
| [ ] | ENG has **no** alert count; Alerts tab does |
| [ ] | ⇄ is requests (not a bell) |

---

## C. Head + Admin smoke (1 min)

| Role | Bar | Header |
|------|-----|--------|
| Head | Home · Queue · Alerts · Menu | ⇄ + office code |
| Admin | Home · Users · COA · Menu | ⇄ + office code |

| Pass? | Check |
|:-----:|-------|
| [ ] | Admin COA export toast works |
| [ ] | Admin office badge → Profile; Menu → Offices / System |

---

## Fail = fix before defense

- Old Profile/Requests bottom tabs → hot restart `R`  
- Red badge still on ENG → report  
- API red banner → XAMPP + sync script  

Full DV: [defense/START-HERE.md](../defense/START-HERE.md)
