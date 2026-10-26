import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartflow/models/user.dart';
import 'package:smartflow/providers/auth_provider.dart';
import 'package:smartflow/screens/admin/admin_qr_monitor_screen.dart';
import 'package:smartflow/services/api_client.dart';
import 'package:smartflow/services/smartflow_api.dart';
import 'package:smartflow/theme/smartflow_theme.dart';

// The phone QR monitor shows the custody exceptions panel the web monitor has, for the Accounting administrator only.

class _Api extends SmartflowApi {
  _Api() : super(ApiClient());
  bool failExceptions = false;
  bool failScans = false;
  List<Map<String, dynamic>> exceptions = [
    {
      'document_id': 'DOC-2026-000077',
      'exception_type': 'unforwarded',
      'detail':
          'Sent from Budget Office on 2026-10-01; no receipt after 90 hours.',
      'last_scanned_at': '2026-10-01 08:00:00',
    },
    {
      'document_id': 'DOC-2026-000078',
      'exception_type': 'wrong_receiver',
      'detail': 'Received at Treasury Office, not the office it was sent to.',
    },
  ];
  int exceptionReads = 0;
  int scanReads = 0;

  @override
  Future<Map<String, dynamic>> auditScans({
    int hours = 48,
    String outcome = 'all',
    int? officeId,
    int? userId,
    int limit = 200,
  }) async {
    scanReads++;
    if (failScans) throw ApiException('Sample scan log unavailable', 503);
    return {
      'summary': {'accepted': 3, 'rejected': 1},
      'events': [
        {
          'outcome': 'success',
          'document_id': 'DOC-2026-000001',
          'office_code': 'ACC',
          'user_name': 'Sample staff',
          'message': 'Folder received',
          'created_at': '2026-10-26 08:00:00',
        },
      ],
      'suspicious': [],
      'top_reject_reasons': [],
    };
  }

  @override
  Future<Map<String, dynamic>> auditActivity({
    int hours = 168,
    String type = 'all',
    int limit = 100,
  }) async => {
    'events': [
      {
        'event_type': 'user.email_update',
        'username': 'sample.admin',
        'office_code': 'ACC',
        'message': 'Changed the reset email of ben_bud',
        'created_at': '2026-10-26 07:00:00',
      },
    ],
  };

  @override
  Future<Map<String, dynamic>> auditExceptions({
    int hours = 24,
    Map<String, String> period = const {},
  }) async {
    exceptionReads++;
    expect(hours, 24);
    if (failExceptions) {
      throw ApiException('Sample exceptions unavailable', 503);
    }
    return {'exceptions': exceptions};
  }
}

class _Auth extends AuthProvider {
  _Auth(this.fixture, this.officeCode);
  final _Api fixture;
  final String officeCode;
  @override
  SmartflowApi get api => fixture;
  @override
  bool get isAuthenticated => true;
  @override
  AppUser get user => AppUser(
    id: 101,
    name: 'Monitor reviewer',
    username: 'monitor.reviewer',
    role: 'admin',
    officeId: 4,
    officeName: '$officeCode Office',
    officeCode: officeCode,
  );
}

