# SmartFlow — basahin mo lang ito (defense)

**Para kay Neil / team.** Tatlong rule lang, tapos **isang main demo (DV)**.

**Lahat ng scenario (security + admin):** [DEMO-SCENARIOS-COMPLETE.md](DEMO-SCENARIOS-COMPLETE.md)

**Password lahat:** `smartflow123`

---

## Team logins (Capstone proponents)

| Who | Username | Office | Role |
|-----|----------|--------|------|
| Fernandez, Kristofer Cyle | `kristofer.eng` | ENG | staff |
| Buenaventura, Angel A. | `angel.bud` | BUD | staff |
| Fallarcuna, Rainier B. | `rainier.hr` | HR | staff |
| Basit, Krizandra Josephine L. | `krizandra.tre` | TRE | staff |
| Pascua, Neil John A. | `neil.acc.staff` | ACC | staff |
| Pascua, Neil John A. | `neil.acc.head` | ACC | head |
| Pascua, Neil John A. | `neil.admin` | ACC | admin |
| Pascua, Neil John A. | `neil.may.staff` | MAY | staff |
| Pascua, Neil John A. | `neil.may.head` | MAY | head |
| Pascua, Neil John A. | `neil.eng.head` | ENG | head |
| Pascua, Neil John A. | `neil.hr.head` | HR | head |
| Pascua, Neil John A. | `neil.bud.head` | BUD | head |
| Pascua, Neil John A. | `neil.tre.head` | TRE | head |

> One login = one office + one role. Neil uses several usernames (staff/head/admin across offices).

**Reset DB to these accounts only:**  
`http://localhost/Smartflow/backend/backend/api/dev-replace-team-users.php`

---

## 3 rules lang

1. **Wala pa sa desk mo ang folder?** → **Document request** (hindi Register).  
2. **Nasa desk mo na?** → **Register** + QR → **Scan IN/OUT** kapag lumipat.  
3. **Sino may hawak, siya mag-Register** — hindi ang humihingi.

---

## Main demo — DV trail (~10 min) — client priority

| Order | Login | Gawin | Sabihin |
|-------|--------|--------|---------|
| 1 | `kristofer.eng` | **New** → **DV** → **secured QR** → scan verified → **OUT** → **BUD** | “Signed QR, hindi raw ID.” |
| 2 | `angel.bud` | **IN** → **OUT** → **ACC** | “Budget check ng pondo.” |
| 3 | `neil.acc.staff` | **IN** → **OUT** → **TRE** | “Supporting docs — **hindi** bayad approval sa app.” |
| 4 | `krizandra.tre` | **IN** → **OUT** → **MAY** → (later) back **TRE** | “Treasury → Mayor → check release.” |
| 5 | `neil.may.staff` | **IN** (optional) / trail continue | “Mayor’s Office custody.” |
| 6 | `kristofer.eng` | Duplicate **IN** → **reject** | “State rules + audit.” |
| 7 | `neil.admin` | **QR scan monitor** → rejects | “Panel compliance view.” |
| 8 | `neil.admin` | **COA report** | “Municipal view — clerk ang nag-scan.” |

**DV line:** *“ENG → BUD → ACC → TRE → MAY → TRE. App tracks the folder; Treasury marks payment released on the request ticket.”*

---

## Backup demo — budget request (kung may oras)

| Order | Login | Gawin |
|-------|--------|--------|
| 1 | `kristofer.eng` | Requests → Budget + **required-by date** |
| 2 | `angel.bud` | **Accept** → Register Approved Budget → OUT → ACC |
| 3 | `neil.acc.staff` | IN → OUT → ENG |
| 4 | `kristofer.eng` | IN |
| 5 | `angel.bud` | Close request + DOC ID |

**Decline demo:** Budget **Decline** + notes → dialog na kailangan din ng tawag/memo.

---

## ⚠️ Huwag malito

| Username | Scan? |
|----------|-------|
| `neil.acc.staff` | **OO** — gamitin sa ACC IN/OUT |
| `neil.admin` | **HINDI** — admin/COA report lang |

---

## Kung may error

```powershell
cd "C:\Users\nljhn\Downloads\Capstone -Neil"
.\scripts\run-defense-demo.ps1
```
Flutter: pindot **`R`**.

**UI polish smoke (5 min):** [../product/UI-VALIDATION-5MIN.md](../product/UI-VALIDATION-5MIN.md)

---

## Kung tanong ng panel

| Tanong | Sagot |
|--------|--------|
| Ano ang SmartFlow? | QR tracking ng **pisikal na folder** — hindi financial audit. |
| Validated? | Questionnaire sa Municipal Accountant; DV trail priority. |
| Request vs Scan? | Request = ticket; Scan = totoong lipat. |
| Ready deploy? | **Pilot** — prototype; kailangan training + security. |
| Limitation? | Scan discipline; payroll = payslip access only (no payroll QR). Payment itself is not approved in-app. |

---

## Files

| File | Para saan |
|------|-----------|
| [PRE-DEFENSE-BUKAS.md](PRE-DEFENSE-BUKAS.md) | Full checklist tonight |
| [DEMO-SCRIPT.md](DEMO-SCRIPT.md) | Detalyadong steps |
| [../design/use-cases/SMARTFLOW-USE-CASE-DIAGRAM.html](../design/use-cases/SMARTFLOW-USE-CASE-DIAGRAM.html) | Backup slide |

**Enough na ito para bukas.**
