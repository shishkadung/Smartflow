bool isOtherDocumentType(String type) =>
    type.trim().toLowerCase().startsWith('others:');

bool isDisbursementDocumentType(String type) {
  final value = type.trim().toLowerCase();
  return !isOtherDocumentType(type) &&
      (value.contains('disbursement') || value.contains('voucher'));
}

bool isApprovedBudgetDocumentType(String type) {
  final value = type.trim().toLowerCase();
  return !isOtherDocumentType(type) &&
      (value.contains('approved budget') || value == 'budget');
}
