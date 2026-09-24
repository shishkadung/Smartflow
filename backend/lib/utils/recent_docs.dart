import 'package:shared_preferences/shared_preferences.dart';

/// Persistent list of recently viewed/scanned tracking IDs (per device).
/// Used to power "Recent IDs" chips on Scan and other clerk pages.
class RecentDocsStore {
  RecentDocsStore._();

  static const _key = 'sf_recent_doc_ids';
  static const _maxEntries = 5;

  static Future<List<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_key) ?? <String>[];
  }

  /// Adds [id] at the front of the list. Returns the new list.
  static Future<List<String>> add(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList(_key) ?? <String>[];
    current.remove(id);
    current.insert(0, id);
    if (current.length > _maxEntries) {
      current.removeRange(_maxEntries, current.length);
    }
    await prefs.setStringList(_key, current);
    return current;
  }

  static Future<void> remove(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList(_key) ?? <String>[];
    current.remove(id);
    await prefs.setStringList(_key, current);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
