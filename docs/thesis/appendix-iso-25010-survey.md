# SmartFlow — ISO/IEC 25010 Client Survey (UAT Evaluation)

**Use this with Municipality of Urbiztondo pilot users** after they try the system (short demo / UAT tasks).  
Paste into Capstone 2 **Appendix — Survey Instrument**.  
Print one copy per respondent **or** copy into Google Forms (same items, 1–5 scale).

---

## How to run (team)

1. **Who:** Municipal Accountant (`admin`), at least 1–2 department heads, and clerks from offices that will use the pilot (ENG / HR / BUD / ACC / TRE / MAY as available).
2. **When:** After a short hands-on (login → register or scan → see dashboard / alerts). Use [docs/defense/START-HERE.md](../defense/START-HERE.md) DV trail if possible.
3. **Where (if client is far / not deployed yet):** use **Remote UAT** below — still valid for Capstone Objective 7 if you describe it honestly in Ch4/Ch5.
4. **Time:** ~10–15 minutes for the form after the demo.
5. **Consent:** Explain this is for school research / pilot evaluation; answers are for Capstone Objective 7; no financial data is collected.
6. **Encode:** For each item, score 5→1. Per characteristic: average the item scores (= WM if equal weights). Overall WM = average of the eight characteristic WMs (or average of all items — state which method you used in Ch5).
7. **Do not invent scores** — leave blank until the client answers.

### Remote UAT (recommended when Urbiztondo is far / system not on LGU LAN yet)

You **do not** need production deploy inside the municipal hall to run the survey. What you need is: (1) they **see** the working system, (2) they **try** main tasks or watch a live walkthrough, (3) they **answer** the form.

| Option | What you do | Good for |
| ------ | ----------- | -------- |
| **A. Screen-share demo + Google Form** (easiest) | Zoom/Meet/Messenger call → share screen → run DV trail with demo accounts → send Form link after | Municipal Accountant + heads who can join a call |
| **B. Temporary public URL** | Host API+web on a free/cloud host or tunnel (`ngrok` / similar) to your XAMPP → client opens browser on their PC | If they want to click themselves |
| **C. Recorded walkthrough + Form** | 8–12 min video of the same DV script → Form | If schedule is hard; weaker than live, but better than nothing — say “asynchronous demo” in Ch5 |
| **D. Hybrid** | Live call with Accountant; clerks fill Form after watching the same video | Minimum credible set: **1 Accountant + 2–3 clerks/heads** |

**Honest wording for the manuscript (use this):**

> User Acceptance Testing was conducted through a **remote demonstration** of the SmartFlow pilot build (web and/or mobile) with municipal respondents, followed by an online ISO/IEC 25010 questionnaire. On-site deployment on the municipal LAN is planned for later pilot use and is outside the evaluation session described here.

**Do not write:** “deployed and used daily in all Urbiztondo offices” if that did not happen.

**Panel one-liner:**  
*“Hindi pa production deploy sa hall — remote UAT demo + ISO questionnaire sa Municipal Accountant at selected staff; pilot deploy is next after Capstone.”*

**Minimum path this week**

1. Copy survey items into **Google Forms** (Likert 1–5).  
2. Book **one call** with the Municipal Accountant (you already have discovery contact).  
3. 20–30 min: screen-share START-HERE DV trail (ENG→…→TRE).  
4. Send Form link before ending the call.  
5. Encode answers → Chapter 5 Table 5.4.  

Flutter scan on *their* phone is optional for remote UAT — web demo of register + history + admin COA/QR monitor is enough if you explain mobile scan parity.

**Likert scale (same for all items):**

| Score | Meaning |
| ----- | ------- |
| 5 | Strongly Agree |
| 4 | Agree |
| 3 | Uncertain / Neutral |
| 2 | Disagree |
| 1 | Strongly Disagree |

---

## Instrument cover (print header)

**National Teachers College**  
School of Arts, Sciences and Technology — BS Information Technology  

**SmartFlow:** A QR-Based Inter-Department Document Flow Tracking and COA Compliance System for the Municipality of Urbiztondo  

**User Acceptance Evaluation Questionnaire (ISO/IEC 25010)**

---

### Part A — Respondent profile

| Field | Answer |
| ----- | ------ |
| Name (optional) | |
| Office | ☐ ENG ☐ HR ☐ BUD ☐ ACC ☐ TRE ☐ MAY ☐ Other: ______ |
| Role in SmartFlow | ☐ Clerk (staff) ☐ Department head ☐ Municipal Accountant / admin ☐ Other: ______ |
| Device used today | ☐ Web (browser) ☐ Android (Flutter) ☐ Both |
| Date | |

---

### Part B — ISO/IEC 25010 items

Circle or mark **one** score per statement (5 = Strongly Agree … 1 = Strongly Disagree).

#### 1. Functional suitability

| Code | Statement | 5 | 4 | 3 | 2 | 1 |
| ---- | --------- | - | - | - | - | - |
| FS1 | SmartFlow provides the functions I need to track or monitor document folders in my office. | | | | | |
| FS2 | Registering a document and getting a QR / tracking ID works as expected. | | | | | |
| FS3 | Scanning receive (IN) and forward (OUT) records the handoff correctly. | | | | | |
| FS4 | Dashboards / lists show where documents are and which ones need attention. | | | | | |

