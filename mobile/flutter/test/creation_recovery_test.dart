import 'dart:convert';
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartflow/services/api_client.dart';
import 'package:smartflow/services/creation_recovery.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('lost creation response reads result with one POST', () async {
    final calls = <String>[];
    final recovery = CreationRecovery(
      ApiClient(
        client: MockClient((request) async {
          calls.add(request.method);
          if (request.method == 'POST') {
            throw http.ClientException('Response lost');
          }
          return http.Response(
            jsonEncode({
              'success': true,
              'state': 'recorded',
              'result': {
                'document': {'id': 'DOC-TEST'},
              },
            }),
            200,
          );
        }),
      ),
      '1_2',
    );
    expect(
      (await recovery.submit('document', {
        'title': 'Folder',
      }))['document']['id'],
      'DOC-TEST',
    );
    expect(calls, ['POST', 'GET']);
    expect(await recovery.pending('document'), isNull);
  });
  test(
    'pending creation survives restart, isolates account, and retries exact operation only',
    () async {
      final ids = <String>[];
      var succeeds = false;
      final client = ApiClient(
        token: 'private-session',
        client: MockClient((request) async {
          if (request.method == 'GET') {
            return http.Response('{"success":true,"state":"unknown"}', 200);
          }
          ids.add('${jsonDecode(request.body)['operation_id']}');
          if (!succeeds) throw http.ClientException('Offline');
          return http.Response('{"success":true,"request":{"id":42}}', 201);
        }),
      );
      final recovery = CreationRecovery(client, '1_2');
      await expectLater(
        recovery.submit('request', {'purpose': 'Original'}),
        throwsA(isA<ApiException>()),
      );
      expect(
        (await SharedPreferences.getInstance()).getString(
          'sf_creation_v1_1_2_request',
        ),
        isNot(contains('private-session')),
      );
      final restarted = CreationRecovery(client, '1_2');
      await expectLater(
        restarted.submit('request', {'purpose': 'Changed'}),
        throwsA(isA<ApiException>()),
      );
      expect(ids.length, 1);
      expect(await CreationRecovery(client, '2_2').pending('request'), isNull);
      succeeds = true;
      expect(
        (await restarted.submit('request', {
          'purpose': 'Original',
        }))['request']['id'],
        42,
      );
      expect(ids[0], ids[1]);
      expect(await restarted.pending('request'), isNull);
    },
  );
  test('definite validation rejection clears pending creation', () async {
    final recovery = CreationRecovery(
      ApiClient(
        client: MockClient(
          (request) async =>
              http.Response('{"success":false,"message":"Invalid form"}', 400),
        ),
      ),
      '1_2',
    );
    await expectLater(
      recovery.submit('document', {'title': 'Bad'}),
      throwsA(isA<ApiException>()),
    );
    expect(await recovery.pending('document'), isNull);
  });
  test('delayed recovery cannot clear a newer saved operation', () async {
    final result = Completer<http.Response>();
    final started = Completer<void>();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'sf_creation_v1_1_2_document',
      jsonEncode({
        'id': 'a' * 32,
        'body': {'title': 'Old'},
      }),
    );
    final recovery = CreationRecovery(
      ApiClient(
        client: MockClient((request) {
          started.complete();
          return result.future;
        }),
      ),
      '1_2',
    );
    final check = recovery.check('document');
    await started.future;
    await prefs.setString(
      'sf_creation_v1_1_2_document',
      jsonEncode({
        'id': 'b' * 32,
        'body': {'title': 'New'},
      }),
    );
    result.complete(
      http.Response(
        '{"success":true,"state":"recorded","result":{"document":{"id":"OLD"}}}',
        200,
      ),
    );
    await expectLater(check, throwsA(isA<ApiException>()));
    expect((await recovery.pending('document'))!['id'], 'b' * 32);
  });
}
