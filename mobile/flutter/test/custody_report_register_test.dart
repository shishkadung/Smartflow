import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:smartflow/models/user.dart';
import 'package:smartflow/providers/auth_provider.dart';
import 'package:smartflow/screens/admin/admin_shell.dart';
import 'package:smartflow/screens/admin/custody_report_register.dart';
import 'package:smartflow/services/api_client.dart';
import 'package:smartflow/services/smartflow_api.dart';
import 'package:smartflow/theme/smartflow_theme.dart';

const _id = 'DOC-2026-000077';
const _period = {'period': 'month', 'month': '2026-10'};
const _offices = [
  {'office_id': 4, 'office_code': 'ACC', 'office_name': 'Accounting Office'},
];

Map<String, dynamic> _register(String title, {int page = 1, int pages = 1}) => {
  'period_label': 'October 2026',
  'as_of': '2026-10-23 10:00:00',
  'timezone': 'Asia/Manila',
  'page': page,
  'total_pages': pages,
  'total': pages == 1 ? 1 : 26,
  'documents': [
    {
      'document_id': _id,
      'title': title,
      'type': 'Others: Complete supporting papers',
      'classification': 'unforwarded',
      'current_status': 'OUT',
      'current_office_name': 'Accounting Office',
      'destination_office_name': 'Municipal Treasury Office',
      'last_scanned_at': '2026-10-01 08:00:00',
      'recorded_by': 'Recorded sender',
      'last_sent_at': '2026-10-01 08:00:00',
      'sent_by': 'Recorded sender',
      'last_received_at': '2026-09-30 08:00:00',
      'received_by': 'Recorded receiver',
      'receipt_wait_hours': 90,
      'movement_count': 7,
      'carried_forward': true,
    },
  ],
};

class _Api extends SmartflowApi {
  _Api() : super(ApiClient());
  final queries = <Map<String, String>>[];
  final exportQueries = <Map<String, String>>[];
  Future<Map<String, dynamic>> Function(Map<String, String>)? read;
  bool failExport = false;
  @override
  Future<Map<String, dynamic>> reportsRegister(Map<String, String> query) {
    queries.add(Map.of(query));
    return read?.call(query) ?? Future.value(_register('Register folder'));
  }

  @override
  Future<Map<String, dynamic>> reportsSummary(
    int officeId,
    String month,
  ) async => {
    'office_id': 4,
    'period': 'month',
    'month': month,
    'export_allowed': true,
    'period_start': '2026-10-01 00:00:00',
    'generated_at': '2026-10-23 10:00:00',
    'as_of': '2026-10-23 10:00:00',
    'movement_watermark': 77,
    'correction_watermark': 3,
    'timezone': 'Asia/Manila',
    'scope': 'Municipal',
    'prepared_by': 'Accounting administrator',
    'totals': {'documents_in_period': 4},
    'outstanding_transfers': 1,
    'carried_forward_transfers': 1,
    'compliance': {
      'on_time': {'percent': 50, 'count': 2},
      'unforwarded': {'percent': 25, 'count': 1},
      'delayed': {'percent': 25, 'count': 1},
    },
    'office_totals': [
      {..._offices.first, 'docs_processed': 4},
    ],
  };

  @override
  Future<Map<String, dynamic>> auditExceptions({
    int hours = 24,
    Map<String, String> period = const {},
  }) async => {
    'exceptions': [
      {'document_id': _id, 'detail': 'Unreceived transfer evidence'},
    ],
  };

  @override
  Future<String> reportExport(Map<String, String> query, String format) async {
    exportQueries.add(Map.of(query));
    if (failExport) throw ApiException('Controlled export failure');
    return 'Period,October 2026';
  }
}

