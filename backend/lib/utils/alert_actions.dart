import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Per-device store of alert acknowledgements and snoozes.
///
/// MVP scope: local-only so a clerk can clear noise during a pilot day.
/// For production, replace with a server-backed `alert_actions` table so
/// other clerks/heads see the same acknowledgements.
class AlertActionsStore {
  AlertActionsStore._();

  static const _key = 'sf_alert_actions_v1';

  /// `Map<actionKey, ISO8601 DateTime>`
  /// - actionKey: `${documentId}::${kind}`
  /// - For `ack`, value is when it was acknowledged (any time in past = hidden).
  /// - For `snooze`, value is the snooze-until timestamp.
  static Future<Map<String, DateTime>> _readMap(String prefix) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('${_key}_$prefix');
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = json.decode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) {
        return MapEntry(k, DateTime.parse(v as String));
      });
    } catch (_) {
      return {};
    }
  }

  static Future<void> _writeMap(
    String prefix,
    Map<String, DateTime> map,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = json.encode(
      map.map((k, v) => MapEntry(k, v.toIso8601String())),
    );
    await prefs.setString('${_key}_$prefix', encoded);
  }

  static String _key2(String documentId, String kind) => '$documentId::$kind';

  // ─── Acknowledge ───────────────────────────────────────────────────────
  static Future<void> acknowledge(String documentId, String kind) async {
    final map = await _readMap('ack');
    map[_key2(documentId, kind)] = DateTime.now();
    await _writeMap('ack', map);
  }

  static Future<void> unacknowledge(String documentId, String kind) async {
    final map = await _readMap('ack');
    map.remove(_key2(documentId, kind));
    await _writeMap('ack', map);
  }

  // ─── Snooze ────────────────────────────────────────────────────────────
  static Future<void> snooze(
    String documentId,
    String kind,
    Duration duration,
  ) async {
    final map = await _readMap('snooze');
    map[_key2(documentId, kind)] = DateTime.now().add(duration);
    await _writeMap('snooze', map);
  }

  static Future<void> unsnooze(String documentId, String kind) async {
    final map = await _readMap('snooze');
    map.remove(_key2(documentId, kind));
    await _writeMap('snooze', map);
  }

  // ─── Read helpers ──────────────────────────────────────────────────────
  static Future<AlertActionState> stateFor(
    String documentId,
    String kind,
  ) async {
    final ackMap = await _readMap('ack');
    final snoozeMap = await _readMap('snooze');
    final acknowledgedAt = ackMap[_key2(documentId, kind)];
    final snoozeUntil = snoozeMap[_key2(documentId, kind)];
    final now = DateTime.now();
    return AlertActionState(
      acknowledgedAt: acknowledgedAt,
      snoozeUntil:
          snoozeUntil != null && snoozeUntil.isAfter(now) ? snoozeUntil : null,
    );
  }

  /// Returns the action state for many alerts in one batch.
  static Future<Map<String, AlertActionState>> stateForMany(
    List<({String documentId, String kind})> alerts,
  ) async {
    final ackMap = await _readMap('ack');
    final snoozeMap = await _readMap('snooze');
    final now = DateTime.now();
    final result = <String, AlertActionState>{};
    for (final a in alerts) {
      final k = _key2(a.documentId, a.kind);
      final snoozeUntil = snoozeMap[k];
      result[k] = AlertActionState(
        acknowledgedAt: ackMap[k],
        snoozeUntil:
            snoozeUntil != null && snoozeUntil.isAfter(now) ? snoozeUntil : null,
      );
    }
    return result;
  }

  /// Count alerts not hidden by acknowledge/snooze on this device.
  static Future<int> visibleCount(List<dynamic> alerts) async {
    if (alerts.isEmpty) return 0;
    final keys = alerts
        .map((a) => Map<String, dynamic>.from(a as Map))
        .map((m) => (
              documentId: m['document_id']?.toString() ?? '',
              kind: m['kind']?.toString() ?? '',
            ))
        .toList();
    final actions = await stateForMany(keys);
    var visible = 0;
    for (final a in alerts) {
      final m = a as Map;
      final k = '${m['document_id']}::${m['kind']}';
      if (!(actions[k]?.isHidden ?? false)) visible++;
    }
    return visible;
  }
}

class AlertActionState {
  const AlertActionState({this.acknowledgedAt, this.snoozeUntil});

  final DateTime? acknowledgedAt;
  final DateTime? snoozeUntil;

  bool get isHidden => acknowledgedAt != null || snoozeUntil != null;
  bool get isAcknowledged => acknowledgedAt != null;
  bool get isSnoozed => snoozeUntil != null;
}
