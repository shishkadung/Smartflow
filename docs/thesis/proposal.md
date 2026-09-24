

**TITLE PROPOSAL**

   

|  |  |
| :---- | :---- |
| **RESEARCHER:** | Member 1: Pascua, Neil John A. Member 2: Basit, Krizandra Josephine L. Member 3: Buenaventura, Angel A. Member 4: Fallarcuna, Rainier B. Member 5: Fernandez, Kristofer Cyle |
|  **Proposed Project Title 3:  SmartFlow: A QR-Based Inter-Department Document Flow Tracking and COA Compliance System for the Municipality of Urbiztondo** |  |

       

1. **Area of Investigation:**

The Municipality of Urbiztondo operates through several interconnected offices including Engineering, HR, Budget, and Accounting that depend on one another to process financial and administrative documents. Disbursement vouchers, payroll records, and approved budgets must pass through multiple departments before the Municipal Accountant can consolidate them and prepare reports for the Commission on Audit (COA).

Currently, there is no system that shows where a document is at any given time, how long it has been sitting in a certain office, or which department is causing delays. Staff resort to phone calls, personal visits, and messaging apps just to check whether something has been forwarded. This cycle of manual follow-ups consumes time, creates stress, and slows down processes that are already running on tight deadlines.

An initial interview was conducted with the Municipal Accountant, as the Accounting office serves as the convergence point where all inter-department financial documents ultimately arrive. This makes the Accountant the most positioned respondent to identify where delays originate across multiple offices. The respondent confirmed that recording is not continuous because other departments submit documents late. The office also cited slow consolidation of reports and manual counting of data as recurring issues. When asked what an ideal system would look like, the respondent described one that connects to all departments with financial transactions to speed up recording and preparation of reports.

This study investigates how a QR-based document tracking system can provide real-time visibility over the movement of financial documents between offices, identify bottleneck departments, and support timely COA compliance  without replacing or digitizing the documents themselves.

2. **Background and Rationale of the Project/System:**

In local government units, financial accountability starts with paperwork. Before the Municipal Accountant can prepare a financial statement or submit a report to COA, documents need to move from one office to another, disbursement vouchers from Engineering, payroll records from HR, approved budgets from Budget. Each must be checked, signed, and forwarded before reaching Accounting for consolidation.

In Urbiztondo, this process is entirely manual. There is no MIS or IT system in use. Documents are handed off physically, and tracking relies on staff initiative  calling, walking over, or messaging through group chats. The problem is not that these steps are complicated. The problem is that nobody knows where a document is until someone asks.

This matters because COA deadlines are not flexible. If even one department is late forwarding its documents, the entire consolidation gets delayed. The Municipal Accountant ends up compiling data manually in Excel  counting, cross-checking, and summarizing numbers that should have arrived days earlier. The respondent identified three main challenges: lack of employees, low technology knowledge, and late submissions from other departments. That third point means the Accounting office's own output is directly bottlenecked by how fast other offices move their paperwork and right now, there is no way to measure, flag, or address that delay.

SmartFlow takes a different approach from typical LGU capstones. Instead of digitizing documents or replacing workflows, it tracks the physical movement of documents using QR codes. Each document gets a QR tag at creation. Every handoff is logged by scanning, capturing the document ID, office, personnel, and timestamp. The dashboard then shows where every active document is, how long it has been there, and whether it is overdue. COA reports can be generated automatically from the logged data, and departments that consistently delay submissions show up in analytics. The only new step for staff is a quick scan at each handoff of a task that takes seconds on a smartphone or desktop with a camera, and one that replaces the far more time-consuming cycle of follow-up calls, personal visits, and repeated status inquiries that staff currently deal with throughout the day.

3. **Statement of Objectives:**

This project aims to develop a QR-based inter-department document flow tracking and COA compliance system for the Municipality of Urbiztondo. Specifically, it aims to:

1. Develop a QR tagging module that generates a unique QR code for each financial document at the point of origin, enabling it to be tracked across departments.

2. Build a scan-and-forward tracking feature that logs each handoff—capturing the document ID, receiving office, scanning personnel, and timestamp—creating a real-time audit trail of document movement.

3. Provide a real-time dashboard displaying all active documents, their current location, time at each office, and overdue status.

4. Implement automated alerts that flag documents exceeding expected processing time at any department.

