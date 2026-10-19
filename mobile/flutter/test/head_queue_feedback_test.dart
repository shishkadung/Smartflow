import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartflow/models/user.dart';
import 'package:smartflow/providers/auth_provider.dart';
import 'package:smartflow/screens/head/head_shell.dart';
import 'package:smartflow/screens/head/head_widgets.dart';
import 'package:smartflow/screens/staff/clerk_widgets.dart' show SfLoadingCard;
import 'package:smartflow/services/api_client.dart';
import 'package:smartflow/services/smartflow_api.dart';
import 'package:smartflow/theme/smartflow_theme.dart';

Map<String, dynamic> _folder(String title, {bool overdue = false}) => {
  'document_id': overdue ? 'DOC-2026-000002' : 'DOC-2026-000001',
  'title': title,
  'type': 'Others: Review papers',
  'meta': 'Budget Office',
  'status_label': overdue ? 'overdue' : 'in_office',
  'status_pill': overdue ? 'Overdue' : 'On time',
  'hours_pending': overdue ? 80 : 2,
};

http.Response _response(List<Map<String, dynamic>> rows) => http.Response(
  jsonEncode({'queue': rows}),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

http.Response _failure() => http.Response(
  jsonEncode({'message': 'Sample queue read unavailable'}),
  503,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

class _QueueFixture {
  bool fail = false;
  bool controlled = false;
  int reads = 0;
  List<Map<String, dynamic>> rows = [_folder('Original queue folder')];
  final pending = <Completer<http.Response>>[];
  late final client = MockClient((request) async {
    expect(request.method, 'GET');
    expect(request.url.pathSegments.last, 'head-dashboard.php');
    expect(request.url.queryParameters['office_id'], '2');
    reads++;
    if (controlled) {
      final response = Completer<http.Response>();
      pending.add(response);
      return response.future;
    }
    return fail ? _failure() : _response(rows);
  });
  late final api = SmartflowApi(ApiClient(client: client));
}

/// Controls completion ordering at the API boundary for UI ownership races.
class _ControlledQueueApi extends SmartflowApi {
  _ControlledQueueApi(_QueueFixture fixture)
    : super(ApiClient(client: fixture.client));

  bool controlled = false;
  int reads = 0;
  final pending = <Completer<Map<String, dynamic>>>[];

  @override
  Future<Map<String, dynamic>> headDashboard(int officeId) {
    expect(officeId, 2);
    reads++;
    if (!controlled) return super.headDashboard(officeId);
    final response = Completer<Map<String, dynamic>>();
    pending.add(response);
    return response.future;
  }
}

class _QueueAuth extends AuthProvider {
  _QueueAuth(this.api);

  @override
  final SmartflowApi api;
  Object _session = Object();

  @override
  Object get sessionIdentity => _session;

  @override
  bool get isAuthenticated => true;

  @override
  AppUser get user => const AppUser(
    id: 21,
    name: 'Sample department head',
    username: 'sample.head',
    role: 'head',
    officeId: 2,
    officeName: 'Budget Office',
    officeCode: 'BUD',
  );

  void replaceLogin() {
    _session = Object();
    notifyListeners();
  }
}

Future<_QueueAuth> _mount(
  WidgetTester tester,
  _QueueFixture fixture, {
  SfHeadQueueFilter? filter,
  SmartflowApi? api,
}) async {
  tester.view.physicalSize = const Size(390, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final auth = _QueueAuth(api ?? fixture.api);
  addTearDown(auth.dispose);
  addTearDown(fixture.client.close);
  final router = GoRouter(
    initialLocation: '/head/queue',
    routes: [
      GoRoute(
        path: '/head/queue',
        builder: (_, _) =>
            Scaffold(body: HeadQueueScreen(initialFilter: filter)),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ChangeNotifierProvider<AuthProvider>.value(
      value: auth,
      child: MaterialApp.router(
        theme: buildSmartflowTheme().copyWith(platform: TargetPlatform.windows),
        routerConfig: router,
      ),
    ),
  );
  if (fixture.controlled) {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(fixture.pending, hasLength(1));
  } else {
    await tester.pumpAndSettle();
  }
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
  return auth;
}

Future<void> _refresh(WidgetTester tester) =>
    tester.widget<RefreshIndicator>(find.byType(RefreshIndicator)).onRefresh();

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Queue loading and failure do not imply a verified zero', (
    tester,
  ) async {
    final fixture = _QueueFixture()..controlled = true;
    await _mount(tester, fixture);
    expect(find.byType(SfLoadingCard), findsOneWidget);
    expect(find.text('0 of 0'), findsNothing);
    expect(find.text('No documents in the office queue'), findsNothing);

    fixture.pending.single.complete(_failure());
    await tester.pumpAndSettle();
    expect(find.textContaining('Queue unavailable.'), findsOneWidget);
    expect(find.text('Retry queue'), findsOneWidget);
    expect(find.text('0 of 0'), findsNothing);
    expect(find.text('No documents in the office queue'), findsNothing);

    fixture
      ..controlled = false
      ..rows = [];
    await tester.tap(find.text('Retry queue'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Queue unavailable.'), findsNothing);
    expect(find.text('0 of 0'), findsOneWidget);
    expect(find.text('No documents in the office queue'), findsOneWidget);
    expect(fixture.reads, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Queue refresh failure retains explicitly stale rows until retry',
    (tester) async {
      final fixture = _QueueFixture();
      await _mount(tester, fixture);
      expect(find.text('Original queue folder'), findsOneWidget);
      fixture.fail = true;
      await _refresh(tester);
      await tester.pumpAndSettle();
      expect(find.text('Original queue folder'), findsOneWidget);
      expect(find.text('1 of 1 · stale'), findsOneWidget);
      expect(
        find.textContaining('Previously loaded queue and counts may be stale.'),
        findsOneWidget,
      );
      expect(find.textContaining('Last successful update'), findsOneWidget);

      fixture
        ..fail = false
        ..rows = [_folder('Verified replacement folder')];
      await tester.tap(find.text('Retry queue'));
      await tester.pumpAndSettle();
      expect(find.text('Verified replacement folder'), findsOneWidget);
      expect(find.text('Original queue folder'), findsNothing);
      expect(find.text('1 of 1'), findsOneWidget);
      expect(find.textContaining('may be stale'), findsNothing);
      expect(find.textContaining('Last successful update'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('A retained empty Queue is qualified after refresh failure', (
    tester,
  ) async {
    final fixture = _QueueFixture()..rows = [];
    await _mount(tester, fixture);
    expect(find.text('No documents in the office queue'), findsOneWidget);
    fixture.fail = true;
    await _refresh(tester);
    await tester.pumpAndSettle();
    expect(find.text('No documents in the office queue'), findsNothing);
    expect(
      find.textContaining('The last successful read found no documents.'),
      findsOneWidget,
    );
    expect(find.text('0 of 0 · stale'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Clear search restores matches without changing the Queue filter',
    (tester) async {
      final fixture = _QueueFixture()
        ..rows = [
          _folder('Current office folder'),
          _folder('Late office folder', overdue: true),
        ];
      await _mount(tester, fixture, filter: SfHeadQueueFilter.overdue);
      await tester.enterText(find.byType(TextField), 'unmatched search');
      await tester.pumpAndSettle();
      expect(find.text('No matching documents'), findsOneWidget);
      expect(find.text('Show all'), findsNothing);
      await tester.ensureVisible(find.text('Clear search'));
      await tester.tap(find.text('Clear search'));
      await tester.pumpAndSettle();
      expect(find.text('Late office folder'), findsOneWidget);
      expect(find.text('Current office folder'), findsNothing);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '',
      );
      expect(
        tester
            .widget<SfHeadQueueFilterChips>(find.byType(SfHeadQueueFilterChips))
            .selected,
        SfHeadQueueFilter.overdue,
      );
      expect(fixture.reads, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Show all resets a nonmatching Queue filter', (tester) async {
    final fixture = _QueueFixture();
    await _mount(tester, fixture, filter: SfHeadQueueFilter.forwarded);
    expect(find.text('No documents in this filter'), findsOneWidget);
    await tester.ensureVisible(find.text('Show all'));
    await tester.tap(find.text('Show all'));
    await tester.pumpAndSettle();
    expect(find.text('Original queue folder'), findsOneWidget);
    expect(
      tester
          .widget<SfHeadQueueFilterChips>(find.byType(SfHeadQueueFilterChips))
          .selected,
      SfHeadQueueFilter.all,
    );
    expect(fixture.reads, 1);
    expect(tester.takeException(), isNull);
  });

  for (final olderFails in [false, true]) {
    testWidgets(
      'Only the latest Queue read publishes (olderFails=$olderFails)',
      (tester) async {
        final fixture = _QueueFixture();
        final api = _ControlledQueueApi(fixture);
        await _mount(tester, fixture, api: api);
        api.controlled = true;
        final older = _refresh(tester);
        expect(api.pending, hasLength(1));
        final newer = _refresh(tester);
        expect(api.pending, hasLength(2));
        expect(api.reads, 3);
        expect(fixture.reads, 1);

        if (olderFails) {
          api.pending[1].complete({
            'queue': [_folder('Newest queue folder')],
          });
        } else {
          api.pending[1].completeError(
            ApiException('Sample queue read unavailable', 503),
          );
        }
        await newer;
        await tester.pump();
        if (olderFails) {
          api.pending[0].completeError(
            ApiException('Sample queue read unavailable', 503),
          );
        } else {
          api.pending[0].complete({
            'queue': [_folder('Obsolete queue folder')],
          });
        }
        await older;
        await tester.pumpAndSettle();

        if (olderFails) {
          expect(find.text('Newest queue folder'), findsOneWidget);
          expect(
            find.textContaining('Sample queue read unavailable'),
            findsNothing,
          );
          expect(find.text('1 of 1'), findsOneWidget);
        } else {
          expect(find.text('Original queue folder'), findsOneWidget);
          expect(find.text('Obsolete queue folder'), findsNothing);
          expect(
            find.textContaining('Sample queue read unavailable'),
            findsOneWidget,
          );
          expect(find.text('1 of 1 · stale'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('Queue reads remain bound to their originating login', (
    tester,
  ) async {
    final fixture = _QueueFixture();
    final api = _ControlledQueueApi(fixture);
    final auth = await _mount(tester, fixture, api: api);
    api.controlled = true;
    final refresh = _refresh(tester);
    expect(api.pending, hasLength(1));
    auth.replaceLogin();
    api.pending.single.complete({
      'queue': [_folder('Late old-login folder')],
    });
    await refresh;
    await tester.pump();
    expect(find.text('Late old-login folder'), findsNothing);
    await _refresh(tester);
    expect(api.reads, 2);
    expect(tester.takeException(), isNull);
  });
}
