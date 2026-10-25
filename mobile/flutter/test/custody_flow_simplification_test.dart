import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:smartflow/models/user.dart';
import 'package:smartflow/providers/auth_provider.dart';
import 'package:smartflow/screens/shared/document_requests_screen.dart';
import 'package:smartflow/screens/shared/documents_screen.dart';
import 'package:smartflow/services/api_client.dart';
import 'package:smartflow/services/smartflow_api.dart';
import 'package:smartflow/theme/smartflow_theme.dart';

const _id = 'DOC-2026-000091';
const _incoming = <String, dynamic>{
  'id': _id,
  'title': 'Road repair evidence',
  'type': 'Others: Evidence',
  'tray': 'incoming',
  'current_status': 'OUT',
  'current_office_id': 2,
  'current_office_name': 'Budget Office',
  'origin_office_name': 'Budget Office',
  'destination_office_id': 1,
  'destination_office_name': 'Engineering Office',
  'last_movement_id': 6,
  'journey': <Map<String, dynamic>>[],
  'folder_inventory': {
    'total_pages': 5,
    'items': [
      {'id': 'main', 'name': 'Main document', 'pages': 5, 'required': true},
    ],
  },
};
const _request = <String, dynamic>{
  'id': 91,
  'request_code': 'REQ-2026-000091',
  'status': 'approved',
  'revision': 'before',
  'document_category': 'other',
  'purpose': 'Road repair evidence for review',
  'related_document_id': _id,
  'required_by': '2026-10-01',
  'is_overdue': true,
  'review_notes': 'Original review notes',
  'requester': {
    'id': 1,
    'name': 'Engineering staff',
    'username': 'fixture',
    'office_name': 'Engineering Office',
    'office_code': 'ENG',
  },
  'handler_office': {
    'office_id': 2,
    'office_name': 'Budget Office',
    'office_code': 'BUD',
  },
};

class _Fixture {
  Map<String, dynamic> document = Map.from(_incoming);
  Map<String, dynamic> request = Map.from(_request);
  final writes = <Map<String, dynamic>>[];
  final reads = <Map<String, String>>[];
  late final api = SmartflowApi(ApiClient(client: MockClient(_respond)));

  Future<http.Response> _respond(http.Request req) async {
    final query = req.url.queryParameters;
    var data = <String, dynamic>{};
    switch (req.url.pathSegments.last) {
      case 'office-documents.php':
        data = {'document': document};
      case 'documents-show.php':
        data = {'document': document};
      case 'offices-list.php':
        data = {
          'offices': [
            {'id': 1, 'name': 'Engineering Office', 'code': 'ENG'},
            {'id': 2, 'name': 'Budget Office', 'code': 'BUD'},
            {'id': 3, 'name': 'Accounting Office', 'code': 'ACC'},
          ],
        };
      case 'movements-create.php':
        writes.add(jsonDecode(req.body) as Map<String, dynamic>);
        data = {'message': 'Handoff recorded'};
      case 'document-requests-list.php':
        reads.add(Map.from(query));
        final page = int.parse(query['page'] ?? '1');
        data = {
          'requests': query['view'] == 'outbox' ? [request] : [],
          'pending_inbox_count': 0,
          'counts': {'total': 51, 'pending': 0, 'overdue': 51},
          'total': 51,
          'page': page,
          'page_size': 25,
          'has_more': page < 3,
        };
    }
    return http.Response(jsonEncode({'success': true, ...data}), 200);
  }
}

class _Auth extends AuthProvider {
  _Auth(this.fixture);
  final _Fixture fixture;
  @override
  SmartflowApi get api => fixture.api;
  @override
  AppUser get user => const AppUser(
    id: 1,
    name: 'Engineering staff',
    username: 'fixture',
    role: 'staff',
    officeId: 1,
    officeName: 'Engineering Office',
    officeCode: 'ENG',
  );
}

Finder _field(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

// The protected action remains busy while its review dialog is open.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump();
}

