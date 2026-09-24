# SmartFlow — Document Request Logic (Deploy Guide)

## Two layers (huwag paghaluin)

| Layer | Ano | Sa prototype |
|-------|-----|----------------|
| **A. Document request** | Sino humihingi, anong uri, saang office dapat tumugon | **Bagong module** (`document_requests`) |
| **B. Physical tracking** | QR + IN/OUT kapag umiikot ang folder | **Existing** (`documents` + `movements`) |

Request = *"Kailangan ko ito / pakipadala."*  
Scan = *"Dumating / umalis na ang folder."*

**Mark OUT:** Clerk pumipili ng **receiving department** (ENG / HR / BUD / ACC) — naka-save sa `movements.destination_office_id`. Ang susunod na office lang ang makakita sa “Incoming” list (kung naka-set ang destination).

**Suggested destination (auto-highlight):**

| Document type | From | Suggested to |
|---------------|------|--------------|
| Disbursement Voucher | ENG | BUD |
| Disbursement Voucher | BUD | ACC |
| Disbursement Voucher | ACC | *(pilot ends — Treasury outside app)* |
| Approved Budget | BUD | ACC |
| Approved Budget | ENG | BUD |

Clerk can still pick another office if needed.

---

## Register vs Document Request (important)

| Tanong | Sagot |
|--------|--------|
| ENG nag-request sa Budget — DV ba sa Register? | **Hindi.** Request = ticket sa BUD. **Hindi** Register + DV para “humingi”. |
| Kailan ENG mag-Register? | Kapag **may pisikal na DV folder na sa Engineering** (project packet nila). Type: **Disbursement Voucher** lang (dropdown per office). |
| Kailan BUD mag-Register? | Pagkatapos **approve**, kapag **nas Budget na ang budget file** → Register (**Approved Budget**) → QR → OUT papunta ENG. |
| “Approved lang pwede i-register”? | **Tama ang idea** para sa cross-office: handler office mag-register **after approve**. Sa sariling office, register anytime may folder na sa desk. |
| Document type dropdown | **Ano ang laman ng folder**, hindi uri ng request. ENG = DV · BUD = Approved Budget · HR = Payroll. |

**Future (optional):** Register form → pili ng approved request → auto-fill title/type — mas strict na “approved muna”.

---

## Document ownership (routing)

| Category | Owner office (handler) | Halimbawa |
|----------|------------------------|-----------|
| `budget` | **BUD** | Budget allocation, availability |
| `payroll` | **ACC** | Not used in pilot UI (Accounting prepares payroll) |
| `disbursement` | **ACC** | DV supporting docs — ACC must not self-request |

## Request kind

| Kind | Gamit | Handler |
|------|-------|---------|
| `access` | Humihingi ng uri ng doc sa **owner** | BUD / HR / ACC by category |
| `pull` | Humihingi sa **specific office** na magpadala (e.g. ACC → ENG) | `target_office_id` |

**Rule:** Hindi pwedeng `access` request kung ang handler office = office mo (ikaw ang owner — walk-in sa desk niyo).

---

## Role permissions (pilot)

| Role | Pwede mag-request |
|------|-------------------|
| **staff** | budget, disbursement, pull (no payroll in UI; ACC no disbursement request) |
| **head** | budget, disbursement, pull |
| **admin** | lahat + on behalf of any office (audit) |

## Sino nag-a-approve?

Inbox ng **handler office** — staff/head ng BUD, HR, ACC, o ENG (kapag pull).

- `pending` → accept / decline (decline also needs phone/memo per client)  
- `approved` → in progress (optional link `document_id`)  
- `fulfilled` → custody complete at pilot offices (not Treasury payment)  
- **required_by** — mandatory on create; end user follows up if overdue  
- `rejected` / `cancelled` → closed  

---

## Scenario: ENG humingi ng budget file (wala pa sa ENG)

1. **Neil** (ENG) → Request `access` + category **budget** → inbox **BUD**  
2. **Angel** → Approve **or Reject** (reject → Neil sees `rejected` in **My requests**)  
3. **Angel (BUD)** → **Register + QR** (nasa Budget ang dokumento — **hindi** Neil)  
4. **Angel** → **OUT** → **ACC** → **IN** (Accounting)  
5. **Rainier (ACC)** → **OUT** → **ENG** → **Neil IN** (only ENG can IN — enforced if OUT had destination)  
6. **Angel** → Fulfill (+ link `DOC-2026-xxx`)

**Reject:** Hindi automatic — Budget staff taps **Reject** with notes; status `rejected` (not “decline” in DB).

## Scenario: ENG may sariling DV packet (review / payment trail)

1. **Neil** → Register DV sa **ENG** (may hawak na siya)  
2. Optional: budget request = “pakicheck ang DV” (ticket lang)  
3. Pisikal: **ENG → BUD → ACC** (hindi HR para sa DV)  

## Scenario: ACC needs file from ENG

1. **Rainier** (ACC admin) → Request `pull` + **target ENG** + category disbursement  
2. Inbox **Neil / Tofers (ENG)**  
3. Accept → Neil **OUT** (scan) → **`accounting.staff` IN** (admin cannot scan)  
4. Fulfill request  

---

## API (after migration)

Run once: `document-requests-migration.sql`

| Method | Endpoint | Notes |
|--------|----------|-------|
| POST | `document-requests-create.php` | Create request |
| GET | `document-requests-list.php?view=inbox\|outbox` | Lists |
| POST | `document-requests-update.php` | approve, reject, fulfill, cancel |

## DB migration

```text
mysql smartflow < backend/backend/api/document-requests-migration.sql
```

Then sync to XAMPP: `.\scripts\sync-backend-to-xampp.ps1`
