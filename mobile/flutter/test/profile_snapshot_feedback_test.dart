import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartflow/models/user.dart';
import 'package:smartflow/providers/auth_provider.dart';
import 'package:smartflow/screens/staff/staff_shell.dart';
import 'package:smartflow/services/api_client.dart';
import 'package:smartflow/services/smartflow_api.dart';
import 'package:smartflow/theme/smartflow_theme.dart';

Map<String, dynamic> _stats(int count) => {
  'stats': {
    'in_flow': count,
    'out_flow': 5,
    'active_tags': 9,
    'in_office': count,
    'overdue': 5,
    'avg_hours': 9,
  },
};

class _SnapshotApi extends SmartflowApi {
  _SnapshotApi()
    : super(
        ApiClient(
          client: MockClient((_) async {
            throw StateError('Snapshot tests must never use HTTP.');
          }),
        ),
      );

  bool fail = false;
  int reads = 0;
  final pending = <Completer<Map<String, dynamic>>>[];

  Future<Map<String, dynamic>> _read() async {
    reads++;
    if (pending.isNotEmpty) return pending.removeAt(0).future;
    if (fail) throw ApiException('Sample connection unavailable', 503);
    return _stats(7);
  }

  @override
  Future<Map<String, dynamic>> dashboardStats(int officeId) => _read();
  @override
  Future<Map<String, dynamic>> headDashboard(int officeId) => _read();
}

class _SnapshotAuth extends AuthProvider {
  _SnapshotAuth(this.api, this.role);
  @override
  final _SnapshotApi api;
  final String role;
  @override
  bool get isAuthenticated => true;
  @override
  String get token => 'synthetic-snapshot-session';
  @override
  AppUser get user => AppUser(
    id: 101,
    name: 'Sample reviewer',
    username: 'sample.review',
    role: role,
    officeId: 1,
    officeName: 'Engineering Office',
    officeCode: 'ENG',
  );
}

Future<void> _mount(WidgetTester tester, _SnapshotApi api, String role) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(390, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final auth = _SnapshotAuth(api, role);
  final router = GoRouter(
    initialLocation: '/$role/profile',
    routes: [
      GoRoute(
        path: '/$role/profile',
        builder: (_, _) => const Scaffold(body: ProfileScreen()),
      ),
    ],
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    router.dispose();
    auth.dispose();
  });
  await tester.pumpWidget(
    ChangeNotifierProvider<AuthProvider>.value(
      value: auth,
      child: MaterialApp.router(
        routerConfig: router,
        theme: buildSmartflowTheme(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _refresh(WidgetTester tester) =>
    tester.widget<RefreshIndicator>(find.byType(RefreshIndicator)).onRefresh();

void main() {
  for (final role in ['staff', 'head']) {
    testWidgets('$role Profile explains initial snapshot failure and retries', (
      tester,
    ) async {
      final api = _SnapshotApi()..fail = true;
      await _mount(tester, api, role);
      expect(
        find.textContaining('Office snapshot unavailable.'),
        findsOneWidget,
      );
      expect(find.text('Sample reviewer'), findsOneWidget);
      expect(find.text('Account & security'), findsOneWidget);
      expect(find.text('0'), findsNothing);
      api.fail = false;
      await tester.tap(find.text('Retry snapshot'));
      await tester.pumpAndSettle();
      expect(api.reads, 2);
      expect(find.text('7'), findsOneWidget);
      expect(find.textContaining('unavailable'), findsNothing);
      expect(find.textContaining('Updated '), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      '$role Profile retains metrics with progress then stale feedback',
      (tester) async {
        final api = _SnapshotApi();
        await _mount(tester, api, role);
        final reply = Completer<Map<String, dynamic>>();
        api.pending.add(reply);
        final refresh = _refresh(tester);
        await tester.pump();
        expect(find.text('7'), findsOneWidget);
        expect(find.text('Updating snapshot…'), findsOneWidget);
        expect(find.text('Account & security'), findsOneWidget);
        reply.completeError(ApiException('Sample refresh unavailable', 503));
        await refresh;
        await tester.pumpAndSettle();
        expect(find.text('7'), findsOneWidget);
        expect(
          find.textContaining('Previously loaded snapshot may be stale.'),
          findsOneWidget,
        );
        expect(find.textContaining('Last successful update '), findsOneWidget);
        expect(find.text('Updating snapshot…'), findsNothing);
        await tester.tap(find.text('Retry snapshot'));
        await tester.pumpAndSettle();
        expect(find.textContaining('stale'), findsNothing);
        expect(find.textContaining('Updated '), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '$role Profile keeps newer snapshot when an older refresh fails',
      (tester) async {
        final api = _SnapshotApi();
        await _mount(tester, api, role);
        final olderReply = Completer<Map<String, dynamic>>();
        final newerReply = Completer<Map<String, dynamic>>();
        api.pending.addAll([olderReply, newerReply]);
        final older = _refresh(tester);
        await tester.pump();
        final newer = _refresh(tester);
        await tester.pump();
        newerReply.complete(_stats(21));
        await newer;
        await tester.pump();
        olderReply.completeError(ApiException('Older snapshot failed', 503));
        await older;
        await tester.pumpAndSettle();
        expect(find.text('21'), findsOneWidget);
        expect(find.textContaining('Older snapshot failed'), findsNothing);
        expect(find.textContaining('stale'), findsNothing);
        expect(find.text('Updating snapshot…'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '$role Profile ignores a snapshot result after leaving the page',
      (tester) async {
        final api = _SnapshotApi();
        await _mount(tester, api, role);
        final reply = Completer<Map<String, dynamic>>();
        api.pending.add(reply);
        final refresh = _refresh(tester);
        await tester.pump();
        await tester.pumpWidget(const SizedBox.shrink());
        reply.completeError(ApiException('Late snapshot failed', 503));
        await refresh;
        await tester.pump();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
