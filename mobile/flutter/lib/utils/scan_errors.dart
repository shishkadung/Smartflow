/// Optional hint below API message when [scan_error] / [qr_error] is returned.
String? scanErrorHint({String? scanError, String? qrError}) {
  final code = scanError ?? qrError;
  if (code == null || code.isEmpty) return null;

  switch (code) {
    case 'duplicate':
      return 'Wait a few seconds — the first scan was already saved.';
    case 'already_in_here':
      return 'Use Send (OUT) when you forward the folder to another office.';
    case 'already_out_here':
      return 'The next office confirms actual receipt. Use Correct recorded destination if the unreceived OUT names the wrong office.';
    case 'still_at_other_office':
    case 'not_in_at_office':
    case 'out_without_in':
      return 'Follow the physical custody: IN when it arrives, OUT when you send it.';
    case 'wrong_receiver':
      return 'Only the recorded destination can confirm actual receipt. Ask the sending office to correct a wrong destination before receipt.';
    case 'scan_session_expired':
      return 'Open Scanner and scan the label again before Receive (IN) / Send (OUT).';
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