class _Auth extends AuthProvider {
  _Auth(this.fixture);
  final _Api fixture;
  Object identity = Object();
  @override
  Object get sessionIdentity => identity;
  @override
  SmartflowApi get api => fixture;
  @override
  AppUser get user => const AppUser(
    id: 101,
    name: 'Report reviewer',
    username: 'report.reviewer',
    role: 'admin',
    officeId: 4,
    officeName: 'Accounting Office',
    officeCode: 'ACC',
  );
}

Future<GoRouter> _mount(
  WidgetTester tester,
  _Api api, {
  bool full = false,
  double scale = 1,
  _Auth? auth,
  bool settle = true,
}) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  final owner = auth ?? _Auth(api);
  final router = GoRouter(
    initialLocation: '/admin/reports',
    routes: [
      GoRoute(
        path: '/admin/reports',
        builder: (_, _) => Scaffold(
          body: full
              ? const AdminReportsScreen()
              : ListView(
                  children: const [
                    CustodyReportRegister(
                      period: _period,
                      periodLabel: 'October 2026',
                      reloadKey: 1,
                      offices: _offices,
                    ),
                  ],
                ),
        ),
      ),
      GoRoute(
        path: '/admin/documents',
        builder: (_, state) => Scaffold(
          body: Column(
            children: [
              Text('Folder ${state.uri.queryParameters['id']}'),
              TextButton(
                onPressed: () => tester.element(find.text('Back')).pop(),
                child: const Text('Back'),
              ),
            ],
          ),
        ),
      ),
      GoRoute(
        path: '/admin/history',
        builder: (_, state) => Scaffold(
          body: Column(
            children: [
              Text('History ${(state.extra as Map)['documentId']}'),
              TextButton(
                onPressed: () => tester.element(find.text('Back')).pop(),
                child: const Text('Back'),
              ),
            ],
          ),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  addTearDown(owner.dispose);
  await tester.pumpWidget(
    ChangeNotifierProvider<AuthProvider>.value(
      value: owner,
      child: MaterialApp.router(
        routerConfig: router,
        theme: buildSmartflowTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }
  return router;
}

Future<void> _show(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    250,
    scrollable: find.byType(Scrollable).first,
    maxScrolls: 100,
  );
  await tester.pumpAndSettle();
}

void _change(WidgetTester tester, String key, String value) => tester
    .widget<DropdownButtonFormField<String>>(find.byKey(Key(key)))
    .onChanged!(value);

void main() {
  test(
    'register transport preserves period and paging query with header auth',
    () async {
      late http.Request sent;
      final api = SmartflowApi(
        ApiClient(
          token: 'synthetic-report-token',
          client: MockClient((request) async {
            sent = request;
            return http.Response(
              jsonEncode({'success': true, 'documents': []}),
              200,
              headers: {'content-type': 'application/json'},
            );
          }),
        ),
      );
      await api.reportsRegister({
        ..._period,
        'scope': 'outstanding',
        'classification': 'unforwarded',
        'office_id': '4',
        'q': 'road works',
        'page': '2',
        'page_size': '25',
      });
      expect(sent.url.pathSegments.last, 'reports-register.php');
      expect(sent.url.queryParameters['scope'], 'outstanding');
      expect(sent.url.queryParameters['page'], '2');
      expect(sent.url.queryParameters['q'], 'road works');
      expect(sent.url.queryParameters.containsKey('token'), isFalse);
      expect(sent.headers['Authorization'], 'Bearer synthetic-report-token');
    },
  );

  testWidgets(
    'changed view ignores late activity rows and keeps filters on server',
    (tester) async {
      final late = Completer<Map<String, dynamic>>();
      final api = _Api()
        ..read = (q) => q['scope'] == 'activity'
            ? late.future
            : Future.value(_register('Outstanding folder'));
      // An indeterminate pending read requires bounded pumps instead of settle.
      await _mount(tester, api, settle: false);
      _change(tester, 'report-register-classification-all', 'delayed');
      _change(tester, 'report-register-view', 'outstanding');
      await tester.pumpAndSettle();
      late.complete(_register('Late activity folder'));
      await tester.pumpAndSettle();
      expect(find.text('Late activity folder'), findsNothing);
      expect(find.text('Outstanding folder'), findsOneWidget);
      expect(
        find.byKey(const Key('report-register-classification-all')),
        findsNothing,
      );
      _change(tester, 'report-register-office', '4');
      await tester.pumpAndSettle();
      await _show(tester, find.byKey(const Key('report-register-search')));
      await tester.enterText(
        find.byKey(const Key('report-register-search')),
        'Road works',
      );
      await tester.tap(find.text('Search register'));
      await tester.pumpAndSettle();
      expect(api.queries.last, containsPair('scope', 'outstanding'));
      expect(api.queries.last, containsPair('classification', 'all'));
      expect(api.queries.last, containsPair('office_id', '4'));
      expect(api.queries.last, containsPair('q', 'Road works'));
      expect(api.queries.last, containsPair('page', '1'));
    },
  );

  testWidgets(
    'paging replaces rows and changed-query failure cannot show previous results',
    (tester) async {
      final api = _Api()
        ..read = (q) async {
          if (q['q'] != null) throw ApiException('Controlled search failure');
          final page = int.parse(q['page']!);
          return _register('Page $page folder', page: page, pages: 2);
        };
      await _mount(tester, api);
      await _show(tester, find.text('Next page'));
      await tester.tap(find.text('Next page'));
      await tester.pumpAndSettle();
      expect(api.queries.last['page'], '2');
      expect(find.text('Page 1 folder'), findsNothing);
      expect(find.text('Page 2 folder'), findsOneWidget);
      await _show(tester, find.byKey(const Key('report-register-search')));
      await tester.enterText(
        find.byKey(const Key('report-register-search')),
        'missing',
      );
      await tester.tap(find.text('Search register'));
      await tester.pumpAndSettle();
      expect(api.queries.last['page'], '1');
      expect(
        find.textContaining('Folder register unavailable.'),
        findsOneWidget,
      );
      expect(find.text('Page 2 folder'), findsNothing);
      expect(find.text('No matching folders'), findsNothing);
    },
  );

  testWidgets(
    'same-query refresh failure keeps evidence visibly stale and Retry recovers',
    (tester) async {
      final api = _Api();
      await _mount(tester, api);
      api.read = (_) async => throw ApiException('Controlled refresh failure');
      await _show(tester, find.text('Refresh register'));
      await tester.tap(find.text('Refresh register'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Previously loaded register may be stale.'),
        findsOneWidget,
      );
      expect(find.text('Register folder'), findsOneWidget);
      api.read = (_) async => _register('Recovered register');
      await _show(tester, find.text('Retry register'));
      await tester.tap(find.text('Retry register'));
      await tester.pumpAndSettle();
      expect(find.text('Recovered register'), findsOneWidget);
      expect(find.textContaining('may be stale'), findsNothing);
    },
  );

  testWidgets(
    'folder and history push exact ID and return to retained register',
    (tester) async {
      final api = _Api();
      await _mount(tester, api);
      await _show(tester, find.text('Open folder'));
      await tester.tap(find.text('Open folder'));
      await tester.pumpAndSettle();
      expect(find.text('Folder $_id'), findsOneWidget);
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      expect(api.queries.length, 1);
      await _show(tester, find.text('Full history'));
      await tester.tap(find.text('Full history'));
      await tester.pumpAndSettle();
      expect(find.text('History $_id'), findsOneWidget);
    },
  );

  testWidgets('an earlier login cannot publish its delayed register read', (
    tester,
  ) async {
    final pending = Completer<Map<String, dynamic>>();
    final api = _Api()..read = (_) => pending.future;
    final auth = _Auth(api);
    await _mount(tester, api, auth: auth, settle: false);
    auth.identity = Object();
    pending.complete(_register('Earlier login evidence'));
    await tester.pump();
    expect(find.text('Earlier login evidence'), findsNothing);
  });

  testWidgets(
    'report counts, export failure and exception history preserve preview',
    (tester) async {
      final api = _Api()..failExport = true;
      await _mount(tester, api, full: true);
      expect(find.text('2 folders'), findsOneWidget);
      expect(find.text('1 folder'), findsNWidgets(2));
      expect(find.text('Awaiting receipt'), findsOneWidget);
      await _show(tester, find.text('Download CSV'));
      await tester.tap(find.text('Download CSV'));
      await tester.pumpAndSettle();
      expect(api.exportQueries.single['as_of'], '2026-10-23 10:00:00');
      expect(api.exportQueries.single['movement_watermark'], '77');
      expect(api.exportQueries.single['correction_watermark'], '3');
      expect(find.textContaining('Export failed.'), findsOneWidget);
      expect(find.textContaining('Custody report unavailable.'), findsNothing);
      await _show(tester, find.text('By office'));
      expect(api.queries.last['as_of'], '2026-10-23 10:00:00');
      expect(api.queries.last['movement_watermark'], '77');
      expect(api.queries.last['correction_watermark'], '3');
      expect(find.text('By office'), findsOneWidget);
      // The Exceptions part is opened from its chip, as on the web.
      final exceptionsChip = find.byWidgetPredicate(
        (widget) =>
            widget is ChoiceChip &&
            widget.label is Text &&
            ((widget.label as Text).data ?? '').startsWith('Exceptions'),
      );
      await _show(tester, exceptionsChip);
      await tester.ensureVisible(exceptionsChip);
      await tester.tap(exceptionsChip);
      await tester.pumpAndSettle();
      await _show(tester, find.textContaining('Unreceived transfer evidence'));
      await tester.tap(find.textContaining('Unreceived transfer evidence'));
      await tester.pumpAndSettle();
      expect(find.text('History $_id'), findsOneWidget);
    },
  );

  testWidgets('a shrinking register returns to its valid first page', (
    tester,
  ) async {
    var shrink = false;
    final api = _Api()
      ..read = (query) async {
        final page = int.parse(query['page']!);
        if (shrink && page == 2) {
          return {'documents': [], 'total': 1, 'total_pages': 1, 'page': 2};
        }
        return _register('Valid page $page', page: page, pages: shrink ? 1 : 2);
      };
    await _mount(tester, api);
    await _show(tester, find.text('Next page'));
    await tester.tap(find.text('Next page'));
    await tester.pumpAndSettle();
    shrink = true;
    await _show(tester, find.text('Refresh register'));
    await tester.tap(find.text('Refresh register'));
    await tester.pumpAndSettle();
    expect(api.queries.map((query) => query['page']), ['1', '2', '2', '1']);
    expect(find.text('Valid page 1'), findsOneWidget);
    expect(find.text('No matching folders'), findsNothing);
  });

  testWidgets(
    'failed stale-empty refresh does not claim a fresh empty register',
    (tester) async {
      final api = _Api()
        ..read = (_) async => {
          'documents': [],
          'total': 0,
          'total_pages': 0,
          'page': 1,
        };
      await _mount(tester, api);
      expect(find.text('No matching folders'), findsOneWidget);
      api.read = (_) async =>
          throw ApiException('Controlled empty refresh failure');
      await _show(tester, find.text('Refresh register'));
      await tester.tap(find.text('Refresh register'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Previously loaded register may be stale.'),
        findsOneWidget,
      );
      expect(find.text('No matching folders'), findsNothing);
    },
  );

  testWidgets('register evidence and paging fit 320px with doubled text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = _Api()
      ..read = (_) async => _register(
        'Long folder title with all supporting pages retained for review',
        pages: 2,
      );
    await _mount(tester, api, scale: 2);
    await _show(tester, find.text('Next page'));
    expect(find.text('Next page'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
