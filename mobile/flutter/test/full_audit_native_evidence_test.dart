import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartflow/providers/auth_provider.dart';
import 'package:smartflow/screens/admin/admin_qr_monitor_screen.dart';
import 'package:smartflow/screens/staff/staff_shell.dart';
import 'package:smartflow/theme/smartflow_theme.dart';
import 'package:smartflow/widgets/document_journey.dart';
import 'package:smartflow/widgets/folder_contents.dart';
import 'package:smartflow/widgets/sf_pdf_chrome.dart';

Map<String, dynamic> _user(int id) => {
  'id': id,
  'username': 'synthetic$id',
  'name': 'Synthetic $id',
  'email': 'synthetic$id@example.test',
  'role': 'admin',
  'office_id': 3,
  'office_code': 'ACC',
  'office_name': 'Accounting Office',
};
http.Response _ok(Map<String, dynamic> data) =>
    http.Response(jsonEncode({'success': true, ...data}), 200);
http.Response _unavailable() => http.Response(
  jsonEncode({'success': false, 'message': 'Synthetic monitor unavailable'}),
  503,
);
Map<String, dynamic> _audit(String id, {int accepted = 7}) => {
  'summary': {'accepted': accepted, 'rejected': 2},
  'events': [
    {
      'document_id': id,
      'outcome': 'success',
      'created_at': '2026-10-14 10:00:00',
    },
  ],
};

Future<AuthProvider> _auth(
  Future<http.Response> Function(http.Request) handler,
) async {
  final auth = AuthProvider(
    httpClient: MockClient((request) async {
      if (request.url.path.endsWith('auth-login.php')) {
        final id = (jsonDecode(request.body) as Map)['username'] == 'synthetic2'
            ? 2
            : 1;
        return _ok({'token': 'synthetic-session-$id', 'user': _user(id)});
      }
      return handler(request);
    }),
  );
  await auth.login('synthetic1', 'synthetic-password');
  return auth;
}

Future<void> _mount(
  WidgetTester tester,
  AuthProvider auth,
  Widget screen, {
  bool settle = true,
  Size size = const Size(600, 2400),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => Scaffold(body: screen),
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
      ),
    ),
  );
  if (settle) await tester.pumpAndSettle();
  await tester.pump();
}

Future<void> _refresh(WidgetTester tester) async {
  final refresh = tester.widget<RefreshIndicator>(
    find.byType(RefreshIndicator),
  );
  await refresh.onRefresh();
  await tester.pumpAndSettle();
}

SfSecondaryOutlineButton _exportButton(WidgetTester tester) => tester
    .widget<SfSecondaryOutlineButton>(find.byType(SfSecondaryOutlineButton));

