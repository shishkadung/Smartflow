import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartflow/models/user.dart';
import 'package:smartflow/providers/auth_provider.dart';
import 'package:smartflow/screens/shared/document_requests_screen.dart';
import 'package:smartflow/screens/staff/staff_shell.dart';
import 'package:smartflow/services/api_client.dart';
import 'package:smartflow/services/smartflow_api.dart';
import 'package:smartflow/theme/smartflow_theme.dart';

Map<String, dynamic> _request(int id) => {
  'id': id,
  'request_code': 'REQ-2026-$id',
  'status': 'pending',
  'revision': 'revision-$id',
  'document_category': 'budget',
  'purpose': 'Complete purpose for ticket $id',
  'required_by': '2026-10-20',
  'requester': {'user_id': 12, 'office_code': 'ENG'},
  'handler_office': {'office_id': 2, 'office_code': 'BUD'},
};

class _RecordsApi extends SmartflowApi {
  _RecordsApi() : super(ApiClient());
  final requestReads = <Map<String, dynamic>>[];
  final activityReads = <Map<String, dynamic>>[];
  Map<String, dynamic>? decision;
  bool failActivity = false;

  @override
  Future<Map<String, dynamic>> documentRequestsList({
    required String view,
    String? status,
    int page = 1,
    int pageSize = 25,
    bool overdue = false,
    String? search,
    int? requestId,
  }) async {
    requestReads.add({
      'view': view,
      'page': page,
      'status': status,
      'overdue': overdue,
      'search': search,
      'id': requestId,
    });
    return {
      'requests': view == 'inbox' ? [_request(requestId ?? page)] : [],
      'page': page,
      'page_size': 1,
      'total': 5,
      'has_more': page < 5,
      'pending_inbox_count': 3,
      'counts': {
        'total': 5,
        'pending': 3,
        'active': 4,
        'past': 1,
        'overdue': 2,
      },
    };
  }

  @override
  Future<Map<String, dynamic>> documentRequestUpdate({
    required int requestId,
    required String action,
    String? reviewNotes,
    String? relatedDocumentId,
    String? expectedStatus,
    String? expectedRevision,
  }) async {
    decision = {
      'id': requestId,
      'action': action,
      'status': expectedStatus,
      'revision': expectedRevision,
    };
    return {'success': true};
  }

  @override
  Future<Map<String, dynamic>> dashboardStats(int officeId) async => {
    'active_documents': [],
    'recent_movements': [
      {'id': 1, 'document_id': 'PREVIEW-ONLY'},
    ],
  };

  @override
  Future<Map<String, dynamic>> officeMovements(
    int officeId, {
    String? date,
    String? status,
    int page = 1,
    int pageSize = 25,
  }) async {
    activityReads.add({
      'office': officeId,
      'date': date,
      'status': status,
      'page': page,
    });
    if (failActivity) throw ApiException('Office activity unavailable');
    return {
      'movements': [
        {
          'id': page,
          'document_id': 'DOC-2026-00000$page',
          'status': status ?? 'IN',
          'title': 'Office movement $page',
          'scanned_at': '$date 10:00:00',
        },
      ],
      'stats': {'total': 55, 'in_flow': 30, 'out_flow': 25},
      'total': status == 'IN'
          ? 30
          : status == 'OUT'
          ? 25
          : 55,
      'page': page,
      'page_size': 1,
      'has_more': true,
    };
  }
}

class _Auth extends AuthProvider {
  _Auth(this.fixture, {this.role = 'staff'});
  final _RecordsApi fixture;
  final String role;
  @override
  SmartflowApi get api => fixture;
  @override
  AppUser get user => AppUser(
    id: 21,
    username: 'records',
    name: 'Records user',
    role: role,
    officeId: 2,
    officeCode: 'BUD',
    officeName: 'Budget Office',
  );
}

