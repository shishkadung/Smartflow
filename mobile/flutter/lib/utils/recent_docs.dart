import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// A tracking ID this device already opened, with the folder name when known.
class RecentDocRef {
  const RecentDocRef({required this.id, this.title = ''});

  final String id;
  final String title;

  /// `000003 · DV – Road Repair`, or the full ID when the name is unknown.
  String get chipLabel {
    final name = title.trim();
    if (name.isEmpty) return id;
    final tail = id.replaceFirst(RegExp(r'^DOC-\d{4}-'), '');
    return '$tail · $name';
  }
}

/// Persistent list of recently opened tracking IDs (per device).
class RecentDocsStore {
  RecentDocsStore._();

  static const _key = 'sf_recent_doc_ids';
  static const _titleKey = 'sf_recent_doc_titles';
  static const _maxEntries = 5;

  static Future<List<RecentDocRef>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_key) ?? <String>[];
    final titles = _readTitles(prefs);
    return [
      for (final id in ids) RecentDocRef(id: id, title: titles[id] ?? ''),
    ];
  }

  /// Adds [id] at the front. [title] is kept when the folder name is known.
  static Future<List<RecentDocRef>> add(String id, {String? title}) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList(_key) ?? <String>[];
    current.remove(id);
    current.insert(0, id);
    if (current.length > _maxEntries) {
      current.removeRange(_maxEntries, current.length);
    }
    final titles = _readTitles(prefs);
    final name = title?.trim() ?? '';
    if (name.isNotEmpty) titles[id] = name;
    titles.removeWhere((key, _) => !current.contains(key));
    await prefs.setStringList(_key, current);
    await prefs.setString(_titleKey, jsonEncode(titles));
    return [
      for (final saved in current)
        RecentDocRef(id: saved, title: titles[saved] ?? ''),
    ];
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    await prefs.remove(_titleKey);
  }

  static Map<String, String> _readTitles(SharedPreferences prefs) {
    final raw = prefs.getString(_titleKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      return decoded.map((key, value) => MapEntry('$key', '$value'));
    } catch (_) {
      return {};
    }
  }
}