const _earlierReceipt = <String, dynamic>{
  'total_pages': 4,
  'registered_total_pages': 7,
  'status': 'incomplete',
  'reason':
      'Synthetic missing appendix at first receipt; the receiver recorded every missing page.',
  'items': [
    {
      'name': 'Synthetic appendix',
      'pages': 4,
      'registered_pages': 7,
      'required': true,
    },
  ],
};
const _movements = <Map<String, dynamic>>[
  {
    'id': 100,
    'status': 'IN',
    'office_name': 'Budget Office',
    'user_name': 'Synthetic prior receiver',
    'scanned_at': '2026-10-12 10:00:00',
    'remarks': 'Synthetic recorded receipt',
    'contents_receipt': _earlierReceipt,
  },
  {
    'id': 101,
    'status': 'IN',
    'office_name': 'Accounting Office',
    'user_name': 'Synthetic current receiver',
    'scanned_at': '2026-10-13 10:00:00',
    'contents_receipt': {'total_pages': 7, 'status': 'complete'},
  },
  {
    'id': 102,
    'status': 'IN',
    'office_name': 'Engineering Office',
    'user_name': 'Synthetic legacy receiver',
    'scanned_at': '2026-10-14 10:00:00',
  },
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'QR initial failure is unavailable; retry alone verifies empty counts',
    (tester) async {
      var failing = true;
      final auth = await _auth((request) async {
        if (failing) return _unavailable();
        return _ok(
          request.url.path.endsWith('audit-scans.php')
              ? {
                  'summary': {'accepted': 0, 'rejected': 0},
                  'events': [],
                }
              : {'events': []},
        );
      });
      await _mount(tester, auth, const AdminQrMonitorScreen());
      expect(find.text('Synthetic monitor unavailable'), findsOneWidget);
      expect(find.text('0'), findsNothing);
      expect(find.text('No scan events'), findsNothing);
      expect(find.text('No admin actions'), findsNothing);
      expect(find.byType(SfSecondaryOutlineButton), findsNothing);
      failing = false;
      await tester.tap(find.text('Retry QR monitor'));
      await tester.pumpAndSettle();
      expect(find.text('0'), findsNWidgets(2));
      expect(find.text('No scan events'), findsOneWidget);
      expect(find.text('No admin actions'), findsOneWidget);
      expect(_exportButton(tester).onPressed, isNotNull);
      auth.dispose();
    },
  );

  testWidgets(
    'QR failed refresh labels same-filter data stale and blocks export until retry',
    (tester) async {
      var failing = false;
      final auth = await _auth((request) async {
        if (failing) return _unavailable();
        return _ok(
          request.url.path.endsWith('audit-scans.php')
              ? _audit('DOC-SYNTHETIC-48')
              : {'events': []},
        );
      });
      await _mount(tester, auth, const AdminQrMonitorScreen());
      failing = true;
      await _refresh(tester);
      expect(find.text('DOC-SYNTHETIC-48'), findsOneWidget);
      expect(find.textContaining('they may be stale'), findsOneWidget);
      expect(_exportButton(tester).onPressed, isNull);
      failing = false;
      await tester.tap(find.text('Retry QR monitor'));
      await tester.pumpAndSettle();
      expect(find.textContaining('they may be stale'), findsNothing);
      expect(_exportButton(tester).onPressed, isNotNull);
      auth.dispose();
    },
  );

  testWidgets(
    'QR failed changed window never displays older query rows or totals',
    (tester) async {
      var newWindowAvailable = false;
      final queries = <String>[];
      final auth = await _auth((request) async {
        if (!request.url.path.endsWith('audit-scans.php')) {
          return _ok({'events': []});
        }
        final hours = request.url.queryParameters['hours']!;
        queries.add(hours);
        if (hours == '24' && !newWindowAvailable) return _unavailable();
        return _ok(_audit('DOC-SYNTHETIC-$hours'));
      });
      await _mount(tester, auth, const AdminQrMonitorScreen());
      await tester.tap(find.text('24h'));
      await tester.pumpAndSettle();
      expect(find.text('DOC-SYNTHETIC-48'), findsNothing);
      expect(find.text('7'), findsNothing);
      expect(find.text('No scan events'), findsNothing);
      newWindowAvailable = true;
      await tester.tap(find.text('Retry QR monitor'));
      await tester.pumpAndSettle();
      expect(find.text('DOC-SYNTHETIC-24'), findsOneWidget);
      expect(queries, ['48', '24', '24']);
      auth.dispose();
    },
  );

  testWidgets(
    'QR failed outcome filter does not relabel previous all-scan results',
    (tester) async {
      final auth = await _auth((request) async {
        if (!request.url.path.endsWith('audit-scans.php')) {
          return _ok({'events': []});
        }
        if (request.url.queryParameters['outcome'] == 'rejected') {
          return _unavailable();
        }
        return _ok(_audit('DOC-SYNTHETIC-ALL'));
      });
      await _mount(tester, auth, const AdminQrMonitorScreen());
      await tester.tap(find.widgetWithText(ChoiceChip, 'Rejected'));
      await tester.pumpAndSettle();
      expect(find.text('DOC-SYNTHETIC-ALL'), findsNothing);
      expect(find.text('No scan events'), findsNothing);
      expect(find.byType(SfSecondaryOutlineButton), findsNothing);
      auth.dispose();
    },
  );

  for (final oldFails in [false, true]) {
    testWidgets(
      'QR newer refresh ignores older ${oldFails ? 'failure' : 'success'}',
      (tester) async {
        final old = Completer<http.Response>();
        var reads = 0;
        final auth = await _auth((request) async {
          if (!request.url.path.endsWith('audit-scans.php')) {
            return _ok({'events': []});
          }
          reads++;
          if (reads == 1) return old.future;
          return _ok(_audit('DOC-SYNTHETIC-NEW', accepted: 9));
        });
        await _mount(tester, auth, const AdminQrMonitorScreen(), settle: false);
        final refresh = tester.widget<RefreshIndicator>(
          find.byType(RefreshIndicator),
        );
        await refresh.onRefresh();
        await tester.pumpAndSettle();
        expect(find.text('DOC-SYNTHETIC-NEW'), findsOneWidget);
        old.complete(
          oldFails ? _unavailable() : _ok(_audit('DOC-SYNTHETIC-OLD')),
        );
        await tester.pumpAndSettle();
        expect(find.text('DOC-SYNTHETIC-NEW'), findsOneWidget);
        expect(find.text('DOC-SYNTHETIC-OLD'), findsNothing);
        expect(
          find.textContaining('Synthetic monitor unavailable'),
          findsNothing,
        );
        expect(_exportButton(tester).onPressed, isNotNull);
        auth.dispose();
      },
    );
  }

  testWidgets(
    'QR delayed old-account response cannot replace new-account snapshot',
    (tester) async {
      final old = Completer<http.Response>();
      final auth = await _auth((request) async {
        if (!request.url.path.endsWith('audit-scans.php')) {
          return _ok({'events': []});
        }
        if (request.headers['Authorization'] == 'Bearer synthetic-session-1') {
          return old.future;
        }
        return _ok(_audit('DOC-SYNTHETIC-ACCOUNT-2'));
      });
      await _mount(tester, auth, const AdminQrMonitorScreen(), settle: false);
      await auth.login('synthetic2', 'synthetic-password');
      await tester.pumpAndSettle();
      expect(find.text('DOC-SYNTHETIC-ACCOUNT-2'), findsOneWidget);
      old.complete(_ok(_audit('DOC-SYNTHETIC-ACCOUNT-1')));
      await tester.pumpAndSettle();
      expect(find.text('DOC-SYNTHETIC-ACCOUNT-2'), findsOneWidget);
      expect(find.text('DOC-SYNTHETIC-ACCOUNT-1'), findsNothing);
      auth.dispose();
    },
  );

  testWidgets(
    'QR export stays on reviewed filter and never saves a late old-account CSV',
    (tester) async {
      final csv = Completer<http.Response>();
      final csvRequests = <http.Request>[];
      var saves = 0;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('smartflow/report_export'),
        (call) async {
          saves++;
          return true;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('smartflow/report_export'),
          null,
        ),
      );
      final auth = await _auth((request) async {
        if (request.url.queryParameters['format'] == 'csv') {
          csvRequests.add(request);
          return csv.future;
        }
        return _ok(
          request.url.path.endsWith('audit-scans.php')
              ? _audit('DOC-SYNTHETIC')
              : {'events': []},
        );
      });
      await _mount(tester, auth, const AdminQrMonitorScreen());
      await tester.tap(find.text('Download scan CSV'));
      await tester.pump();
      expect(csvRequests.single.url.queryParameters['hours'], '48');
      expect(csvRequests.single.url.queryParameters['outcome'], 'all');
      expect(
        csvRequests.single.headers['Authorization'],
        'Bearer synthetic-session-1',
      );
      final chip = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, '24h'),
      );
      expect(chip.onSelected, isNull);
      await auth.login('synthetic2', 'synthetic-password');
      await tester.pumpAndSettle();
      csv.complete(http.Response('synthetic,csv', 200));
      await tester.pumpAndSettle();
      expect(saves, 0);
      expect(_exportButton(tester).onPressed, isNotNull);
      auth.dispose();
    },
  );

  testWidgets(
    'History preserves every receipt and full earlier discrepancy alongside later counts',
    (tester) async {
      final auth = await _auth((request) async {
        if (request.url.path.endsWith('documents-movements.php')) {
          return _ok({'movements': _movements});
        }
        if (request.url.path.endsWith('documents-show.php')) {
          return _ok({
            'document': {
              'id': 'DOC-2026-000999',
              'title': 'Synthetic receipt history folder',
              'type': 'Others: Sample',
              'current_office_name': 'Accounting Office',
              'current_status': 'IN',
            },
          });
        }
        return _ok({
          'movements': [],
          'stats': {'total': 0},
          'total': 0,
          'page': 1,
          'page_size': 25,
          'has_more': false,
        });
      });
      await _mount(
        tester,
        auth,
        const StaffHistoryScreen(
          initialDocumentId: 'DOC-2026-000999',
          monitorOnly: true,
        ),
      );
      expect(find.text('Synthetic prior receiver'), findsOneWidget);
      expect(find.text('Synthetic recorded receipt'), findsOneWidget);
      expect(find.text(_earlierReceipt['reason'] as String), findsOneWidget);
      expect(
        find.text(
          'Synthetic appendix: 7 registered → 4 received · 3 pages missing',
        ),
        findsOneWidget,
      );
      expect(
        find.text('7 registered pages · 4 received pages'),
        findsOneWidget,
      );
      expect(find.text('7 received pages'), findsOneWidget);
      expect(
        find.text('Contents not recorded for this receipt.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      auth.dispose();
    },
  );

  testWidgets(
    'Document journey shows historical counts and legacy absence without fabricating OUT receipts',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildSmartflowTheme(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: DocumentJourney(
                document: {
                  'current_office_name': 'Accounting Office',
                  'current_status': 'IN',
                  'journey': [
                    ..._movements,
                    {
                      'status': 'OUT',
                      'office_name': 'Accounting Office',
                      'user_name': 'Synthetic sender',
                      'scanned_at': '2026-10-15 10:00:00',
                      'elapsed_hours': 1,
                    },
                  ],
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(_earlierReceipt['reason'] as String), findsOneWidget);
      expect(
        find.text(
          'Synthetic appendix: 7 registered → 4 received · 3 pages missing',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Contents not recorded for this receipt.'),
        findsOneWidget,
      );
      expect(find.byType(FolderReceiptSummary), findsNWidgets(3));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Historical contents tolerate missing old totals and wrap full notes on narrow enlarged text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
              child: const SingleChildScrollView(
                child: FolderReceiptSummary(
                  receipt: {
                    'reason':
                        'A long historical note remains fully available without guessed registered totals or clipping.',
                    'items': [
                      {
                        'name':
                            'Required historical attachment with a long name',
                        'pages': 0,
                        'required': true,
                      },
                    ],
                  },
                ),
              ),
            ),
          ),
        ),
      );
      expect(
        find.text('Page totals not recorded for this receipt.'),
        findsOneWidget,
      );
      expect(find.textContaining('required item missing'), findsOneWidget);
      expect(find.textContaining('guessed registered totals'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
