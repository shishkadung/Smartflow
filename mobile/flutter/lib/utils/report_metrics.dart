import 'package:intl/intl.dart';

/// Wording helpers for the report figures that measure time at an office. They match web/src/report-metrics.js so a
/// figure reads the same on the phone and in the browser.

/// A number the way the web prints it: `5` for 5.0, `5.5` for 5.5.
String reportNumber(num value) {
  if (value is int) return '$value';
  return value == value.roundToDouble() ? '${value.toInt()}' : '$value';
}

num? _number(Object? value) {
  if (value is num) return value.isNaN ? null : value;
  return num.tryParse('${value ?? ''}');
}

/// `5 h`, or `60 h (2.5 days)` from 48 hours up.
String formatHours(Object? hours) {
  final value = _number(hours) ?? 0;
  return value >= 48
      ? '${reportNumber(value)} h (${(value / 24).toStringAsFixed(1)} days)'
      : '${reportNumber(value)} h';
}

/// `October 2026`, or `Oct` when [short]. A value that is not `YYYY-MM` is returned as it was given.
String reportMonthLabel(Object? month, {bool short = false}) {
  final parts = '${month ?? ''}'.split('-');
  if (parts.length != 2) return '${month ?? ''}';
  final year = int.tryParse(parts[0]);
  final number = int.tryParse(parts[1]);
  if (year == null || number == null || number < 1 || number > 12) {
    return '${month ?? ''}';
  }
  final date = DateTime(year, number);
  return short
      ? DateFormat('MMM').format(date)
      : DateFormat('MMMM yyyy').format(date);
}

/// One sentence for the earlier-versus-later comparison, or an honest note when there is too little to compare.
String reportTrendLabel(Map? trend) {
  if (trend == null || trend['direction'] == 'insufficient') {
    return 'Not enough forwarded folders to show a trend';
  }
  final change = (_number(trend['change_hours']) ?? 0).abs();
  final span =
      '${trend['earlier_avg_hours']} h → ${trend['later_avg_hours']} h';
  return switch (trend['direction']) {
    'slower' => 'Slower by ${reportNumber(change)} h ($span)',
    'faster' => 'Faster by ${reportNumber(change)} h ($span)',
    _ => 'Steady ($span)',
  };
}

/// Short number printed on a bar: one decimal below 10 h, whole hours from 10 h up.
String reportBarValueLabel(Object? hours) {
  final value = _number(hours);
  if (value == null) return '';
  return reportNumber(value < 10 ? (value * 10).round() / 10 : value.round());
}

/// Share of the plot height a month's average fills. A forwarded month keeps a visible minimum; a month without one is empty.
double reportBarFraction(Object? hours, num scale) {
  final value = _number(hours);
  if (value == null || !(scale > 0)) return 0;
  return (value / scale).clamp(0.06, 1.0).toDouble();
}

/// Offices with a recurring bottleneck first, then slowest first; offices without a forwarded folder go last.
List<Map<String, dynamic>> sortPerformanceOffices(Iterable? offices) {
  final list = [
    for (final office in offices ?? const [])
      Map<String, dynamic>.from(office as Map),
  ];
  num? average(Map<String, dynamic> office) =>
      _number((office['totals'] as Map?)?['avg_hours']);
  bool flagged(Map<String, dynamic> office) =>
      (office['bottleneck'] as Map?)?['recurring'] == true;
  list.sort((a, b) {
    final byFlag = (flagged(b) ? 1 : 0) - (flagged(a) ? 1 : 0);
    if (byFlag != 0) return byFlag;
    final left = average(a);
    final right = average(b);
    if (left == null && right != null) return 1;
    if (left != null && right == null) return -1;
    if (left != right) return right!.compareTo(left!);
    return '${a['office_code']}'.compareTo('${b['office_code']}');
  });
  return list;
}

/// `5 h on average before forwarding · 12 visits · 3 late (25%)`, or an honest note when nothing was visited.
String reportVisitsLine(Map? totals) {
  final visits = _number(totals?['visits']) ?? 0;
  if (visits == 0) return 'No office visits in this window';
  final average = totals?['avg_hours'] == null
      ? 'No folder forwarded yet'
      : '${formatHours(totals?['avg_hours'])} on average before forwarding';
  return '$average · ${reportNumber(visits)} visits · ${totals?['late']} late (${totals?['late_percent']}%)';
}
