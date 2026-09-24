# SmartFlow — Lahat ng Demo Scenarios (Re-defense)

**Password lahat:** `smartflow123`  
**Basahin tonight · rehearse bukas · order sa baba = recommended sa panel**

---

## Scenario index

| ID | Scenario | Kailangan? | Oras | Account(s) |
|----|----------|------------|------|------------|
| **A** | DV trail (main story) | **OO** | ~6 min | ENG → BUD → ACC clerk |
| **S1** | Secured QR (register + verify) | **OO** | ~1 min | ENG (kasama sa A) |
| **S2** | Duplicate IN blocked | **OO** | ~30 sec | ENG |
| **S3** | Wrong office IN blocked | **OO** | ~1 min | ENG + BUD |
| **S4** | OUT without IN blocked | Optional | ~30 sec | ENG |
| **S5** | Tampered QR rejected | **OO** | ~1 min | ENG |
| **S6** | Admin QR scan monitor | **OO** | ~2 min | `accountant.main` |
| **B** | Budget request trail | Optional | ~5 min | ENG → BUD → ACC → ENG |
| **H** | Head monitor only | Optional | ~2 min | `head.engineering` |
| **C** | COA summary + system | Recommended | ~2 min | `accountant.main` |
| **C2** | COA custody exceptions | Optional | ~1 min | `accountant.main` |

**HTTPS:** hindi kasama sa demo (LAN HTTP OK — sabihin “production = HTTPS later”).

---

## Panel recommendations → demo scenario (mapping)

| Panel recommendation | Sa demo? | Scenario / paano |
|---------------------|--------|-------------------|
| **QR Security** (signed payload) | Oo | **S1**, **S5** (tamper); register + verify banner |
| **QR Expiration** | Partial | **S1** (expiry date sa label); **S5** script — *mention* 180 days; walang live expired scan (kailangan lumang label) |
| **HTTPS** | Hindi (deferred) | Verbal lang sa Q&A — production plan |
| **Duplicate scan prevention** | Oo | **S2**; debounce + state matrix |
| **State-based scan rules** | Oo | **A**, **S2**, **S3**, **S4** (optional) |
| **QR usage audit / monitor** | Oo | **S6** — filter, CSV, suspicious |
| **COA process alignment** | Partial | **A8** History; **C** COA summary; **C2** custody exceptions (below) |
| **Already present: movement history** | Oo | **A8** |
| **Already present: audit logging** | Oo | **S6** (lahat ng accept/reject) |
| **Already present: alerts** | Light | **H** — Head **Alerts** tab (optional, 2 min) |

**Panel talking points (doc):** covered sa **S1** (not one-time), **S6** (audit trail), **S2/S3/S5** (rejects with reason).

---

## Before anything (5 min)

```powershell
cd "C:\Users\nljhn\Downloads\Capstone 1 -Neil"
.\scripts\sync-backend-to-xampp.ps1
.\scripts\setup-smartflow.ps1
# o: .\scripts\run-defense-demo.ps1
```

```powershell
cd mobile\flutter
flutter run
```

1. XAMPP: Apache + MySQL **ON**  
2. Purge (malinis na demo):  
   `http://localhost/Smartflow/backend/backend/api/dev-purge-demo-documents.php?all=1`  
3. Seed users (kung kailangan):  
   `http://localhost/Smartflow/backend/backend/api/dev-seed-demo-users.php`

**Opening line:**  
*“SmartFlow: **requests** kung sino ang dapat tumugon; **secured QR + scans** kung nasaan ang pisikal na folder at sino ang nag-scan.”*

---

## Recommended order bukas (~15 min)

| Order | Scenario | Bakit dito |
|-------|----------|------------|
| 1 | **A + S1** | Main DV + secured QR (positive path) |
| 2 | **S2** | Quick reject — duplicate |
| 3 | **S3** | Wrong receiver — panel favorite |
| 4 | **S5** | Secured QR / tamper |
| 5 | **S6** | Admin monitor — ties rejects + accepts |
| 6 | **C** | COA + municipal view |
| 7 | **H** or **B** | Kung may oras pa |

---

# Scenario A — DV trail (MAIN)

**Story:** DV folder sa Engineering → Budget → Accounting → Treasury → Mayor → Treasury (check release). **Hindi HR.**

*“Validated path: **ENG → BUD → ACC → TRE → MAY → TRE**. Hindi approval ng bayad ang app — **track** ng folder; Treasury marks payment released on the request ticket.”*

