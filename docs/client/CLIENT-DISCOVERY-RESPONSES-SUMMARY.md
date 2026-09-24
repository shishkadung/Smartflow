# Client Discovery — Implementation Summary

**Source:** Municipal Accountant / Head of Accounting (Urbiztondo)  
**Applied to SmartFlow:** May 2026 (updated for Treasury / Mayor in pilot)

## Pilot scope (confirmed)

| Item | Client answer | System change |
|------|---------------|---------------|
| Demo priority | **DV trail** | Demo script — Part 2 = DV |
| Document types | **DV + Approved Budget** | Register dropdowns per office |
| Payroll | **Payslip access only** | No HR payroll QR; payroll requests hidden |
| DV path | ENG → BUD → ACC → **TRE → MAY → TRE** | `routing-helper.php` + Flutter `suggest_forward_office.dart` |
| After ACC | Treasury → Mayor → Treasury (check release) | Offices TRE/MAY seeded; `pilot_end_note` on Scan |
| Accounting DV requests | Must not self-request | API + UI block for ACC |
| Required-by date | **Mandatory** on requests | `required_by` column + Flutter picker |
| Rejection | In-app + **separate notice** | Dialog after decline |
| Fulfillment | **Treasury** after payment | ACC Accept → TRE “Mark payment released” |
| COA export | **Accounting only** | `reports-summary.php` + admin UI |
| Audit gaps | Flag exceptions | `audit-exceptions.php` + admin list |
| Logbook | Mirror fields | Reference, payee, fund source on register |
| Pilot offices | Include Treasury (client) | ENG, HR, BUD, ACC, **TRE**, **MAY** |

## Still clarify with client

- Budget QR: holder office (Budget) vs Engineering answer — follow **holder rule** until confirmed.
- Section 12 confirmation table — blank in response.

## Defense limitation (one line)

*SmartFlow tracks physical custody of DVs and approved budgets through ENG → BUD → ACC → TRE → MAY → TRE; payment release itself is recorded by Treasury on the request ticket, not as a financial approval engine. Payroll remains payslip-access only (no payroll folder QR).*