Future<void> _mount(WidgetTester tester, _Fixture fixture, Widget child) async {
  tester.view.physicalSize = const Size(390, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ChangeNotifierProvider<AuthProvider>(
      create: (_) => _Auth(fixture),
      child: MaterialApp(
        theme: buildSmartflowTheme(),
        home: Scaffold(body: child),
      ),
    ),
  );
  await _settle(tester);
}

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets(
    'Documents receives through one confirmation; cancel never writes',
    (tester) async {
      final fixture = _Fixture();
      await _mount(
        tester,
        fixture,
        const DocumentsScreen(initialDocumentId: _id),
      );
      expect(find.byType(CheckboxListTile), findsNothing);
      expect(find.text('Back to request'), findsNothing);
      expect(find.text('Back to documents'), findsOneWidget);
      await tester.ensureVisible(find.text('Receive (IN)'));
      await tester.tap(find.text('Receive (IN)'));
      await _settle(tester);
      expect(find.byType(CheckboxListTile), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Receive with discrepancy'),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('Cancel'));
      await _settle(tester);
      expect(fixture.writes, isEmpty);
      await tester.tap(find.text('Receive (IN)'));
      await _settle(tester);
      await tester.enterText(_field('Main document — received pages'), '5');
      await tester.tap(find.byType(CheckboxListTile));
      await _settle(tester);
      await tester.tap(find.text('Confirm receipt'));
      await _settle(tester);
      expect(fixture.writes, hasLength(1));
      expect(fixture.writes.single['status'], 'IN');
      expect(fixture.writes.single['movement_source'], 'system');
      expect(fixture.writes.single['expected_movement_id'], 6);
      expect(fixture.writes.single['receipt_confirmed'], isTrue);
      expect(fixture.writes.single['contents_receipt']['items'], [
        {'id': 'main', 'pages': 5},
      ]);
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Documents send dialog retains suggestion and previous-holder return reason',
    (tester) async {
      final fixture = _Fixture();
      fixture.document = {
        ..._incoming,
        'tray': 'in_office',
        'current_status': 'IN',
        'current_office_id': 1,
        'current_office_name': 'Engineering Office',
        'visited_office_codes': ['ENG', 'BUD'],
        'suggested_forward': {
          'office_id': 3,
          'office_code': 'ACC',
          'office_name': 'Accounting Office',
          'reason': 'For review',
        },
      };
      await _mount(
        tester,
        fixture,
        const DocumentsScreen(initialDocumentId: _id),
      );
      await tester.ensureVisible(find.text('Send (OUT)'));
      await tester.tap(find.text('Send (OUT)'));
      await _settle(tester);
      expect(find.text('Suggested: ACC — Accounting Office'), findsOneWidget);
      await tester.tap(find.byType(SwitchListTile));
      await _settle(tester);
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Accounting Office'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Budget Office'),
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Return (OUT)'),
            )
            .onPressed,
        isNull,
      );
      await tester.enterText(
        _field('Reason for return'),
        'Missing signed annex',
      );
      await _settle(tester);
      await tester.tap(find.text('Return (OUT)'));
      await _settle(tester);
      expect(fixture.writes.single['destination_office_id'], 2);
      expect(fixture.writes.single['is_return'], isTrue);
      expect(fixture.writes.single['remarks'], 'Missing signed annex');
      expect(fixture.writes.single['expected_movement_id'], 6);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'completed Treasury folder only offers Accounting in the shared send dialog',
    (tester) async {
      final fixture = _Fixture();
      fixture.document = {
        ..._incoming,
        'tray': 'completed',
        'current_status': 'IN',
        'current_office_id': 1,
        'current_office_name': 'Engineering Office',
        'can_return_to_accounting': true,
      };
      await _mount(
        tester,
        fixture,
        const DocumentsScreen(initialDocumentId: _id),
      );
      await tester.ensureVisible(find.text('Return to Accounting (OUT)'));
      await tester.tap(find.text('Return to Accounting (OUT)'));
      await _settle(tester);
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Accounting Office'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Budget Office'),
        ),
        findsNothing,
      );
      await tester.tap(find.text('Cancel'));
      await _settle(tester);
      expect(fixture.writes, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Back to request restores My requests, overdue/search/page and freshly selected detail',
    (tester) async {
      final fixture = _Fixture();
      final router = GoRouter(
        initialLocation: '/staff/requests',
        routes: [
          GoRoute(
            path: '/staff/requests',
            builder: (_, _) =>
                const DocumentRequestsScreen(homeRoute: '/staff'),
          ),
          GoRoute(
            path: '/staff/documents',
            builder: (_, state) => Scaffold(
              body: DocumentsScreen(
                initialDocumentId: state.uri.queryParameters['id'],
                fromRequest: (state.extra as Map?)?['fromRequest'] == true,
              ),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      tester.view.physicalSize = const Size(390, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => _Auth(fixture),
          child: MaterialApp.router(
            theme: buildSmartflowTheme(),
            routerConfig: router,
          ),
        ),
      );
      await _settle(tester);
      await tester.tap(find.text('My requests'));
      await _settle(tester);
      await tester.ensureVisible(find.text('Overdue (51)'));
      await tester.tap(find.text('Overdue (51)'));
      await _settle(tester);
      await tester.enterText(_field('Search requests'), 'road');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await _settle(tester);
      await tester.ensureVisible(find.text('Next'));
      await tester.tap(find.text('Next'));
      await _settle(tester);
      expect(find.text('Page 2 of 3'), findsOneWidget);
      final state = tester.state(find.byType(DocumentRequestsScreen));
      await tester.tap(find.text('REQ-2026-000091'));
      await _settle(tester);
      await tester.ensureVisible(find.text('Open linked folder in Documents'));
      await tester.tap(find.text('Open linked folder in Documents'));
      await _settle(tester);
      expect(find.text('Back to request'), findsOneWidget);
      expect(find.text('Road repair evidence'), findsOneWidget);
      fixture.request = {
        ...fixture.request,
        'revision': 'after',
        'review_notes': 'Updated while viewing folder',
      };
      await tester.tap(find.text('Back to request'));
      await _settle(tester);
      expect(tester.state(find.byType(DocumentRequestsScreen)), same(state));
      expect(find.byType(RequestDetailsSheet), findsOneWidget);
      expect(find.text('Updated while viewing folder'), findsOneWidget);
      expect(find.text('Original review notes'), findsNothing);
      expect(fixture.reads.last, containsPair('id', '91'));
      expect(fixture.reads.last, containsPair('view', 'outbox'));
      await tester.tap(find.byTooltip('Close details'));
      await _settle(tester);
      expect(find.text('Page 2 of 3'), findsOneWidget);
      await tester.drag(find.byType(NestedScrollView), const Offset(0, 800));
      await _settle(tester);
      expect(
        tester.widget<TextField>(_field('Search requests')).controller!.text,
        'road',
      );
      final viewRead = fixture.reads.lastWhere(
        (read) => read['view'] == 'outbox' && read['id'] == null,
      );
      expect(viewRead, containsPair('page', '2'));
      expect(viewRead, containsPair('overdue', '1'));
      expect(viewRead, containsPair('q', 'road'));
      expect(fixture.writes, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
