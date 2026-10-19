import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smartflow/services/api_client.dart';
import 'package:smartflow/utils/live_refresh.dart';

void main() {
  for (final sample in [
    (401, 'Missing or invalid token', true, true),
    (403, 'This account has been deactivated.', true, true),
    (403, 'Only admin can view this report', true, false),
    (401, 'Invalid username or password', false, false),
    (500, 'Temporary server error', true, false),
  ]) {
    test('session invalidation ${sample.$1} ${sample.$2}', () async {
      final invalid = <String>[];
      final client = ApiClient(
        token: 'current-token',
        onSessionInvalid: (token, message) => invalid.add(token),
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({'success': false, 'message': sample.$2}),
            sample.$1,
          ),
        ),
      );
      await expectLater(
        client.get('check.php', auth: sample.$3),
        throwsA(isA<ApiException>()),
      );
      expect(invalid, sample.$4 ? ['current-token'] : isEmpty);
    });
  }
  test('CSV export invalidates an expired session', () async {
    var invalid = false;
    final client = ApiClient(
      token: 'expired',
      onSessionInvalid: (_, _) => invalid = true,
      client: MockClient(
        (_) async =>
            http.Response('{"message":"Missing or invalid token"}', 401),
      ),
    );
    await expectLater(
      client.getText('export.php'),
      throwsA(isA<ApiException>()),
    );
    expect(invalid, isTrue);
  });
  testWidgets('refresh after 15s, pause in background, resume and dispose', (
    tester,
  ) async {
    var refreshes = 0;
    await tester.pumpWidget(
      MaterialApp(home: _LiveProbe(() async => refreshes++)),
    );
    await tester.pump(const Duration(seconds: 14));
    expect(refreshes, 0);
    await tester.pump(const Duration(seconds: 1));
    expect(refreshes, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 30));
    expect(refreshes, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(refreshes, 2);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 30));
    expect(refreshes, 2);
  });
}

class _LiveProbe extends StatefulWidget {
  const _LiveProbe(this.refresh);
  final Future<void> Function() refresh;
  @override
  State<_LiveProbe> createState() => _LiveProbeState();
}

class _LiveProbeState extends State<_LiveProbe> with LiveRefresh<_LiveProbe> {
  @override
  Future<void> refreshLiveData() => widget.refresh();
  @override
  Widget build(BuildContext context) => const Text('Visible content');
}
