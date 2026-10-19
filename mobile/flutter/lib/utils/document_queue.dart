List<Map<String, dynamic>> documentQueue(
  List<Map<String, dynamic>> documents, {
  required String tray,
  bool overdueOnly = false,
  String search = '',
  String sort = 'urgency',
}) {
  double number(dynamic value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
  int wait(Map<String, dynamic> a, Map<String, dynamic> b) =>
      number(b['hours_waiting']).compareTo(number(a['hours_waiting']));
  final rows = documents
      .where(
        (d) =>
            (overdueOnly
                ? d['is_overdue'] == true && d['tray'] != 'completed'
                : d['tray'] == tray) &&
            '${d['id']} ${d['title']} ${d['reference_no'] ?? ''}'
                .toLowerCase()
                .contains(search.toLowerCase()),
      )
      .toList();
  rows.sort((a, b) {
    int result;
    if (sort == 'recent') {
      result = '${b['last_scanned_at'] ?? ''}'.compareTo(
        '${a['last_scanned_at'] ?? ''}',
      );
    } else if (sort == 'waiting') {
      result = wait(a, b);
    } else {
      result = (b['is_overdue'] == true ? 1 : 0).compareTo(
        a['is_overdue'] == true ? 1 : 0,
      );
      if (result == 0) {
        result = '${a['due_at'] ?? '9999'}'.compareTo(
          '${b['due_at'] ?? '9999'}',
        );
      }
      if (result == 0) result = wait(a, b);
    }
    return result != 0 ? result : '${a['id']}'.compareTo('${b['id']}');
  });
  return rows;
}

String elapsedLabel(dynamic hours) {
  final value = hours is num
      ? hours.toDouble()
      : double.tryParse('$hours') ?? 0;
  final minutes = (value.clamp(0, double.infinity) * 60).round();
  if (minutes < 60) return '$minutes min';
  if (minutes >= 1440) return '${minutes ~/ 1440}d ${(minutes % 1440) ~/ 60}h';
  return '${minutes ~/ 60}h ${minutes % 60}m';
}
