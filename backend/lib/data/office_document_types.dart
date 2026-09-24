/// Pilot document types per office (validated with Municipal Accountant).
/// Physical QR: **Disbursement Voucher** and **Approved Budget**.
/// Payroll uses payslip access — no physical QR registration in HR.
const Map<String, List<String>> kOfficeDocumentTypes = {
  'ENG': ['Disbursement Voucher'],
  'HR': [],
  'BUD': ['Approved Budget'],
  'ACC': [
    'Disbursement Voucher',
    'Approved Budget',
  ],
  'TRE': ['Disbursement Voucher'],
  'MAY': ['Disbursement Voucher'],
};

List<String> documentTypesForOffice(String officeCode) {
  final code = officeCode.trim().toUpperCase();
  return kOfficeDocumentTypes[code] ??
      const [
        'Disbursement Voucher',
        'Approved Budget',
      ];
}

/// Inter-office request categories shown in the app (payroll omitted — ACC prepares payroll).
List<MapEntry<String, String>> documentRequestCategoriesForOffice(String officeCode) {
  final code = officeCode.toUpperCase();
  final items = <MapEntry<String, String>>[];

  if (code != 'BUD') {
    items.add(const MapEntry('budget', 'Budget (→ BUD)'));
  }
  // Disbursement requests go to Accounting; ACC processes incoming DVs — no self-request.
  if (code != 'ACC') {
    items.add(const MapEntry('disbursement', 'Disbursement / DV (→ ACC)'));
  }
  return items;
}