| # | Login | Action | Sabihin |
|---|--------|--------|---------|
| A1 | `engineering.staff` | **New** → Title: `DV – Road Repair` · Type: **Disbursement Voucher** | *“Holder office ang nag-register.”* |
| A2 | Same | Success screen: **secured QR** + expiry date · print/copy | *“Hindi raw ID lang — signed token may expiry.”* (**S1**) |
| A3 | Same | **Scan** tab → scan QR → **“Secured QR verified”** banner | *“Server chine-check signature at expiry.”* |
| A4 | Same | **Mark OUT** → destination **BUD** | |
| A5 | `budget.staff` | **Scan** same label → **Mark IN** | *“Dumating sa Budget.”* |
| A6 | Same | **Mark OUT** → **ACC** | |
| A7 | `accounting.staff` | **Scan** → **Mark IN** · then **Mark OUT** → **TRE** | *“After supporting docs, folder goes to Treasury.”* |
| A8 | `treasury.staff` | **Scan** → **Mark IN** · **Mark OUT** → **MAY** | *“Treasury processes payment path.”* |
| A9 | `mayor.staff` | **Scan** → **Mark IN** · **Mark OUT** → **TRE** | *“Mayor signature, then back to Treasury for check release.”* |
| A10 | `treasury.staff` | **Scan** → **Mark IN** — see **pilot_end_note** on Scan | *“Check release at Treasury — app tracks the folder, not the bank payment.”* |
| A11 | Any | **History** → timeline (user, time, IN/OUT) | *“Chain-of-custody para COA.”* |

**Panel line:**  
*“Validated path: **ENG → BUD → ACC → TRE → MAY → TRE**. Hindi approval ng bayad ang app — **track** lang ng folder; Treasury marks payment released on the ticket.”*

---

# Scenario S1 — Secured QR (kasama sa A, i-highlight)

| Check | Dapat makita |
|-------|----------------|
| After register | Text: **“Print this secured QR”** + **Valid until …** |
| After camera scan | Blue banner: **“Secured QR verified — signature and expiry checked by server.”** |
| QR label print (browser) | Footer: **“SmartFlow · Secured QR · Valid until …”** |

**Kung tanong “one-time ba ang QR?”**  
*“Hindi. **Reusable** ang label habang valid; **isang valid transition** lang per IN o OUT — state-controlled, hindi one-scan forever.”*

---

# Scenario S2 — Duplicate IN blocked

**Gamit ang same DOC mula Scenario A habang **IN pa sa ENG** (o gumawa bagong DV at Mark IN once).

| # | Login | Action | Dapat |
|---|--------|--------|-------|
| S2-1 | `engineering.staff` | Same doc → **Mark IN** ulit | Error: *“Already marked IN at your office…”* + hint |
| S2-2 | | | **Hindi** dapat magdagdag ng bagong IN sa history |

**Sabihin:** *“Duplicate at invalid state — rejected server-side, may reason code sa audit.”*

---

# Scenario S3 — Wrong office IN blocked

**Setup:** Doc naka-**OUT from ENG to BUD** (after A4). **Huwag** pa mag-IN sa Budget.

| # | Login | Action | Dapat |
|---|--------|--------|-------|
| S3-1 | `engineering.staff` | Scan → try **Mark IN** | *“Already forwarded…”* o *“receiving office must scan IN”* |
| S3-2 | `budget.staff` | Scan → **Mark IN** | **Success** — tamang receiver |

**Optional wrong destination:** OUT to ACC, try IN sa **HR** (`hr.staff`) → *“sent to ACC… Only that office can mark IN.”*

---

# Scenario S4 — OUT without IN (optional)

**Bagong doc:** Register DV → **huwag** i-assume auto-IN kung gusto mo pure test — kung may auto-IN, skip o purge.

| # | Action | Dapat |
|---|--------|-------|
| S4-1 | Register lang, then Scan → **Mark OUT** agad | *“Mark IN first when the physical document arrives…”* |

---

# Scenario S5 — Tampered / invalid QR

| # | Action | Dapat |
|---|--------|-------|
| S5-1 | Sa **Scanner**, **manual field**: i-paste ang secured payload mula register screen |
| S5-2 | Baguhin ang **1 character** sa gitna ng string | |
| S5-3 | Lookup | *“Invalid QR — label may be damaged or forged. Reprint from SmartFlow.”* |

**Sabihin:** *“Forged copy ng QR hindi tatanggapin — HMAC signature sa server.”*

**Expired QR (mention lang kung walang luma na label):**  
*“May 180-day expiry; reprint = bagong token.”*

---

# Scenario S6 — Admin QR scan monitor

| # | Login | Action | Dapat |
|---|--------|--------|-------|
| S6-1 | `accountant.main` | Home → **QR scan monitor** | Overview card |
| S6-2 | Same | Filter **48h** · **Rejected** | Lista ng S2, S3, S5 |
| S6-3 | Same | Filter **All** · tingnan **Accepted** | Successful IN/OUT |
| S6-4 | Same | **Needs review** (kung may 3+ rejects sa isang user) | Training flag |
| S6-5 | Same | **Copy CSV for compliance** | Snackbar: copied → paste Excel |

**Sabihin:** *“Lahat ng scan attempt — accepted o rejected — visible sa admin para COA at internal audit.”*

