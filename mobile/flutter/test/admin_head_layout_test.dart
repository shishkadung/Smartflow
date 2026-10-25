import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartflow/models/user.dart';
import 'package:smartflow/providers/auth_provider.dart';
import 'package:smartflow/screens/admin/admin_shell.dart';
import 'package:smartflow/screens/head/head_shell.dart';
import 'package:smartflow/services/api_client.dart';
import 'package:smartflow/services/smartflow_api.dart';
import 'package:smartflow/theme/smartflow_theme.dart';

class _LayoutApi extends SmartflowApi {
  _LayoutApi() : super(ApiClient());
  @override
  Future<Map<String, dynamic>> reportsRegister(Map<String, String> query) async =>
      {'documents': [], 'total': 0, 'total_pages': 0, 'page': 1};

  Map<String, dynamic> get report => {
    'export_allowed': true,
    'generated_at': '2026-10-14 15:00:00',
    'timezone': 'Asia/Manila',
    'scope': 'Municipal offices',
    'prepared_by': 'Municipal Accountant',
    'submission_note':
        'Review the custody trail before submitting this report.',
    'compliance': {
      'on_time': {'percent': 75},
      'unforwarded': {'percent': 10},
      'delayed': {'percent': 15},
    },
    'totals': {'documents_in_period': 24},
    'office_totals': [
      {
        'office_name': 'Municipal Engineering and Public Works Office',
        'office_code': 'ENG',
        'docs_processed': 24,
      },
    ],
  };

  @override
  Future<Map<String, dynamic>> reportsSummary(
    int officeId,
    String month,
  ) async => report;
  @override
  Future<Map<String, dynamic>> reportsSummaryQuarterly(
    int officeId,
    int year,
    int quarter,
  ) async => report;
  @override
  Future<Map<String, dynamic>> reportsSummaryAnnual(
    int officeId,
    int year,
  ) async => report;
  @override
  Future<Map<String, dynamic>> auditExceptions({
    int hours = 24,
    Map<String, String> period = const {},
  }) async => {'exceptions': []};
  @override
  Future<Map<String, dynamic>> usersList() async => {
    'users': [
      {
        'id': 202,
        'username': 'engineering.office.staff.account',
        'role': 'staff',
        'office_name': 'Municipal Engineering and Public Works Office',
        'office_code': 'ENG',
        'is_active': true,
      },
    ],
  };
  @override
  Future<Map<String, dynamic>> signupPending() async => {
    'pending': [
      {
        'id': 203,
        'username': 'new.engineering.office.account',
        'requested_role': 'staff',
        'office_name': 'Municipal Engineering and Public Works Office',
        'office_code': 'ENG',
        'request_code': 'SIGNUP-2026-000003',
      },
    ],
  };
  @override
  Future<Map<String, dynamic>> headDashboard(int officeId) async => {
    'queue': [
      {
        'document_id': 'DOC-2026-000001',
        'title': 'Road repairs with complete annexes and supporting estimates',
        'type': 'Disbursement Voucher',
        'meta': 'Municipal Engineering Office · Received October 14, 2026',
        'status_label': 'overdue',
        'status_pill': 'Overdue',
        'hours_pending': 123,
      },
    ],
  };
}

class _LayoutAuth extends AuthProvider {
  _LayoutAuth(this.role);
  final String role;
  @override
  final SmartflowApi api = _LayoutApi();
  @override
  bool get isAuthenticated => true;
  @override
  AppUser get user => AppUser(
    id: 101,
    name: 'Layout reviewer',
    username: 'layout',
    role: role,
    officeId: 4,
    officeName: 'Accounting Office',
    officeCode: 'ACC',
  );
}

Future<void> _mount(
  WidgetTester tester,
  Widget page,
  double scale, {
  String role = 'admin',
}) async {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => Scaffold(body: page),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ChangeNotifierProvider<AuthProvider>(
      key: UniqueKey(),
      create: (_) => _LayoutAuth(role),
      child: MaterialApp.router(
        theme: buildSmartflowTheme().copyWith(platform: TargetPlatform.windows),
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  expect(tester.takeException(), isNull);
}

Future<void> _scrollPage(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.drag(find.byType(ListView).first, const Offset(0, -300));
    await tester.pump(const Duration(milliseconds: 250));
    expect(tester.takeException(), isNull);
  }
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
}

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'Admin reports, users and head queue fit 320px / ${scale}x text',
      (tester) async {
        GoogleFonts.config.allowRuntimeFetching = false;
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = const Size(320, 740);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await _mount(tester, const AdminReportsScreen(), scale);
        expect(find.text('Monthly'), findsOneWidget);
        await tester.tap(find.text('Quarterly'));
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(find.text('Change quarter'), 180);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Change quarter'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Change quarter'));
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('Report quarter'), findsOneWidget);
        expect(tester.takeException(), isNull);
        final now = DateTime.now();
        final quarter = ((now.month - 1) ~/ 3) + 1;
        await tester.tap(
          find.descendant(
            of: find.byType(SimpleDialog),
            matching: find.text('Q$quarter ${now.year}'),
          ),
        );
        await tester.pump(const Duration(milliseconds: 400));
        await _scrollPage(tester);

        await _mount(tester, const AdminUsersScreen(), scale);
        await _scrollPage(tester);

        await _mount(tester, const HeadQueueScreen(), scale, role: 'head');
        await _scrollPage(tester);
      },
    );
  }
}
