/// Optional hint below API message when [scan_error] / [qr_error] is returned.
String? scanErrorHint({String? scanError, String? qrError}) {
  final code = scanError ?? qrError;
  if (code == null || code.isEmpty) return null;

  switch (code) {
    case 'duplicate':
      return 'Wait a few seconds — the first scan was already saved.';
    case 'already_in_here':
      return 'Use Mark OUT when you forward the folder to another office.';
    case 'already_out_here':
      return 'The next office must Mark IN when they receive it.';
    case 'still_at_other_office':
    case 'not_in_at_office':
    case 'out_without_in':
      return 'Follow the physical custody: IN when it arrives, OUT when you send it.';
    case 'wrong_receiver':
      return 'Only the office named on the last OUT can Mark IN.';
    case 'scan_session_expired':
      return 'Open Scanner and scan the label again before Mark IN/OUT.';
    case 'qr_expired':
      return 'Accounting can reprint a fresh secured label.';
    case 'qr_tampered':
    case 'qr_invalid':
    case 'qr_malformed':
      return 'Reprint the label from SmartFlow — do not edit the QR.';
    case 'qr_mismatch':
      return 'Make sure you scanned the label on this folder.';
    default:
      return null;
  }
}