5. Develop a COA-aligned summary report module that generates monthly, quarterly, and annual document flow reports—including total documents processed, average processing time per department, late submission counts, and completion rates—to support the Accounting office in preparing its COA submissions.

6. Include department performance analytics that identify patterns in submission speed, late counts, and recurring bottlenecks.

7. Evaluate the system's usability and effectiveness through feedback from Accounting staff, department heads, and frontline personnel.

4. **Scope and Limitations of the Study:**

   **Scope:**

   

The study covers the design, development, and evaluation of a QR-based document flow tracking system for the Municipality of Urbiztondo. It will track disbursement vouchers, payroll records, and approved budgets moving between the Accounting, Budget, HR, and Engineering offices. Core features include QR tagging, scan-and-forward logging, a real-time status dashboard, automated delay alerts, department performance analytics, and a COA-aligned document flow summary report generator. The system will run on the desktops, laptops, and smartphones already available in the participating offices.

**Limitations:**

*  The system covers only financial and administrative documents critical to COA compliance. Other document types may be added in future versions.  
    
* Pilot testing is limited to the Accounting, Budget, HR, and Engineering offices. Wider LGU adoption will be considered after evaluation.  
    
* Advanced IoT features such as RFID or NFC scanning are classified as future enhancements and will not be included in the initial version.  
    
* The COA-aligned report module generates document flow summaries (processing times, late counts, completion rates) to support COA preparation  it does not generate the actual financial statements, which remain the responsibility of the Accounting office.  
    
* Hardware and hosting infrastructure will be handled by the LGU and are outside the scope of this study.  
    
* The system's effectiveness depends on consistent scanning at each handoff. Skipped scans will result in incomplete tracking data.

5. **Target Beneficiaries:**  
   

**Municipal Accountant and Accounting Staff**  gains a dashboard showing where every document is and which ones are overdue, eliminating constant follow-ups. The auto-report generator reduces manual effort for COA submissions.

**Department Heads (Engineering, HR, Budget)** gain visibility into their own office's processing speed, helping them manage workloads and avoid late submission flags.

**Frontline Staff**  the scan log serves as proof of forwarding, reducing interruptions from repeated follow-up questions.

**Municipal Management** gains performance analytics revealing which offices are consistently slow, enabling systemic fixes rather than case-by-case complaints.

**Commission on Audit (COA)** benefits from more accurate and timely report submissions, reducing audit discrepancies.

**Citizens of Urbiztondo**  faster internal processing means quicker payroll releases, timely project funding, and stronger public trust through improved transparency.

6. **References:**

* Commission on Audit (COA). (2022). Annual Audit Reports on Local Government Units.  

  – Provides official findings on LGU compliance, highlighting recurring issues in delayed submissions and incomplete documentation. Directly supports the need for a tracking system like SmartFlow.

* Department of Budget and Management (DBM). (2022). Enhanced Public Financial Management Assessment Tool (ePFMAT) for Local Government Units.  

  – A framework for evaluating LGU financial management systems. Identifies weaknesses in document flow and reporting, which SmartFlow addresses through QR-based tracking and automated COA report generation.

* Philippine Institute for Development Studies (PIDS). (2022). Digital Transformation in Local Government Units.  

  – Policy research showing how digital tools improve efficiency, transparency, and citizen trust in LGUs. SmartFlow aligns with this by introducing QR-based tracking into traditional paper-based workflows.

* Asian Development Bank (ADB). (2022). Philippines: Local Governance Reform Project.  

  – Highlights inefficiencies in LGU operations and recommends digital solutions. SmartFlow is consistent with these recommendations, offering a practical innovation for document flow monitoring.

* World Bank. (2022). Philippines Local Governance Reform Program.  

  – Emphasizes accountability and transparency in LGUs. SmartFlow contributes to these goals by making document movement visible and measurable, reducing bureaucratic delays.

* Tabia, V. U. (2022). Records Management and Data Security in Local Government Units. Provincial Government of Laguna.  

  – Research emphasizing the importance of proper records management and secure handling of government documents. Supports your innovation by showing that LGUs need systems that ensure both efficiency and accountability.

* Balangat, E. S. (2022). Status of the Records Management System of LGU Calanasan: Recommendation for Records Management System. ISRG Journal of Arts, Humanities and Social Sciences.  

  – A study evaluating LGU records management practices. Highlights issues such as delayed submissions, poor accessibility, and lack of transparency — the same problems SmartFlow addresses in Urbiztondo.


  