Future<List<String>> _mount(
  WidgetTester tester,
  _Api api, {
  String office = 'ACC',
  double width = 390,
  double scale = 1,
}) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = Size(width, 3600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final opened = <String>[];
  final auth = _Auth(api, office);
  addTearDown(auth.dispose);
  final router = GoRouter(
    initialLocation: '/admin/qr-monitor',
    routes: [
      GoRoute(
        path: '/admin/qr-monitor',
        builder: (_, _) => const Scaffold(body: AdminQrMonitorScreen()),
      ),
      GoRoute(
        path: '/admin/history',
        builder: (_, state) {
          opened.add('${(state.extra as Map)['documentId']}');
          return Scaffold(
            body: Text('History ${(state.extra as Map)['documentId']}'),
          );
        },
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ChangeNotifierProvider<AuthProvider>.value(
      value: auth,
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
  await tester.pumpAndSettle();
  return opened;
}

void main() {
  testWidgets(
    'the Accounting administrator sees each custody exception with its kind and what was found',
    (tester) async {
      final api = _Api();
      await _mount(tester, api);
      expect(find.text('Custody exceptions'), findsOneWidget);
      expect(
        find.textContaining(
          'Missing receipt records after 24 hours, receiver mismatches, route gaps and incomplete DV contents',
        ),
        findsOneWidget,
      );
      expect(find.text('DOC-2026-000077'), findsOneWidget);
      expect(find.text('Unforwarded OUT'), findsOneWidget);
      expect(find.text('Wrong receiver'), findsOneWidget);
      expect(find.textContaining('no receipt after 90 hours.'), findsOneWidget);
      expect(
        find.text(
          'Received at Treasury Office, not the office it was sent to.',
        ),
        findsOneWidget,
      );
      expect(api.exceptionReads, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('opening an exception shows that folder\'s full history', (
    tester,
  ) async {
    final opened = await _mount(tester, _Api());
    await tester.tap(find.text('DOC-2026-000078'));
    await tester.pumpAndSettle();
    expect(opened, ['DOC-2026-000078']);
    expect(find.text('History DOC-2026-000078'), findsOneWidget);
  });

  testWidgets(
    'another office\'s administrator is told it is Accounting only, and nothing is read',
    (tester) async {
      final api = _Api();
      await _mount(tester, api, office: 'BUD');
      expect(find.text('Custody exceptions'), findsOneWidget);
      expect(
        find.text(
          'Custody exceptions are available to Accounting administrators.',
        ),
        findsOneWidget,
      );
      expect(find.text('DOC-2026-000077'), findsNothing);
      expect(find.text('Retry exceptions'), findsNothing);
      expect(
        api.exceptionReads,
        0,
        reason: 'the server would refuse it, so it is not even asked',
      );
      // The scan monitor itself is unchanged.
      expect(find.text('Folder received'), findsOneWidget);
    },
  );

  testWidgets(
    'a failed exceptions read leaves the scan monitor intact, and Retry exceptions recovers',
    (tester) async {
      final api = _Api()..failExceptions = true;
      await _mount(tester, api);
      expect(
        find.textContaining(
          'Custody exceptions unavailable. Sample exceptions unavailable',
        ),
        findsOneWidget,
      );
      expect(find.text('Retry exceptions'), findsOneWidget);
      expect(find.text('No custody exceptions found'), findsNothing);
      expect(
        find.text('Folder received'),
        findsOneWidget,
        reason: 'scan events still show',
      );
      expect(find.text('3'), findsOneWidget, reason: 'the accepted count');
      api.failExceptions = false;
      await tester.tap(find.text('Retry exceptions'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Custody exceptions unavailable'),
        findsNothing,
      );
      expect(find.text('DOC-2026-000077'), findsOneWidget);
    },
  );

  testWidgets(
    'a failed scan log is its own failure, not a claim that there are no exceptions',
    (tester) async {
      final api = _Api()..failScans = true;
      await _mount(tester, api);
      expect(find.text('Retry QR monitor'), findsOneWidget);
      expect(find.text('No custody exceptions found'), findsNothing);
      expect(find.text('Custody exceptions'), findsNothing);
      api.failScans = false;
      await tester.tap(find.text('Retry QR monitor'));
      await tester.pumpAndSettle();
      expect(find.text('Custody exceptions'), findsOneWidget);
      expect(find.text('DOC-2026-000077'), findsOneWidget);
    },
  );

  testWidgets('a read that found nothing says so, as a verified empty result', (
    tester,
  ) async {
    final api = _Api()..exceptions = [];
    await _mount(tester, api);
    expect(find.text('No custody exceptions found'), findsOneWidget);
    expect(find.text('Retry exceptions'), findsNothing);
  });

  testWidgets('the activity log names a reset email change', (tester) async {
    await _mount(tester, _Api());
    expect(find.text('Reset email changed by administrator'), findsOneWidget);
  });

  testWidgets('the exceptions panel fits 320px with doubled text', (
    tester,
  ) async {
    await _mount(tester, _Api(), width: 320, scale: 2);
    expect(find.text('DOC-2026-000077'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