#### 2. Performance efficiency

| Code | Statement | 5 | 4 | 3 | 2 | 1 |
| ---- | --------- | - | - | - | - | - |
| PE1 | The system responds quickly enough for daily office use. | | | | | |
| PE2 | Login, register, and scan screens load without long delays on our network. | | | | | |
| PE3 | Completing a handoff (scan) takes less time than calling or walking to ask for status. | | | | | |

#### 3. Compatibility

| Code | Statement | 5 | 4 | 3 | 2 | 1 |
| ---- | --------- | - | - | - | - | - |
| CO1 | SmartFlow works with the devices we used (browser and/or Android phone). | | | | | |
| CO2 | Using SmartFlow fits our existing practice of moving **physical** folders between offices. | | | | | |
| CO3 | Web and mobile views are consistent enough that I can understand status either way. | | | | | |

#### 4. Usability

| Code | Statement | 5 | 4 | 3 | 2 | 1 |
| ---- | --------- | - | - | - | - | - |
| US1 | I can learn the main screens with brief training. | | | | | |
| US2 | Labels and buttons (Scan, Register, Requests, Alerts) are clear. | | | | | |
| US3 | Error messages (e.g. wrong scan / duplicate) are understandable. | | | | | |
| US4 | I can tell the difference between **requesting** a file and **registering** a folder on my desk. | | | | | |

#### 5. Reliability

| Code | Statement | 5 | 4 | 3 | 2 | 1 |
| ---- | --------- | - | - | - | - | - |
| RE1 | During the pilot session, SmartFlow worked without frequent crashes or freezes. | | | | | |
| RE2 | Document history / trail matched the scans we performed. | | | | | |
| RE3 | Rejected illegal actions (e.g. duplicate IN) behave consistently. | | | | | |

#### 6. Security

| Code | Statement | 5 | 4 | 3 | 2 | 1 |
| ---- | --------- | - | - | - | - | - |
| SE1 | Login is required before I can use office functions. | | | | | |
| SE2 | I only see information appropriate to my role / office (as far as I can tell). | | | | | |
| SE3 | Logging out ends my session on this device. | | | | | |
| SE4 | I understand SmartFlow tracks folder movement — it does not store the full document content or approve payments. | | | | | |

#### 7. Maintainability

| Code | Statement | 5 | 4 | 3 | 2 | 1 |
| ---- | --------- | - | - | - | - | - |
| MA1 | Account / profile and password options are reachable when I need them. | | | | | |
| MA2 | Admin / accountant tools (users, reports, thresholds, QR monitor) look organized enough for pilot use. | | | | | |
| MA3 | Problems during the demo could be explained or corrected by the research team without rewriting the whole workflow. | | | | | |

#### 8. Portability

| Code | Statement | 5 | 4 | 3 | 2 | 1 |
| ---- | --------- | - | - | - | - | - |
| PO1 | I can use SmartFlow on the office computer (web) assigned to our unit. | | | | | |
| PO2 | I can use SmartFlow on an Android phone for scanning (or I saw a colleague do so successfully). | | | | | |
| PO3 | Moving between offices / devices still makes sense for tracking the same folder. | | | | | |

---

### Part C — Open feedback (optional but useful for Ch5 discussion)

1. What did you like most about SmartFlow?  
   _______________________________________________________________

2. What was confusing or hard?  
   _______________________________________________________________

3. What should be improved before wider use in the LGU?  
   _______________________________________________________________

4. Would you recommend SmartFlow for **pilot** use in your office? ☐ Yes ☐ No ☐ Not sure  
   Why? _________________________________________________________

---

### Part D — Consent / sign-off (respondent)

I understand this questionnaire is for academic evaluation of the SmartFlow pilot. I answered based on my experience during the demonstration / UAT session.

Signature (optional): _________________ Date: _________

---

## Encoding sheet (researchers only — not for client)

| Characteristic | Item codes | Item scores (list) | Characteristic WM |
| -------------- | ---------- | ------------------ | ----------------- |
| Functional suitability | FS1–FS4 | | |
| Performance efficiency | PE1–PE3 | | |
| Compatibility | CO1–CO3 | | |
| Usability | US1–US4 | | |
| Reliability | RE1–RE3 | | |
| Security | SE1–SE4 | | |
| Maintainability | MA1–MA3 | | |
| Portability | PO1–PO3 | | |
| **Overall WM** | all items or mean of 8 WMs | | **state method in Ch5** |

Copy characteristic WMs into `docs/thesis/chapter-5-results-and-discussion.md` Table 5.4.

---

## Suggested minimum respondents (pilot)

| Role | Suggested minimum |
| ---- | ----------------- |
| Municipal Accountant / admin | 1 |
| Department head | 1–2 |
| Clerk | 2–4 |
| **Total** | **~4–7** is enough for a small-LGU Capstone pilot if adviser agrees |

More is better, but **one honest Municipal Accountant + clerks who actually scanned** beats a large fake sample.

---

## Note for defense

If panel asks “validated ba?”:  
*“Yes — after a hands-on UAT we gave an ISO/IEC 25010 Likert questionnaire to the Municipal Accountant and participating heads/clerks; results are in Chapter 5.”*  
Only say this after forms are actually filled.