Future<void> _mount(
  WidgetTester tester,
  Widget screen,
  _RecordsApi api, {
  String role = 'staff',
}) async {
  tester.view.physicalSize = const Size(390, 950);
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
    ChangeNotifierProvider<AuthProvider>(
      create: (_) => _Auth(api, role: role),
      child: MaterialApp.router(
        routerConfig: router,
        theme: buildSmartflowTheme(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'request pages, filters and search use whole-view server metadata',
    (tester) async {
      final api = _RecordsApi();
      await _mount(
        tester,
        const DocumentRequestsScreen(homeRoute: '/staff'),
        api,
      );
      expect(find.text('All (5)'), findsOneWidget);
      expect(find.text('Active (4)'), findsOneWidget);
      expect(api.requestReads.first['status'], 'active');
      expect(find.text('Overdue (2)'), findsOneWidget);
      expect(find.text('Page 1 of 5'), findsOneWidget);
      await tester.ensureVisible(find.text('Next'));
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(
        api.requestReads.lastWhere((r) => r['view'] == 'inbox')['page'],
        2,
      );
      expect(find.text('Page 2 of 5'), findsOneWidget);
      await tester.drag(find.byType(NestedScrollView), const Offset(0, 800));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Past (1)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Past (1)'));
      await tester.pumpAndSettle();
      expect(
        api.requestReads.lastWhere((r) => r['view'] == 'inbox')['status'],
        'past',
      );
      expect(
        api.requestReads.lastWhere((r) => r['view'] == 'inbox')['page'],
        1,
      );
      await tester.ensureVisible(find.text('Overdue (2)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Overdue (2)'));
      await tester.pumpAndSettle();
      expect(
        api.requestReads.lastWhere((r) => r['view'] == 'inbox')['overdue'],
        true,
      );
      await tester.enterText(find.byType(TextField), 'old ticket');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(
        api.requestReads.lastWhere((r) => r['view'] == 'inbox')['search'],
        'old ticket',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'direct old ticket lookup stays scoped and sends viewed status and revision',
    (tester) async {
      final api = _RecordsApi();
      await _mount(
        tester,
        const DocumentRequestsScreen(
          homeRoute: '/staff',
          initialRequestId: 501,
        ),
        api,
      );
      expect(
        api.requestReads.where((r) => r['id'] == 501).map((r) => r['view']),
        ['inbox', 'outbox'],
      );
      expect(find.text('Complete purpose for ticket 501'), findsOneWidget);
      await tester.tap(find.text('Accept request').last);
      await tester.pumpAndSettle();
      expect(api.decision, isNull);
      await tester.tap(
        find.widgetWithText(FilledButton, 'Accept request').last,
      );
      await tester.pumpAndSettle();
      expect(api.decision, {
        'id': 501,
        'action': 'approve',
        'status': 'pending',
        'revision': 'revision-501',
      });
    },
  );

  testWidgets(
    'office history pages complete dated log, not dashboard preview',
    (tester) async {
      final api = _RecordsApi();
      await _mount(tester, const StaffHistoryScreen(), api);
      expect(find.text('Tracking ID'), findsOneWidget);
      expect(find.text('All (55)'), findsNothing);
      await tester.tap(find.text('Office activity'));
      await tester.pumpAndSettle();
      expect(find.text('Tracking ID'), findsNothing);
      expect(find.text('Desk preview'), findsNothing);
      expect(find.text('All (55)'), findsOneWidget);
      expect(find.text('Received (30)'), findsOneWidget);
      expect(find.text('Sent (25)'), findsOneWidget);
      expect(find.text('PREVIEW-ONLY'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Next'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(api.activityReads.last['page'], 2);
      expect(find.text('DOC-2026-000002'), findsOneWidget);
      await tester.ensureVisible(find.text('Sent (25)'));
      await tester.tap(find.text('Sent (25)'));
      await tester.pumpAndSettle();
      expect(api.activityReads.last['page'], 1);
      expect(api.activityReads.last['status'], 'OUT');
      expect(
        api.activityReads.last['date'],
        matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'history load failure is unavailable rather than verified empty',
    (tester) async {
      final api = _RecordsApi()..failActivity = true;
      await _mount(
        tester,
        const StaffHistoryScreen(monitorOnly: true),
        api,
        role: 'head',
      );
      await tester.tap(find.text('Office activity'));
      await tester.pumpAndSettle();
      expect(find.text('Office activity unavailable'), findsOneWidget);
      expect(find.text('No office activity in this filter'), findsNothing);
      expect(find.text('Open Scanner'), findsNothing);
    },
  );
}
