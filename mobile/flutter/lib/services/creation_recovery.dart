import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';

class CreationRecovery {
  CreationRecovery(this.client, this.scope);
  final ApiClient client;
  final String scope;
  static final _writing = <String>{};
  String _key(String kind) => 'sf_creation_v1_${scope}_$kind';

  Future<Map<String, dynamic>?> pending(String kind) async {
    final raw = (await SharedPreferences.getInstance()).getString(_key(kind));
    if (raw == null) return null;
    final value = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    if (!RegExp(r'^[a-f0-9]{32}$').hasMatch('${value['id']}') ||
        value['body'] is! Map) {
      throw ApiException(
        'Saved submission is unreadable. Keep this account signed in and ask for recovery assistance.',
      );
    }
    return value;
  }

  Future<void> _clear(String kind, String id) async {
    if ((await pending(kind))?['id'] != id) {
      throw ApiException(
        'Saved submission changed. Check its current result before continuing.',
      );
    }
    if (!await (await SharedPreferences.getInstance()).remove(_key(kind))) {
      throw ApiException(
        'Result verified, but local recovery could not be cleared. Check again before another submission.',
      );
    }
  }

  Future<Map<String, dynamic>?> check(String kind) async {
    final key = _key(kind);
    if (!_writing.add(key)) {
      throw ApiException(
        'A submission is still being checked. Wait for its result.',
      );
    }
    try {
      return await _check(kind);
    } finally {
      _writing.remove(key);
    }
  }

  Future<Map<String, dynamic>?> _check(String kind) async {
    final saved = await pending(kind);
    if (saved == null) return null;
    final result = await client.get(
      'creation-requests.php',
      query: {'operation_id': '${saved['id']}', 'kind': kind},
    );
    if (result['state'] == 'recorded') {
      await _clear(kind, saved['id'] as String);
    }
    return result;
  }

  dynamic _canonical(dynamic value) {
    if (value is List) return value.map(_canonical).toList();
    if (value is Map) {
      final keys = value.keys.map((key) => key.toString()).toList()..sort();
      return {for (final key in keys) key: _canonical(value[key])};
    }
    return value;
  }

  Future<Map<String, dynamic>> submit(
    String kind,
    Map<String, dynamic> body,
  ) async {
    final key = _key(kind);
    if (!_writing.add(key)) {
      throw ApiException('A submission is still running. Wait for its result.');
    }
    try {
      var saved = await pending(kind);
      final clean = _canonical(body) as Map<String, dynamic>;
      if (saved != null &&
          jsonEncode(_canonical(saved['body'])) != jsonEncode(clean)) {
        throw ApiException(
          'Check the previous submission before creating a different record.',
        );
      }
      if (saved == null) {
        final random = Random.secure();
        final id = List.generate(
          16,
          (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
        ).join();
        saved = {'id': id, 'body': clean};
        if (!await (await SharedPreferences.getInstance()).setString(
          key,
          jsonEncode(saved),
        )) {
          throw ApiException(
            'Could not save recovery on this phone. No submission was sent.',
          );
        }
      }
      try {
        final result = await client.post(
          kind == 'document'
              ? 'documents-create.php'
              : 'document-requests-create.php',
          body: {
            ...Map<String, dynamic>.from(saved['body'] as Map),
            'operation_id': saved['id'],
          },
        );
        await _clear(kind, saved['id'] as String);
        return result;
      } catch (error) {
        if (error is ApiException &&
            error.statusCode >= 400 &&
            error.statusCode < 500) {
          await _clear(kind, saved['id'] as String);
          rethrow;
        }
        try {
          final outcome = await _check(kind);
          if (outcome?['state'] == 'recorded') {
            return Map<String, dynamic>.from(outcome!['result'] as Map);
          }
        } catch (_) {
          /* Preserve the pending operation on an uncertain response. */
        }
        throw ApiException(
          'Submission outcome is pending. Use Check previous submission before starting another record.',
        );
      }
    } finally {
      _writing.remove(key);
    }
  }
}
