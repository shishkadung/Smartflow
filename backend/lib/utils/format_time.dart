import 'package:intl/intl.dart';

/// Friendly relative time for movement timestamps from the API.
String formatSmartflowTime(String? raw) {
  if (raw == null || raw.isEmpty) return '—';
  final normalized = raw.contains('T') ? raw : raw.replaceFirst(' ', 'T');
  final dt = DateTime.tryParse(normalized);
  if (dt == null) return raw;

  final local = dt.isUtc ? dt.toLocal() : dt;
  final diff = DateTime.now().difference(local);

  if (diff.inSeconds < 45) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 48) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return DateFormat('MMM d, h:mm a').format(local);
}

/// List rows for today's movements — always shows clock time so two "Just now" rows differ.
String formatMovementListTime(String? raw) {
  if (raw == null || raw.isEmpty) return '—';
  final normalized = raw.contains('T') ? raw : raw.replaceFirst(' ', 'T');
  final dt = DateTime.tryParse(normalized);
  if (dt == null) return raw;

  final local = dt.isUtc ? dt.toLocal() : dt;
  final now = DateTime.now();
  final clock = DateFormat('h:mm a').format(local);
  final sameDay = local.year == now.year &&
      local.month == now.month &&
      local.day == now.day;

  if (sameDay) return clock;

  final diff = now.difference(local);
  if (diff.inDays < 7) {
    return '${DateFormat('MMM d').format(local)} · $clock';
  }
  return DateFormat('MMM d, h:mm a').format(local);
}

/// Subtitle under a movement row on home / history (time · route · staff).
String movementScanSubtitle(Map<String, dynamic> m) {
  final st = m['status']?.toString() ?? '';
  final user = m['user_name']?.toString();
  final dest = m['destination_office_code']?.toString();
  final time = formatMovementListTime(m['scanned_at']?.toString());
  final parts = <String>[time];
  if (st == 'OUT' && dest != null && dest.isNotEmpty) {
    parts.add('To $dest');
  } else if (st == 'IN') {
    parts.add('At your office');
  }
  if (user != null && user.isNotEmpty) {
    parts.add(user);
  }
  return parts.join(' · ');
}

/// Short page captions — shared web/mobile (no per-office essays).
String dashboardSubtitleForOffice(String officeCode) {
  return "Today's received, sent, and folders on desk.";
}

String registerSubtitleForOffice(String officeCode) {
  return 'Only when the folder is already in your custody.';
}

String scanSubtitleForOffice(String officeCode) {
  return 'Look up a folder, then Mark IN or Mark OUT.';
}

/// Head dashboard caption (office-agnostic).
String headDashboardSubtitleForOffice(String officeCode) {
  return 'Folders currently at your office.';
}

String headQueueSubtitleForOffice(String officeCode) {
  return 'Folders in your office — filter and open for history.';
}

/// Clerk document requests.
String requestsSubtitleForOffice(String officeCode) {
  return 'Accepting does not move the folder — register or scan when it arrives.';
}

/// Head monitor view for office request inbox.
String headRequestsSubtitleForOffice(String officeCode) {
  return 'Monitor tickets for your office — clerks fulfill handoffs.';
}
