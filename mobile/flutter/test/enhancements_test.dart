import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:smartflow/models/user.dart';
import 'package:smartflow/providers/auth_provider.dart';
import 'package:smartflow/services/api_client.dart';
import 'package:smartflow/services/api_connectivity.dart';
import 'package:smartflow/services/smartflow_api.dart';
import 'package:smartflow/screens/shared/documents_screen.dart';
import 'package:smartflow/utils/document_queue.dart';
import 'package:smartflow/widgets/document_journey.dart';
import 'package:smartflow/widgets/sf_widgets.dart';
import 'package:smartflow/screens/auth/forgot_password_screen.dart';
import 'package:smartflow/screens/admin/admin_shell.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';

const _doc = {
  'id': 'DOC-2026-000001',
  'title': 'Controlled incoming folder',
  'type': 'Approved Budget',
  'reference_no': 'QA-1',
  'current_office_name': 'Budget Office',
  'origin_office_name': 'Budget Office',
  'destination_office_name': 'Engineering Office',
  'tray': 'incoming',
  'current_status': 'OUT',
  'last_movement_id': 2,
  'qr_payload': 'DOC-2026-000001',
  'is_overdue': true,
  'hours_waiting': 26,
  'journey': [
    {
      'id': 1,
      'status': 'IN',
      'office_name': 'Budget Office',
      'user_name': 'QA Staff',
      'scanned_at': '2026-10-01 08:00:00',
      'elapsed_hours': 2,
      'duration_kind': 'at_office',
      'is_current': false,
    },
    {
      'id': 2,
      'status': 'OUT',
      'office_name': 'Budget Office',
      'destination_office_name': 'Engineering Office',
      'user_name': 'QA Staff',
      'scanned_at': '2026-10-01 10:00:00',
      'elapsed_hours': 26,
      'duration_kind': 'in_transit',
      'is_current': true,
    },
  ],
};

class _FixtureApi extends SmartflowApi {
  _FixtureApi() : super(ApiClient());
  bool fail = false;
  Map<String, dynamic> doc = Map.from(_doc);
  Completer<Map<String, dynamic>>? pending;
  @override
  Future<Map<String, dynamic>> officeDocuments({String? id}) async {
    if (fail) throw ApiException('Cannot reach portal');
    if (id != null && pending != null) return pending!.future;
    return id == null
        ? {
            'documents': [doc],
          }
        : {'document': doc};
  }
}

class _FixtureAuth extends AuthProvider {
  _FixtureAuth(this.fixture);
  final _FixtureApi fixture;
  @override
  SmartflowApi get api => fixture;
  @override
  AppUser get user => const AppUser(
    id: 101,
    name: 'QA Staff',
    username: 'qa.staff',
    role: 'staff',
    officeId: 1,
    officeName: 'Engineering Office',
    officeCode: 'ENG',
  );
}

class _ReportApi extends SmartflowApi {
  _ReportApi() : super(ApiClient());
  final exported = <String>[];
  @override
  Future<Map<String, dynamic>> reportsSummary(
    int officeId,
    String month,
  ) async => {
    'office_id': 4,
    'period': 'month',
    'month': '2026-10',
    'year': '2026',
    'export_allowed': true,
    'period_start': '2026-10-01 00:00:00',
    'generated_at': '2026-10-03 15:00:00',
    'timezone': 'Asia/Manila',
    'scope': 'Municipal system (all offices)',
    'prepared_by': 'QA Accountant',
    'totals': {'documents_in_period': 1},
    'compliance': {
      'on_time': {'count': 1, 'percent': 100},
    },
    'office_totals': [],
  };
  @override
  Future<Map<String, dynamic>> auditExceptions({
    int hours = 24,
    Map<String, String>? period,
  }) async => {'exceptions': []};
  @override
  Future<String> reportExport(Map<String, String> query, String format) async {
    expect(query['month'], '2026-10');
    exported.add(format);
    return format == 'csv'
        ? '\uFEFFPeriod,October 2026\r\n'
        : '<!doctype html><html><title>SmartFlow</title></html>';
  }
}

