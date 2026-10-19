import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartflow/services/api_client.dart';
import 'package:smartflow/services/movement_recovery.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  const body = {
    'document_id': 'DOC-2026-000001',
    'office_id': 1,
    'status': 'OUT',
  };
  test(
    'Response loss after commit is recovered by GET with exactly one movement POST',
    () async {
      final calls = <String>[];
      final client = ApiClient(
        token: 'private-session',
        client: MockClient((request) async {
          calls.add('${request.method} ${request.url.pathSegments.last}');
          if (request.method == 'POST') {
            throw http.ClientException('Response lost');
          }
          return http.Response(
            jsonEncode({
              'success': true,
              'state': 'recorded',
              'result': {
                'success': true,
                'movement_id': 41,
                'message': 'Recorded',
              },
            }),
            200,
          );
        }),
      );
      final recovery = MovementRecovery(client, '1_1');
      expect((await recovery.record(body))['movement_id'], 41);
      expect(calls, ['POST movements-create.php', 'GET movement-requests.php']);
      expect(await recovery.pending(), isNull);
    },
  );
  test(
    'Unknown outcome persists across service restart and blocks a second action',
    () async {
      var posts = 0;
      final client = ApiClient(
        token: 'private-session',
        client: MockClient((request) async {
          if (request.method == 'POST') {
            posts++;
            throw http.ClientException('Disconnected');
          }
          return http.Response(
            '{"success":true,"state":"unknown","result":null}',
            200,
          );
        }),
      );
      final recovery = MovementRecovery(client, '2_1');
      await expectLater(recovery.record(body), throwsA(isA<ApiException>()));
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString('sf_pending_movement_v1_2_1'),
        isNot(contains('private-session')),
      );
      final restarted = MovementRecovery(client, '2_1');
      expect(
        (await restarted.pending())!['request_id'],
        matches(RegExp(r'^[a-f0-9]{32}$')),
      );
      await expectLater(restarted.record(body), throwsA(isA<ApiException>()));
      expect(posts, 1);
      expect(await MovementRecovery(client, '3_1').pending(), isNull);
      expect(await MovementRecovery(client, '2_2').pending(), isNull);
    },
  );
  test('Safe cancellation clears only a terminal server result', () async {
    SharedPreferences.setMockInitialValues({
      'sf_pending_movement_v1_4_1': jsonEncode({
        ...body,
        'request_id': 'a' * 32,
      }),
    });
    var recorded = false;
    final recovery = MovementRecovery(
      ApiClient(
        client: MockClient((request) async {
          final value = jsonDecode(request.body) as Map;
          expect(value['action'], 'cancel');
          expect(value['document_id'], body['document_id']);
          return http.Response(
            jsonEncode({
              'success': true,
              'state': recorded ? 'recorded' : 'cancelled',
              'result': recorded ? {'movement_id': 42} : null,
            }),
            200,
          );
        }),
      ),
      '4_1',
    );
    expect((await recovery.cancel())!['state'], 'cancelled');
    expect(await recovery.pending(), isNull);
    SharedPreferences.setMockInitialValues({
      'sf_pending_movement_v1_4_1': jsonEncode({
        ...body,
        'request_id': 'b' * 32,
      }),
    });
    recorded = true;
    expect((await recovery.cancel())!['result']['movement_id'], 42);
    expect(await recovery.pending(), isNull);
  });
  test('Two overlapping taps produce only one movement request', () async {
    final completer = Completer<http.Response>();
    var posts = 0;
    final recovery = MovementRecovery(
      ApiClient(
        client: MockClient((_) {
          posts++;
          return completer.future;
        }),
      ),
      '5_1',
    );
    final first = recovery.record(body);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await expectLater(recovery.record(body), throwsA(isA<ApiException>()));
    completer.complete(http.Response('{"success":true,"movement_id":43}', 200));
    await first;
    expect(posts, 1);
  });
  test(
    'Definitive validation rejection clears recovery and does not read or retry',
    () async {
      var requests = 0;
      final recovery = MovementRecovery(
        ApiClient(
          client: MockClient((_) async {
            requests++;
            return http.Response(
              '{"success":false,"message":"Stale document"}',
              409,
            );
          }),
        ),
        '6_1',
      );
      await expectLater(
        recovery.record(body),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 409)),
      );
      expect(requests, 1);
      expect(await recovery.pending(), isNull);
    },
  );

  test(
    'Correction response loss uses the correction endpoint and one persisted movement operation',
    () async {
      final calls = <String>[];
      String? requestId;
      final recovery = MovementRecovery(
        ApiClient(
          client: MockClient((request) async {
            calls.add('${request.method} ${request.url.pathSegments.last}');
            if (request.method == 'POST') {
              requestId = (jsonDecode(request.body) as Map)['request_id']
                  .toString();
              throw http.ClientException('Lost response');
            }
            expect(request.url.queryParameters['request_id'], requestId);
            return http.Response(
              '{"success":true,"state":"recorded","result":{"correction_id":7}}',
              200,
            );
          }),
        ),
        '7_1',
      );
      expect(
        (await recovery.record({
          'document_id': 'DOC-2026-000001',
          'reason': 'Wrong office',
          'correction_confirmed': true,
        }, destinationCorrection: true))['correction_id'],
        7,
      );
      expect(calls, [
        'POST movements-correct-destination.php',
        'GET movement-requests.php',
      ]);
      expect(await recovery.pending(), isNull);
    },
  );

  test('Delayed outcome check preserves a newer pending action', () async {
    final key = 'sf_pending_movement_v1_8_1';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode({...body, 'request_id': 'a' * 32}));
    final response = Completer<http.Response>();
    final started = Completer<void>();
    final recovery = MovementRecovery(
      ApiClient(
        client: MockClient((_) {
          started.complete();
          return response.future;
        }),
      ),
      '8_1',
    );
    final check = recovery.check();
    await started.future;
    await prefs.setString(key, jsonEncode({...body, 'request_id': 'b' * 32}));
    response.complete(
      http.Response(
        '{"success":true,"state":"recorded","result":{"movement_id":1}}',
        200,
      ),
    );
    await expectLater(check, throwsA(isA<ApiException>()));
    expect((await recovery.pending())!['request_id'], 'b' * 32);
  });
}
