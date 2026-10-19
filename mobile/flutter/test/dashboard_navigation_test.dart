import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartflow/models/user.dart';
import 'package:smartflow/providers/auth_provider.dart';
import 'package:smartflow/screens/admin/admin_shell.dart';
import 'package:smartflow/screens/admin/admin_widgets.dart';
import 'package:smartflow/screens/head/head_shell.dart';
import 'package:smartflow/screens/head/head_widgets.dart';
import 'package:smartflow/screens/shared/document_requests_screen.dart';
import 'package:smartflow/services/api_client.dart';
import 'package:smartflow/services/smartflow_api.dart';
import 'package:smartflow/theme/smartflow_theme.dart';

const _linkedRequest = <String, dynamic>{
  'id': 91,
  'request_code': 'REQ-2026-000091',
  'status': 'approved',
  'document_category': 'budget',
  'purpose':
      'Review the road maintenance budget and complete supporting papers.',
  'related_document_id': 'DOC-2026-000091',
  'requester': {
    'user_id': 20,
    'name': 'Requester',
    'office_name': 'Engineering',
  },
  'handler_office': {
    'office_id': 2,
    'office_name': 'Budget',
    'office_code': 'BUD',
  },
};

class _Api extends SmartflowApi {
  _Api() : super(ApiClient());
  bool fail = false;
  int reads = 0;

  Future<Map<String, dynamic>> _dashboard() async {
    reads++;
    if (fail) throw ApiException('Cannot reach portal');
    return {
      'stats': {
        'in_office': 4,
        'overdue': 0,
        'avg_hours': 3,
        'active_documents': 4,
        'pending_signups': 0,
      },
      'queue': [],
      'recent_movements': [],
      'office_totals': [],
    };
  }

  @override
  Future<Map<String, dynamic>> headDashboard(int officeId) => _dashboard();
  @override
  Future<Map<String, dynamic>> accountantDashboard() => _dashboard();
  @override
  Future<Map<String, dynamic>> alerts(int officeId) async =>
      throw ApiException('Alerts unavailable');
  @override
  Future<Map<String, dynamic>> documentRequestsSummary() async => {
    'pending_inbox_count': 0,
  };
  @override
  Future<Map<String, dynamic>> documentRequestsList({
    required String view,
    String? status,
    int page = 1,
    int pageSize = 25,
    bool overdue = false,
    String? search,
    int? requestId,
  }) async => {
    'requests': view == 'inbox' ? [_linkedRequest] : [],
    'pending_inbox_count': 0,
  };
}

class _Auth extends AuthProvider {
  _Auth(this.api, this.role);
  @override
  final SmartflowApi api;
  final String role;
  @override
  bool get isAuthenticated => true;
  @override
  AppUser get user => AppUser(
    id: 10,
    name: 'UI reviewer',
    username: 'ui.reviewer',
    role: role,
    officeId: 2,
    officeName: 'Budget Office',
    officeCode: 'BUD',
  );
}

Future<GoRouter> _mount(
  WidgetTester tester,
  _Api api,
  String role, {
  bool requests = false,
}) async {
  final router = GoRouter(
    initialLocation: '/$role',
    routes: [
      GoRoute(
        path: '/$role',
        builder: (_, _) => Scaffold(
          body: requests
              ? DocumentRequestsScreen(
                  homeRoute: '/$role',
                  initialRequestId: 91,
                )
              : role == 'head'
              ? const HeadDashboardScreen()
              : const AdminDashboardScreen(),
        ),
      ),
      GoRoute(
        path: '/$role/documents',
        builder: (_, state) => Scaffold(
          body: Text(
            'Folder ${state.uri.queryParameters['id']} scope ${state.uri.queryParameters['scope'] ?? 'office'}',
          ),
        ),
      ),
      GoRoute(
        path: '/$role/history',
        builder: (_, state) => Scaffold(
          body: Text('History ${(state.extra as Map)['documentId']}'),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ChangeNotifierProvider<AuthProvider>(
      create: (_) => _Auth(api, role),
      child: MaterialApp.router(
        theme: buildSmartflowTheme(),
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({
      'sf_role_tip_seen_v2_ui.reviewer': true,
    });
  });

  for (final role in ['head', 'admin']) {
    testWidgets(
      '$role failed dashboard has retry and recovers without an all-clear',
      (tester) async {
        final api = _Api()..fail = true;
        await _mount(tester, api, role);
        expect(find.textContaining('Dashboard unavailable.'), findsOneWidget);
        expect(find.text('Try again'), findsOneWidget);
        expect(find.byType(SfHeadStatRow), findsNothing);
        expect(find.byType(SfAdminStatRow), findsNothing);
        expect(find.text('No office activity yet'), findsNothing);
        expect(find.textContaining('Office on track'), findsNothing);
        api.fail = false;
        await tester.tap(find.text('Try again'));
        await tester.pumpAndSettle();
        expect(api.reads, 2);
        expect(find.textContaining('Dashboard unavailable.'), findsNothing);
        expect(find.text('4'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '$role retains successful counts with a stale label after refresh failure',
      (tester) async {
        final api = _Api();
        await _mount(tester, api, role);
        expect(find.text('4'), findsOneWidget);
        api.fail = true;
        await tester
            .widget<RefreshIndicator>(find.byType(RefreshIndicator).first)
            .onRefresh();
        await tester.pumpAndSettle();
        expect(
          find.textContaining(
            'Showing previously loaded data; counts may be out of date.',
          ),
          findsOneWidget,
        );
        expect(find.text('4'), findsOneWidget);
        expect(find.textContaining('Office on track'), findsNothing);
        expect(find.text('No office activity yet'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final role in ['staff', 'head', 'admin']) {
    testWidgets('$role opens its linked folder directly in Documents', (
      tester,
    ) async {
      await _mount(tester, _Api(), role, requests: true);
      await tester.tap(find.text('Open linked folder in Documents'));
      await tester.pumpAndSettle();
      // Imperative pushes do not replace the browser URI by default. Inspect the visible page's state.
      final uri = GoRouterState.of(
        tester.element(find.textContaining('Folder DOC-2026-000091')),
      ).uri;
      expect(uri.path, '/$role/documents');
      expect(uri.queryParameters['id'], 'DOC-2026-000091');
      expect(
        uri.queryParameters['scope'],
        role == 'admin' ? 'municipal' : null,
      );
      expect(find.textContaining('Folder DOC-2026-000091'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('linked folder keeps a separate full custody-history route', (
    tester,
  ) async {
    await _mount(tester, _Api(), 'staff', requests: true);
    await tester.tap(find.text('View custody history'));
    await tester.pumpAndSettle();
    expect(
      GoRouterState.of(
        tester.element(find.text('History DOC-2026-000091')),
      ).uri.path,
      '/staff/history',
    );
    expect(find.text('History DOC-2026-000091'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
