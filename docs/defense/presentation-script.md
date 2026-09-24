# SmartFlow — Presentation / Defense Script (Taglish)

**Municipality of Urbiztondo · Capstone**  
Practice bawat figure **2–3 beses** nang malakas. **Ituro** ang diagram habang nagsasalita.

**Prototype:** **Flutter mobile** (clerks scan) + **PHP/MySQL** sa LGU server. Ang **Municipal Accountant** ay **admin** sa mobile app para sa COA reports — hindi hiwalay na React web sa live demo.

---

## A. Opening — 30–45 segundo

> Magandang umaga/hapon po, honorable panel.
>
> Ipapakita namin ang **SmartFlow: A QR-Based Inter-Department Document Flow Tracking and COA Compliance System** para sa **Municipality of Urbiztondo**.
>
> **Problema:** Ang financial documents—**disbursement vouchers** at **approved budgets**—ay **pisikal** na pinapasa sa Engineering, Budget, at Accounting, pero **walang shared system** para malaman kung **nasaan** ang file. Umaasa sa **tawag, visit, at chat**. Ang Municipal Accountant ay **late** ang natatanggap na documents at **manual sa Excel** ang routing history.
>
> **Solusyon:** **Movement lang** ang tinatrack—hindi content ng voucher. May **QR** sa folder. Clerks **scan receive at forward** sa mobile. Heads **monitor**; Accounting **COA support reports**. Data sa **LGU server** (MySQL).
>
> Ipapaliwanag namin ang **Chapter II figures**, tapos **live demo** ng DV trail. Maraming salamat po.

---

## B. Figure 1 — IPO — ~1 minuto

> **Input:** Knowledge, Flutter mobile, PHP REST API, MySQL, phones, printer, document types, roles, thresholds.
>
> **Process:** Register + QR → physical handoff → scan IN/OUT → audit trail → alerts → COA summaries.
>
> **Output:** Deployed system, real-time location, scan history, reports for **COA preparation**—hindi financial statements.
>
> **Evaluation:** ISO/IEC 25010 questionnaire + pilot with Municipal Accountant, heads, clerks.

---

## C. Figure 2-1 — Architecture — ~45 segundo (mobile-first)

> **Three-tier:** Flutter mobile (presentation) → PHP REST on Apache (application) → MySQL (data).
>
> Clerks: scan at bawat handoff. Admin/accountant: reports at user setup sa same app. **Isang API, isang database.**

**Kung may React sa thesis slide:** *“React web ay planned/admin browser variant; ang defended prototype ay Flutter + API na parehong backend.”*

---

## D. Figure 2-2 — DFD Context — ~45 segundo

> **SmartFlow** sa gitna. **Frontline staff** (ENG, BUD, ACC, TRE, MAY): scans. **Department head:** monitor queue at alerts. **Municipal Accountant:** COA reports at thresholds. **DV trail:** ENG → BUD → ACC → TRE → MAY → TRE (check release).

---

## E. Live demo bridge — 15 segundo

> *“Document **requests** = formal ticket; **QR scans** = proof na lumipat ang pisikal na folder. DV path: **ENG → BUD → ACC → TRE → MAY → TRE**.”*

(Sundin ang **[DEMO-SCRIPT.md](DEMO-SCRIPT.md)** — Part 2 DV trail.)

---

## F. Panel Q&A — quick lines

| Tanong | Sagot |
|--------|--------|
| Bakit hindi HR sa DV? | Payroll hiwalay; pilot = DV + budget folders sa ENG/BUD/ACC |
| Approve ba ang app ng DV? | **Hindi** — custody log lang; Accounting checks docs, hindi payment approval |
| Bakit 0 on desk pagkatapos OUT? | On desk = still IN here; forwarded = Sent count |
| Treasury? | Phase 2; pilot ends sa ACC — may note sa app |
| COA export sino? | Accounting admin lang (`accountant.main`) |

---

## G. Closing — 20 segundo

> SmartFlow ay nagbibigay ng **chain-of-custody** para sa pisikal na DV at budget folders hanggang Accounting, **sumusuporta sa COA preparation** habang nananatiling **manual ang payment release** sa Treasury at Mayor. Salamat po.

---

*Full demo steps: `DEMO-SCRIPT.md` · Night before: `PRE-DEFENSE-BUKAS.md`*
