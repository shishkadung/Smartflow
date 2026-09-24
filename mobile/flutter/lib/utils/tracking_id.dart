/// Extract SmartFlow document ID from QR payload or manual entry.
String? parseTrackingId(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;

  if (isSignedQrPayload(trimmed)) {
    return null;
  }

  final direct = RegExp(r'^DOC-\d{4}-\d{6}$', caseSensitive: false);
  if (direct.hasMatch(trimmed)) {
    return trimmed.toUpperCase();
  }

  final embedded = RegExp(r'DOC-\d{4}-\d{6}', caseSensitive: false);
  final match = embedded.firstMatch(trimmed);
  if (match != null) {
    return match.group(0)!.toUpperCase();
  }

  return null;
}

/// Secured label format: SF1.{payload}.{signature}
bool isSignedQrPayload(String raw) {
  final trimmed = raw.trim();
  if (!trimmed.startsWith('SF1.')) return false;
  final parts = trimmed.split('.');
  return parts.length == 3 && parts[0] == 'SF1' && parts[1].isNotEmpty && parts[2].isNotEmpty;
}

/// Clerk UI: whether IN / OUT actions are allowed (mirrors server rules).
({bool canIn, bool canOut, String statusLine, String? blockReason}) clerkScanActions({
  required Map<String, dynamic>? lastMovement,
  required int myOfficeId,
  String? currentStatus,
  int? currentOfficeId,
  String? currentOfficeName,
}) {
  final lastStatus = currentStatus?.toUpperCase();
  final lastOfficeId = currentOfficeId;

  if (lastStatus == null || lastOfficeId == null) {
    return (
      canIn: true,
      canOut: false,
      statusLine: 'No scans yet — mark IN when the document arrives',
      blockReason: null,
    );
  }

  final office = currentOfficeName ?? 'office #$lastOfficeId';
  final statusLine = '$lastStatus at $office';

  if (lastStatus == 'IN' && lastOfficeId == myOfficeId) {
    return (
      canIn: false,
      canOut: true,
      statusLine: statusLine,
      blockReason: null,
    );
  }

  if (lastStatus == 'OUT' && lastOfficeId == myOfficeId) {
    return (
      canIn: false,
      canOut: false,
      statusLine: statusLine,
      blockReason: 'Already forwarded from your office. Receiving office must scan IN.',
    );
  }

  if (lastStatus == 'IN' && lastOfficeId != myOfficeId) {
    return (
      canIn: false,
      canOut: false,
      statusLine: statusLine,
      blockReason: 'Still at $office. They must mark OUT before you can receive it.',
    );
  }

  // Last OUT from another office → receive here.
  return (
    canIn: true,
    canOut: false,
    statusLine: statusLine,
    blockReason: null,
  );
}
