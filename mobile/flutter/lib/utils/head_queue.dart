// Head office queue: folders that need attention come first; finished folders stay reachable but out of the way.
// This mirrors web/src/head-queue.js so the same queue reads the same on the phone and in the browser.

const headQueuePageSize = 20;

const headQueueFilters = [
  'active',
  'overdue',
  'in_office',
  'awaiting',
  'completed',
  'all',
];

const headQueueSorts = ['attention', 'hoursDesc', 'hoursAsc', 'id'];

String _statusOf(Map item) =>
    '${item['status_label'] ?? ''}'.trim().toLowerCase();

/// OUT from this office with no receive recorded at the next office yet.
bool queueAwaitingReceive(Map item) =>
    item['last_status'] == 'OUT' &&
    '${item['meta'] ?? ''}'.toLowerCase().contains('awaiting receive');

enum HeadQueueState { overdue, awaiting, completed, inOffice, other }

/// The one state shown on a card: the server's overdue or completed label wins over the physical position.
HeadQueueState headQueueState(Map item) {
  final status = _statusOf(item);
  if (status == 'overdue') return HeadQueueState.overdue;
  if (queueAwaitingReceive(item)) return HeadQueueState.awaiting;
  if (status == 'completed') return HeadQueueState.completed;
  if (status == 'in_office') return HeadQueueState.inOffice;
  return HeadQueueState.other;
}

bool matchesQueueFilter(Map item, String filter) {
  switch (filter) {
    case 'all':
      return true;
    case 'active':
      return _statusOf(item) != 'completed';
    case 'overdue':
      return _statusOf(item) == 'overdue';
    case 'in_office':
      return _statusOf(item) == 'in_office';
    case 'awaiting':
      return queueAwaitingReceive(item);
    case 'completed':
      return _statusOf(item) == 'completed';
    default:
      return true;
  }
}

Map<String, int> queueCounts(Iterable<Map> queue) => {
  for (final filter in headQueueFilters)
    filter: queue.where((item) => matchesQueueFilter(item, filter)).length,
};

num _hoursOf(Map item) {
  final value = item['hours_pending'];
  final number = value is num ? value : num.tryParse('${value ?? ''}');
  return number == null || number.isNaN ? 0 : number;
}

int _rank(HeadQueueState state) => switch (state) {
  HeadQueueState.overdue => 0,
  HeadQueueState.inOffice => 1,
  HeadQueueState.awaiting => 2,
  HeadQueueState.other => 3,
  HeadQueueState.completed => 4,
};

/// Sorted copy. "attention" puts overdue first, then the longest waits; completed folders go last, newest first.
/// Equal folders keep the order the server sent them in.
List<Map<String, dynamic>> sortQueue(
  Iterable<Map<String, dynamic>> list,
  String sort,
) {
  final indexed = list.toList().asMap().entries.toList();
  int compare(Map a, Map b) {
    switch (sort) {
      case 'id':
        return '${a['document_id'] ?? ''}'.compareTo(
          '${b['document_id'] ?? ''}',
        );
      case 'hoursAsc':
        return _hoursOf(a).compareTo(_hoursOf(b));
      case 'hoursDesc':
        return _hoursOf(b).compareTo(_hoursOf(a));
      default:
        final stateA = headQueueState(a);
        final stateB = headQueueState(b);
        final byState = _rank(stateA) - _rank(stateB);
        if (byState != 0) return byState;
        return stateA == HeadQueueState.completed
            ? _hoursOf(a).compareTo(_hoursOf(b))
            : _hoursOf(b).compareTo(_hoursOf(a));
    }
  }

  indexed.sort((a, b) {
    final result = compare(a.value, b.value);
    return result != 0 ? result : a.key.compareTo(b.key);
  });
  return [for (final entry in indexed) entry.value];
}

List<Map<String, dynamic>> filterQueue(
  Iterable<Map<String, dynamic>> queue, {
  String filter = 'active',
  String query = '',
  String sort = 'attention',
}) {
  final q = query.trim().toUpperCase();
  final list = queue.where((item) {
    if (!matchesQueueFilter(item, filter)) return false;
    if (q.isEmpty) return true;
    return '${item['document_id'] ?? item['id'] ?? ''}'.toUpperCase().contains(
          q,
        ) ||
        '${item['title'] ?? ''}'.toUpperCase().contains(q);
  });
  return sortQueue(list, sort);
}

/// Whole hours below two days, days and leftover hours from then on, so "96h" reads as "4d".
String queueSpanLabel(Object? hours) {
  final number = hours is num ? hours : num.tryParse('${hours ?? ''}');
  if (number == null || number.isNaN || number.isInfinite) return '';
  final value = number.floor();
  if (value < 1) return '';
  if (value < 48) return '${value}h';
  final days = value ~/ 24;
  final rest = value % 24;
  return rest > 0 ? '${days}d ${rest}h' : '${days}d';
}

/// Completed folders say when they finished; the others say how long they have been waiting.
String queueWaitLabel(Map item) {
  final span = queueSpanLabel(item['hours_pending']);
  if (headQueueState(item) == HeadQueueState.completed) {
    return span.isEmpty ? 'Completed just now' : 'Completed $span ago';
  }
  return span.isEmpty ? 'Just recorded' : '$span waiting';
}
