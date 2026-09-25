/// Pilot document types per office (validated with Municipal Accountant).
/// Physical QR: **Disbursement Voucher** and **Approved Budget**.
/// Payroll uses payslip access — no payroll QR. Others is a named folder that is not a DV or an approved budget.
const String kOtherDocumentType = 'Others';
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
  final types = List<String>.from(
    kOfficeDocumentTypes[code] ??
        const [
          'Disbursement Voucher',
          'Approved Budget',
        ],
  );
  if (!types.contains(kOtherDocumentType)) {
    types.add(kOtherDocumentType);
  }
  return types;
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
  items.add(const MapEntry('other', 'Others'));
  return items;
}