---

# Scenario B — Budget request (OPTIONAL backup)

**Hiwalay sa DV — huwag isabay sa same DOC.**

| # | Login | Action |
|---|--------|--------|
| B1 | `engineering.staff` | **Document requests** → Budget → purpose + required-by date |
| B2 | `budget.staff` | Inbox → **Approve** → **New** Approved Budget → QR → OUT → ACC |
| B3 | `accounting.staff` | IN → OUT → ENG |
| B4 | `engineering.staff` | IN → receive |
| B5 | `budget.staff` | Fulfill + link DOC ID |

**Reject variant:** B2 **Reject** + notes → Neil sees declined.

---

# Scenario H — Head monitor (OPTIONAL)

| # | Login | Action | Sabihin |
|---|--------|--------|---------|
| H1 | `head.engineering` | Home / Queue / Alerts | *“Monitor — clerks ang scanner.”* |
| H2 | Same | History → DOC ID | Read-only trail |

---

# Scenario C — Admin / COA (RECOMMENDED)

| # | Login | Action | Sabihin |
|---|--------|--------|---------|
| C1 | `accountant.main` | Home — all offices | Municipal view |
| C2 | Same | **COA monthly summary** | Export / compliance |
| C3 | Same | **System** — API online | XAMPP health |
| C4 | Same | **QR scan monitor** (kung hindi pa sa S6) | Audit trail |

**Note:** `accountant.main` **hindi** frontline scanner — gamit `accounting.staff` sa ACC scans.

---

# Scenario C2 — COA custody exceptions (OPTIONAL)

**Para sa panel item:** *“COA process alignment — traceability + exceptions.”*  
Nasa **COA monthly summary** screen (baba), hindi hiwalay na app.

| # | Login | Action | Sabihin |
|---|--------|--------|---------|
| C2-1 | `accountant.main` | **COA summary** → scroll **Audit exceptions (custody gaps)** | *“Unforwarded OUT o wrong-office IN — bago mag-report.”* |
| C2-2 | Same | Kung may row: basahin *wrong_receiver* / *unforwarded* | *“Hindi financial audit — physical custody gaps.”* |
| C2-3 | Same | Kung empty: *“No exceptions (24h)”* | *“Maayos ang trail sa demo window.”* |

**Para makita ang exception sa demo:** kailangan scenario na **OUT walang IN** sa next office > 24h — mahirap sa live demo; pwede **mention** lang o rehearse kahapon na may stale data.

---

# 5-minute emergency script

1. ENG: New DV → secured QR → OUT → BUD  
2. BUD: IN → OUT → ACC  
3. ACC clerk: IN → History  
4. ENG: duplicate IN → **reject**  
5. Admin: QR monitor → rejected row  
6. *“Treasury after ACC — outside pilot.”*

---

# Accounts

| Name | Username | Office | Scan? | Admin? |
|------|----------|--------|-------|--------|
| Neil | `engineering.staff` | ENG | Yes | No |
| Tofers | `head.engineering` | ENG | Yes | No |
| Angel | `budget.staff` | BUD | Yes | No |
| Zandra | `hr.staff` | HR | Yes | No |
| Maria | `accounting.staff` | ACC | Yes | No |
| Rainier | `accountant.main` | ACC | No | Yes |

---

# Panel Q&A — security (bagong sagot)

| Tanong | Sagot |
|--------|--------|
| Secure ba ang QR? | Signed token (`SF1…`), expiry, server verify bago IN/OUT. |
| One-time scan? | **Hindi** — reusable label; **one valid transition** per state (IN/OUT rules). |
| Duplicate scan? | Blocked + audit; 8-second debounce + state matrix. |
| HTTPS? | Pilot sa LGU LAN (HTTP); production deployment = HTTPS (planned). |
| Sino nakakakita ng rejects? | Municipal admin — **QR scan monitor**. |

---

# Troubleshooting

| Problem | Fix |
|---------|-----|
| Invalid server response | `.\scripts\sync-backend-to-xampp.ps1` · restart Apache |
| Walang “Secured QR verified” | Reprint/register bagong doc — luma plain QR = legacy warning lang |
| Cannot Mark IN | Previous office OUT muna; tamang receiving office |
| Admin cannot scan | Normal — use `accounting.staff` |
| QR monitor empty | Gawin muna S2/S3/S5 rejects · pull to refresh · try 48h |
| Purge masyadong aggressive | Purge documents only kung kailangan — users naiwan |

---

# Screenshot checklist (optional evidence)

- [ ] Register success — secured QR + expiry  
- [ ] Scanner — “Secured QR verified”  
- [ ] Reject — duplicate IN message  
- [ ] Reject — wrong office / tampered QR  
- [ ] Admin QR monitor — accepted + rejected + CSV  

---

**Good luck bukas.** Kung isang file lang babasahin: **Scenario A → S2 → S3 → S5 → S6 → C**.