class _ReportAuth extends AuthProvider {
  _ReportAuth(this.fixture);
  final _ReportApi fixture;
  @override
  SmartflowApi get api => fixture;
  @override
  AppUser get user => const AppUser(
    id: 102,
    name: 'QA Accountant',
    username: 'qa.admin',
    role: 'admin',
    officeId: 4,
    officeName: 'Accounting Office',
    officeCode: 'ACC',
  );
}

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });
  test('queue sorting, search and overdue include only open records', () {
    final documents = [
      {..._doc, 'id': 'A', 'due_at': '2026-10-01', 'hours_waiting': 20},
      {..._doc, 'id': 'B', 'due_at': '2026-10-02', 'hours_waiting': 30},
      {
        ..._doc,
        'id': 'C',
        'tray': 'completed',
        'is_overdue': false,
        'hours_waiting': 100,
      },
    ];
    expect(documentQueue(documents, tray: 'incoming').map((d) => d['id']), [
      'A',
      'B',
    ]);
    expect(
      documentQueue(
        documents,
        tray: 'incoming',
        sort: 'waiting',
      ).map((d) => d['id']),
      ['B', 'A'],
    );
    expect(
      documentQueue(documents, tray: 'in_office', overdueOnly: true).length,
      2,
    );
    expect(
      documentQueue(documents, tray: 'incoming', search: 'QA-1').length,
      2,
    );
    expect(documents.map((d) => d['id']), ['A', 'B', 'C']);
    expect(elapsedLabel(26), '1d 2h');
  });
  test(
    'failed write sends once, retains last contact and reports reconnection',
    () async {
      var calls = 0;
      var failed = false;
      final client = ApiClient(
        client: MockClient((_) async {
          calls++;
          if (failed) throw http.ClientException('Offline');
          return http.Response('{"success":true}', 200);
        }),
      );
      await client.get('read.php');
      final contact = ApiConnectivity.instance.lastSuccess;
      failed = true;
      await expectLater(
        client.post('move.php', body: {}),
        throwsA(isA<ApiException>()),
      );
      expect(calls, 2);
      expect(ApiConnectivity.instance.unavailable, isTrue);
      expect(ApiConnectivity.instance.lastSuccess, contact);
      failed = false;
      await client.get('read.php');
      expect(ApiConnectivity.instance.unavailable, isFalse);
    },
  );
  test(
    'report export uses saved period and authenticated text request',
    () async {
      final api = SmartflowApi(
        ApiClient(
          token: 'fixture',
          client: MockClient((request) async {
            expect(request.url.queryParameters['format'], 'csv');
            expect(request.url.queryParameters['quarter'], '4');
            expect(request.headers['Authorization'], 'Bearer fixture');
            return http.Response.bytes(
              utf8.encode('\uFEFFPeriod,Q4 2026\r\n'),
              200,
              headers: {'content-type': 'text/csv; charset=utf-8'},
            );
          }),
        ),
      );
      expect(
        await api.reportExport({
          'office_id': '4',
          'period': 'quarter',
          'year': '2026',
          'quarter': '4',
        }, 'csv'),
        contains('Q4 2026'),
      );
    },
  );
  testWidgets(
    'journey fits small screens and completed trails have no ongoing timer',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DocumentJourney(document: {..._doc, 'tray': 'completed'}),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Journey complete'), findsOneWidget);
      expect(find.textContaining('ongoing'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'production recovery offers code entry without a development code',
    (tester) async {
      final api = SmartflowApi(
        ApiClient(
          client: MockClient((request) async {
            expect(jsonDecode(request.body)['username'], 'qa.staff');
            return http.Response(
              '{"success":true,"message":"If an account exists, check its email."}',
              200,
            );
          }),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(home: ForgotPasswordScreen(api: api)),
      );
      await tester.enterText(find.byType(TextField).first, 'qa.staff');
      final send = find.text('Send reset code');
      await tester.ensureVisible(send);
      await tester.tap(send);
      await tester.pump();
      await tester.pump();
      expect(find.text('Enter reset code'), findsOneWidget);
      expect(find.text('Verify & reset password'), findsOneWidget);
      expect(find.textContaining('Development test code'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('report buttons invoke real file-save and print bridges', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final api = _ReportApi();
    final auth = _ReportAuth(api);
    final calls = <MethodCall>[];
    const channel = MethodChannel('smartflow/report_export');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return true;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    final router = GoRouter(
      initialLocation: '/admin/reports',
      routes: [
        GoRoute(
          path: '/admin/reports',
          builder: (_, _) => const Scaffold(body: AdminReportsScreen()),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump();
    final download = find.text('Download CSV');
    await tester.ensureVisible(download);
    await tester.tap(download);
    await tester.pumpAndSettle();
    expect(calls.single.method, 'saveCsv');
    expect(
      calls.single.arguments['filename'],
      'SmartFlow-custody-month-2026-10-01.csv',
    );
    final savedBytes = calls.single.arguments['bytes'] as List<int>;
    expect(savedBytes.take(3), [0xEF, 0xBB, 0xBF]);
    expect(utf8.decode(savedBytes), startsWith('Period'));
    final print = find.text('Print / Save PDF');
    await tester.ensureVisible(print);
    await tester.tap(print);
    await tester.pumpAndSettle();
    expect(calls.last.method, 'printReport');
    expect(calls.last.arguments['html'], startsWith('<!doctype html>'));
    expect(api.exported, ['csv', 'print']);
    await tester.pumpWidget(const SizedBox());
    auth.dispose();
  });
  testWidgets(
    'failed refresh disables receipt until custody is verified again',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = _FixtureApi();
      final auth = _FixtureAuth(api);
      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>.value(
          value: auth,
          child: const MaterialApp(
            home: Scaffold(
              body: DocumentsScreen(initialDocumentId: 'DOC-2026-000001'),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.byType(CheckboxListTile), findsNothing);
      final receiveButton = find.byWidgetPredicate(
        (w) => w is SfPrimaryButton && w.label == 'Receive (IN)',
      );
      expect(
        tester.widget<SfPrimaryButton>(receiveButton).onPressed,
        isNotNull,
      );
      api.fail = true;
      await tester.pump(const Duration(seconds: 15));
      await tester.pump();
      final receive = tester.widget<SfPrimaryButton>(receiveButton);
      expect(receive.onPressed, isNull);
      expect(find.text('Controlled incoming folder'), findsOneWidget);
      api.fail = false;
      ApiConnectivity.instance.refresh();
      await tester.pump();
      await tester.pump();
      expect(
        tester.widget<SfPrimaryButton>(receiveButton).onPressed,
        isNotNull,
      );
      api.doc = {...api.doc, 'last_movement_id': 4};
      await tester.pump(const Duration(seconds: 15));
      await tester.pump();
      expect(find.byType(CheckboxListTile), findsNothing);
      await tester.pumpWidget(const SizedBox());
      auth.dispose();
    },
  );
}
