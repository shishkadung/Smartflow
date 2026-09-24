# CHAPTER 6: SUMMARY, CONCLUSIONS, AND RECOMMENDATIONS

Paste into Capstone 2 after Chapter 5. Adjust tense and numbers after ISO results are final.

---

## 6.1 Summary

This Capstone Project developed **SmartFlow**, a QR-based inter-department document flow tracking and COA *support* system for the Municipality of Urbiztondo. The problem addressed was the lack of continuous visibility over **physical** financial and administrative folders as they move among municipal offices, which forced staff to rely on calls, visits, and chat follow-ups and slowed consolidation work needed for Commission on Audit (COA) deadlines.

SmartFlow was built as a **hybrid** system: **React (Vite)** web client, **Flutter** Android client, **PHP** REST API, and **MySQL**, following a **Waterfall** development life cycle. Core capabilities include signed QR tagging at registration, scan-based receive/forward logging, role-based dashboards (`staff`, `head`, `admin`), threshold-driven overdue alerts, formal document requests when a folder is not yet on desk, Account & security (including email for password reset), and municipal COA-oriented flow summaries / QR monitoring for the Municipal Accountant.

Pilot coverage in the implemented system includes **Engineering, Human Resources, Budget, Accounting, Treasury, and Mayor’s Office** (ENG, HR, BUD, ACC, TRE, MAY). A representative disbursement-voucher custody path used in validation is **ENG → BUD → ACC → TRE → MAY → TRE**. The system tracks folder location and timing; it does **not** digitally approve payments or generate COA financial statements.

Software testing progressed from unit through integration and system testing to User Acceptance Testing (Chapter 4). Evaluation for Specific Objective 7 used an **ISO/IEC 25010** questionnaire after structured UAT tasks; detailed scores appear in Chapter 5.

---

## 6.2 Conclusions

Based on the design, implementation, testing, and evaluation of SmartFlow, the researchers conclude that:

1. **Objective 1.** A QR tagging module can assign each registered financial/administrative folder a unique tracking identity and a **signed** QR suitable for labeling and later verification at handoffs.

2. **Objective 2.** Scan-and-forward logging (IN/OUT) can create a real-time audit trail of custody—document, office, user, and timestamp—provided staff scan consistently.

3. **Objective 3.** Role-based dashboards can show active documents, current location, elapsed time, and overdue status at municipal or office scope as appropriate to `admin`, `head`, and `staff`.

4. **Objective 4.** Configurable processing thresholds can drive automated overdue alerts for clerks, heads, and the Municipal Accountant.

5. **Objective 5.** COA-aligned **flow** summaries (counts, times, late indicators, completion-oriented metrics) can be generated from live tracking data to **support** Accounting’s COA preparation without replacing financial statements.

6. **Objective 6.** Department-oriented views and municipal analytics can surface slower offices and recurring bottlenecks for management attention.

7. **Objective 7.** Structured UAT plus an ISO/IEC 25010 questionnaire is a workable evaluation design for a small-LGU pilot. *[After scores: state overall WM and whether users Agree / Strongly Agree that SmartFlow is acceptable for pilot use.]*

8. **Overall.** SmartFlow is suitable as a **pilot** custody-tracking system for Urbiztondo’s participating offices. Its effectiveness depends on scan discipline, training, and continued administrator oversight. It is a tracking and accountability aid—not a document imaging system, payment approval system, or automated financial-statement generator.

---

## 6.3 Recommendations

### 6.3.1 For the Municipality of Urbiztondo

1. Adopt SmartFlow first as a **controlled pilot** in the six offices already seeded in the system, with a short training session per role (clerk, head, accountant).
2. Enforce a simple operating rule: **request** when the folder is not on your desk; **register + scan** when it is; the holder of the folder registers.
3. Assign the Municipal Accountant (or designated admin) to approve sign-ups, tune thresholds, and review the QR monitor for repeated rejects.
4. Keep physical folders as the official records; treat SmartFlow history as supporting evidence of custody and delay, not as a substitute for signed paper.

### 6.3.2 For Future System Enhancements

1. Harden production hosting (HTTPS, backups, password policy, audit retention) with LGU IT before wide rollout.
2. Expand document-type coverage only after client confirmation (retain **no payroll-folder QR** unless the LGU later requests it).
3. Optional notifications (email/SMS) for overdue items beyond in-app alerts.
4. Optional offline / queue-tolerant scanning if municipal connectivity remains intermittent.
5. Broader UAT sample and post-pilot metrics after at least one full reporting period.

### 6.3.3 For Future Researchers

1. Replicate the custody-tracking (not full digital approval) approach in other LGUs and compare ISO/IEC 25010 outcomes.
2. Study behavioral factors that affect scan compliance and incomplete trails.
3. Explore privacy-preserving analytics that help COA preparation without exposing unnecessary personal data.

---

## 6.4 Closing Statement

SmartFlow demonstrates that a small municipality can gain clearer visibility over inter-office financial paperwork by tagging physical folders and logging handoffs digitally. With disciplined use and continued refinement, the system can reduce follow-up friction and strengthen the evidence trail that supports timely COA-related work in Urbiztondo.
