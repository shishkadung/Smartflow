# Figure 1.3 - SmartFlow Data Flow Diagram Level 1

This figure represents the implemented SmartFlow data flow as of 29 September 2026.

## External Entities

- **E1 Staff / Clerk** supplies credentials, document-registration data, scans, and request actions and receives status, tracking, and notification information.
- **E2 Department Head** performs the shared operational workflow and receives assigned-office monitoring, queue, delay, and request information.
- **E3 Municipal Accountant / Admin** reviews signups, administers users, offices, and thresholds, monitors municipality-wide custody and audit data, and generates COA flow reports.

## Processes

1. **Authenticate User and Apply Role Access** validates an active account and establishes the user's role and assigned office.
2. **Register Held Document and Generate Signed QR + Initial IN** creates the document record, tracking identity, signed QR payload, and initial custody movement.
3. **Verify QR / Tracking ID and Record Movement** validates the scan session, QR, custody, destination, and duplicate rules before recording IN, OUT, or return.
4. **Create and Process Document Requests** handles access and pull requests independently from physical QR custody.
5. **Monitor Custody, Delays, Queues, Alerts, and Movement History** reads the latest movements and processing thresholds to produce operational status.
6. **Administer Accounts, Offices, Thresholds, Audits, and COA Flow Reports** manages configuration and produces authorized municipality-wide outputs.

## Data Stores

- **D1** Users and Offices
- **D2** Signup Requests
- **D3** Documents
- **D4** Movements
- **D5** Document Requests
- **D6** Processing Thresholds
- **D7** Audit Logs

The DFD intentionally excludes approval of disbursements, payroll, and financial transactions because those are outside SmartFlow's implemented scope.
