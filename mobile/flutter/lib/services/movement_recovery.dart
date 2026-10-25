import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';

class MovementRecovery {
  MovementRecovery(this.client, this.scope);
  final ApiClient client;
  final String scope;
  static final changes = ValueNotifier<int>(0);
  static final _writing = <String>{};
  String get _key => 'sf_pending_movement_v1_$scope';
  Future<Map<String, dynamic>?> pending() async {
    final raw = (await SharedPreferences.getInstance()).getString(_key);
    return raw == null
        ? null
        : Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  Future<void> _clear(String requestId) async {
    if ((await pending())?['request_id'] != requestId) {
      throw ApiException(
        'The saved action changed. Check its current result before continuing.',
      );
    }
    if (!await (await SharedPreferences.getInstance()).remove(_key)) {
      throw ApiException(
        'The result is verified, but local recovery could not be cleared. Check again before another action.',
      );
    }
    changes.value++;
  }

  Future<Map<String, dynamic>?> _check() async {
    final body = await pending();
    if (body == null) return null;
    final result = await client.get(
      'movement-requests.php',
      query: {'request_id': body['request_id'].toString()},
    );
    if (['recorded', 'cancelled'].contains(result['state'])) {
      await _clear(body['request_id'].toString());
    }
    return result;
  }

  Future<Map<String, dynamic>?> check() async {
    if (!_writing.add(scope)) {
      throw ApiException(
        'An action is still being checked. Wait for its result.',
      );
    }
    try {
      return await _check();
    } finally {
      _writing.remove(scope);
    }
  }

  Future<Map<String, dynamic>?> cancel() async {
    if (!_writing.add(scope)) {
      throw ApiException(
        'An action is still being checked. Wait for its result.',
      );
    }
    try {
      final body = await pending();
      if (body == null) return null;
      final result = await client.post(
        'movement-requests.php',
        body: {
          'action': 'cancel',
          'request_id': body['request_id'],
          'document_id': body['document_id'],
        },
      );
      if (['recorded', 'cancelled'].contains(result['state'])) {
        await _clear(body['request_id'].toString());
      }
      return result;
    } finally {
      _writing.remove(scope);
    }
  }

  Future<Map<String, dynamic>> record(
    Map<String, dynamic> body, {
    bool destinationCorrection = false,
  }) async {
    if (!_writing.add(scope)) {
      throw ApiException(
        'A movement is still being checked. Wait for its result.',
      );
    }
    try {
      if (await pending() != null) {
        throw ApiException(
          'Check the pending movement at the top of the screen before another IN/OUT.',
        );
      }
      final random = Random.secure();
      final id = List.generate(
        16,
        (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join();
      final request = {...body, 'request_id': id};
      if (!await (await SharedPreferences.getInstance()).setString(
        _key,
        jsonEncode(request),
      )) {
        throw ApiException(
          'Could not save movement recovery on this device. No movement was submitted.',
        );
      }
      changes.value++;
      try {
        final result = await client.post(
          destinationCorrection
              ? 'movements-correct-destination.php'
              : 'movements-create.php',
          body: request,
        );
        await _clear(id);
        return result;
      } catch (error) {
        if (error is ApiException &&
            error.statusCode >= 400 &&
            error.statusCode < 500) {
          await _clear(id);
          rethrow;
        }
        // Only read the outcome. Never automatically send the movement twice.
        try {
          final outcome = await _check();
          if (outcome?['state'] == 'recorded') {
            return Map<String, dynamic>.from(outcome!['result'] as Map);
          }
          if (outcome?['state'] == 'cancelled') {
            throw ApiException(
              'This movement was cancelled. Refresh the document.',
            );
          }
        } catch (_) {
          /* Keep the persisted request for the recovery controls. */
        }
        throw ApiException(
          'Connection interrupted. Your movement outcome is pending. Use Check result before another IN/OUT.',
        );
      }
    } finally {
      _writing.remove(scope);
    }
  }
}
