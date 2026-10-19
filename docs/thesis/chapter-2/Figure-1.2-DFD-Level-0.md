# SmartFlow Data Flow Diagram - Level 0

The Level 0 Data Flow Diagram presents SmartFlow as a single process and identifies the external entities that exchange information with the system. Internal processes and data stores are intentionally omitted because they are expanded in the Level 1 DFD.

## External Entities and Data Flows

### E1 Municipal Employee / Applicant

Inputs signup details, selected office, and requested role. SmartFlow returns a request code and the signup approval status.

### E2 Staff / Clerk

Inputs credentials, document-registration details, QR scans or tracking IDs, IN/OUT information, destinations, return reasons, and document-request actions. SmartFlow returns authentication results, signed QR information, custody results, current location and history, request statuses, office queue information, and alerts.

### E3 Department Head

Inputs credentials, the same authorized operational data as Staff / Clerk, and office-monitoring requests. SmartFlow returns assigned-office queues, analytics, delayed-document information, alerts, and request statuses.

### E4 Municipal Accountant / Admin

Inputs credentials, signup decisions, user and office administration changes, threshold settings, audit filters, and report requests. SmartFlow returns municipality-wide dashboards, configuration results, custody information, QR and audit exceptions, system status, and authorized PDF/CSV COA flow reports.

## Scope Clarification

Treasury, Mayor, Budget, Engineering, HR, and Accounting are office destinations within SmartFlow's routing data. They are not separate application roles or external entities. SmartFlow records document custody and supports COA reporting; it does not approve disbursements, payroll, or other financial transactions.
