import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartflow/models/user.dart';
import 'package:smartflow/providers/auth_provider.dart';
import 'package:smartflow/screens/shared/document_requests_screen.dart';
import 'package:smartflow/screens/shared/documents_screen.dart';
import 'package:smartflow/services/api_client.dart';
import 'package:smartflow/services/smartflow_api.dart';
import 'package:smartflow/theme/smartflow_theme.dart';
import 'package:smartflow/utils/document_types.dart';
import 'package:smartflow/utils/suggest_forward_office.dart';
import 'package:smartflow/widgets/mark_out_destination_dialog.dart';

Map<String, dynamic> ticket(int id, String status, String purpose) => {
  'id': id,
  'request_code': 'REQ-2026-$id',
  'status': status,
  'revision': 'revision-$id',
  'document_category': 'general',
  'purpose': purpose,
  'required_by': '2026-10-25',
  'requester': {'user_id': 21, 'office_code': 'BUD'},
  'handler_office': {'office_id': 3, 'office_code': 'ACC'},
};

class _Api extends SmartflowApi {
  _Api() : super(ApiClient());
  final reads = <Map<String, dynamic>>[];
  final creations = <Map<String, dynamic>>[];
  bool failList = false;
  bool failExact = false;
  bool failDocuments = false;
  bool recovery = false;
  int recoveryChecks = 0;

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
    reads.add({
      'view': view,
      'status': status,
      'search': search,
      'id': requestId,
      'page': page,
    });
    if (requestId != null) {
      if (failExact) throw ApiException('Exact ticket unavailable');
      return {
        'requests': [
          ticket(
            requestId,
            'pending',
            requestId == 102
                ? 'New exact audit ticket'
                : 'Previously active audit ticket',
          ),
        ],
      };
    }
    if (failList) throw ApiException('List unavailable');
    final rows = status == 'past'
        ? [ticket(100, 'fulfilled', 'Previously closed audit ticket')]
        : [ticket(101, 'pending', 'Previously active audit ticket')];
    return {
      'requests': rows,
      'page': page,
      'page_size': 25,
      'total': rows.length,
      'has_more': false,
      'pending_inbox_count': 1,
      'counts': {'total': 2, 'active': 1, 'past': 1, 'overdue': 0},
    };
  }

  @override
  Future<List<Map<String, dynamic>>> offices() async => [
    {'id': 1, 'code': 'ENG', 'name': 'Engineering Office'},
    {'id': 2, 'code': 'BUD', 'name': 'Budget Office'},
    {'id': 3, 'code': 'ACC', 'name': 'Accounting Office'},
    {'id': 4, 'code': 'TRE', 'name': 'Treasury Office'},
  ];

  @override
  Future<Map<String, dynamic>> documentRequestCreate({
    required String requestKind,
    required String documentCategory,
    required String purpose,
    required String requiredBy,
    int? targetOfficeId,
  }) async {
    creations.add({
      'kind': requestKind,
      'category': documentCategory,
      'target': targetOfficeId,
    });
    return {'request': ticket(102, 'pending', purpose)};
  }

  @override
  Future<Map<String, dynamic>?> pendingCreation(String kind) async => recovery
      ? {
          'id': 'a' * 32,
          'body': {'purpose': 'New exact audit ticket'},
        }
      : null;

  @override
  Future<Map<String, dynamic>?> checkCreation(String kind) async {
    recoveryChecks++;
    recovery = false;
    return {
      'state': 'recorded',
      'result': {'request': ticket(102, 'pending', 'New exact audit ticket')},
    };
  }

  @override
  Future<Map<String, dynamic>> officeDocumentPage({
    required String tray,
    String search = '',
    String sort = 'urgency',
    bool overdue = false,
    int limit = 50,
    int offset = 0,
  }) async {
    reads.add({
      'tray': tray,
      'search': search,
      'sort': sort,
      'offset': offset,
      'overdue': overdue,
    });
    if (failDocuments) throw ApiException('Document query unavailable');
    return {
      'documents': tray == 'completed' || search.isNotEmpty
          ? []
          : [
              {
                'id': 'DOC-2026-000101',
                'title': 'Incoming audit folder',
                'type': 'Others: Audit',
                'tray': 'incoming',
                'current_status': 'OUT',
                'current_office_name': 'Engineering Office',
                'destination_office_name': 'Budget Office',
                'hours_waiting': 2,
                'is_overdue': false,
              },
            ],
      'total': tray == 'completed' || search.isNotEmpty ? 0 : 1,
      'has_more': false,
      'tray_counts': {
        'incoming': 1,
        'in_office': 0,
        'forwarded': 0,
        'completed': 0,
      },
      'overdue_count': 0,
    };
  }

  @override
  Future<Map<String, dynamic>> documentMovements(String id) async => {
    'movements': [],
  };
}

class _Auth extends AuthProvider {
  _Auth(this.fixture);
  final _Api fixture;
  int accountId = 21;
  void changeAccount() {
    accountId++;
    notifyListeners();
  }

  @override
  SmartflowApi get api => fixture;
  @override
  AppUser get user => AppUser(
    id: accountId,
    username: 'audit.synthetic',
    name: 'Synthetic audit staff',
    role: 'staff',
    officeId: 2,
    officeCode: 'BUD',
    officeName: 'Budget Office',
  );
}

Finder field(String label) => find.byWidgetPredicate(
  (w) => w is TextField && w.decoration?.labelText == label,
);

Future<_Auth> _mount(WidgetTester tester, Widget screen, _Api api) async {
  final auth = _Auth(api);
  await _mountProvider(tester, screen, auth);
  addTearDown(auth.dispose);
  return auth;
}

Future<void> _mountProvider(
  WidgetTester tester,
  Widget screen,
  AuthProvider auth,
) async {
  tester.view.physicalSize = const Size(600, 1400);
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
  await tester.pumpAndSettle();
}

class _HttpFixture {
  final creations = <Map<String, dynamic>>[];
  final reads = <Map<String, dynamic>>[];
  late final client = MockClient((request) async {
    final endpoint = request.url.pathSegments.last;
    final query = request.url.queryParameters;
    reads.add({'endpoint': endpoint, ...query});
    Map<String, dynamic> result;
    switch (endpoint) {
      case 'auth-login.php':
        result = {
          'token': 'synthetic-test-session',
          'user': {
            'id': 21,
            'username': 'synthetic',
            'name': 'Synthetic staff',
            'role': 'staff',
            'office_id': 2,
            'office_code': 'BUD',
            'office_name': 'Budget Office',
          },
        };
      case 'auth-session.php':
        result = {};
      case 'document-requests-list.php':
        final id = int.tryParse(query['id'] ?? '');
        final rows = id != null
            ? [
                ticket(
                  id,
                  'pending',
                  id == 102
                      ? 'Real provider exact new ticket'
                      : 'Real provider active ticket',
                ),
              ]
            : query['status'] == 'past'
            ? [ticket(100, 'fulfilled', 'Real provider past ticket')]
            : [ticket(101, 'pending', 'Real provider active ticket')];
        result = {
          'requests': rows,
          'page': 1,
          'page_size': 25,
          'total': rows.length,
          'has_more': false,
          'pending_inbox_count': 1,
          'counts': {'total': 2, 'active': 1, 'past': 1, 'overdue': 0},
        };
      case 'offices-list.php':
        result = {
          'offices': [
            {'id': 2, 'code': 'BUD', 'name': 'Budget Office'},
            {'id': 3, 'code': 'ACC', 'name': 'Accounting Office'},
          ],
        };
      case 'document-requests-create.php':
        creations.add(jsonDecode(request.body) as Map<String, dynamic>);
        result = {
          'request': ticket(102, 'pending', 'Real provider exact new ticket'),
        };
      case 'office-documents.php':
        final document = {
          'id': 'DOC-2026-000101',
          'title': 'Real provider incoming folder',
          'type': 'Others: Audit',
          'tray': 'incoming',
          'current_status': 'OUT',
          'current_office_id': 1,
          'current_office_name': 'Engineering Office',
          'destination_office_id': 2,
          'destination_office_name': 'Budget Office',
          'last_movement_id': 7,
          'hours_waiting': 2,
          'is_overdue': false,
          'journey': <Map<String, dynamic>>[],
        };
        final empty =
            query['tray'] == 'completed' || (query['search'] ?? '').isNotEmpty;
        result = (query['id'] ?? '').isNotEmpty
            ? {'document': document, 'read_only': false}
            : {
                'documents': empty ? [] : [document],
                'total': empty ? 0 : 1,
                'has_more': false,
                'overdue_count': 0,
                'tray_counts': {
                  'incoming': 1,
                  'in_office': 0,
                  'forwarded': 0,
                  'completed': 0,
                },
              };
      default:
        throw StateError('Unexpected isolated endpoint: $endpoint');
    }
    return http.Response(jsonEncode({'success': true, ...result}), 200);
  });
}

Future<void> finish(WidgetTester tester) async {
  expect(tester.takeException(), isNull);
  await tester.pumpWidget(const SizedBox.shrink());
}

Future<void> chooseDocumentsView(WidgetTester tester, String label) async {
  final picker = find.byKey(const ValueKey('documents-view'));
  await tester.ensureVisible(picker);
  await tester.tap(picker);
  await tester.pump(const Duration(milliseconds: 100));
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'pull transport stores general regardless of a hidden prior category',
    () async {
      Map<String, dynamic>? body;
      final api = SmartflowApi(
        ApiClient(
          client: MockClient((request) async {
            body = jsonDecode(request.body) as Map<String, dynamic>;
            return http.Response('{"success":true}', 201);
          }),
        ),
      );
      await api.documentRequestCreate(
        requestKind: 'pull',
        documentCategory: 'budget',
        purpose: 'General request',
        requiredBy: '2026-10-25',
        targetOfficeId: 3,
      );
      expect(body?['document_category'], 'general');
    },
  );

  testWidgets(
    'real AuthProvider completes request reads, new general creation and exact reveal',
    (tester) async {
      final fixture = _HttpFixture();
      final auth = AuthProvider(httpClient: fixture.client);
      await auth.login('synthetic', 'synthetic-password');
      expect(identical(auth.api, auth.api), isFalse);
      await _mountProvider(
        tester,
        const DocumentRequestsScreen(homeRoute: '/staff'),
        auth,
      );
      expect(find.text('Real provider active ticket'), findsOneWidget);
      await tester.tap(find.text('Past (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Real provider past ticket'), findsOneWidget);
      await tester.tap(find.text('New request'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('From office'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send request to office'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Accounting Office (ACC)').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        field('Purpose'),
        'Real provider exact new ticket',
      );
      await tester.ensureVisible(find.text('Submit request'));
      await tester.tap(find.text('Submit request'));
      await tester.pumpAndSettle();
      expect(fixture.creations.single['document_category'], 'general');
      expect(find.byType(RequestDetailsSheet), findsOneWidget);
      expect(find.text('Real provider exact new ticket'), findsOneWidget);
      expect(fixture.reads.last, containsPair('id', '102'));
      expect(await auth.api.pendingCreation('request'), isNull);
      Navigator.of(tester.element(find.byType(RequestDetailsSheet))).pop();
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilterChip>(find.widgetWithText(FilterChip, 'Past (1)'))
            .selected,
        isTrue,
      );
      auth.dispose();
      await finish(tester);
    },
  );

  testWidgets(
    'real AuthProvider completes Documents initial, changed-query and exact-detail reads',
    (tester) async {
      final fixture = _HttpFixture();
      final auth = AuthProvider(httpClient: fixture.client);
      await auth.login('synthetic', 'synthetic-password');
      expect(identical(auth.api, auth.api), isFalse);
      await _mountProvider(tester, const DocumentsScreen(), auth);
      expect(find.text('Real provider incoming folder'), findsOneWidget);
      await chooseDocumentsView(tester, 'Completed');
      expect(find.text('0 documents'), findsOneWidget);
      await chooseDocumentsView(tester, 'Incoming (1)');
      await tester.enterText(
        field('Search ID, title or reference'),
        'specific query',
      );
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pumpAndSettle();
      expect(find.text('No matching documents'), findsOneWidget);
      await tester.enterText(field('Search ID, title or reference'), '');
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Real provider incoming folder'));
      await tester.pumpAndSettle();
      expect(find.text('Receive (IN)'), findsOneWidget);
      expect(
        find.textContaining('Current custody is unverified'),
        findsNothing,
      );
      expect(fixture.reads.last, containsPair('id', 'DOC-2026-000101'));
      auth.dispose();
      await finish(tester);
    },
  );

  testWidgets(
    'failed changed request search hides previous rows/counts and offers Retry',
    (tester) async {
      final api = _Api();
      await _mount(
        tester,
        const DocumentRequestsScreen(homeRoute: '/staff'),
        api,
      );
      expect(find.text('Previously active audit ticket'), findsOneWidget);
      api.failList = true;
      await tester.enterText(
        field('Search requests'),
        'different committed query',
      );
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(find.text('Previously active audit ticket'), findsNothing);
      expect(find.text('Active (1)'), findsNothing);
      expect(find.text('Accept request'), findsNothing);
      expect(find.text('Try again'), findsOneWidget);
      expect(find.text('No requests in this filter'), findsNothing);
      api.failList = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(api.reads.last['search'], 'different committed query');
      expect(find.text('Previously active audit ticket'), findsOneWidget);
      await finish(tester);
    },
  );

  testWidgets(
    'same-query request failure retains stale rows with disabled decisions',
    (tester) async {
      final api = _Api();
      await _mount(
        tester,
        const DocumentRequestsScreen(homeRoute: '/staff'),
        api,
      );
      api.failList = true;
      await tester.pump(const Duration(seconds: 16));
      await tester.pumpAndSettle();
      expect(find.text('Previously active audit ticket'), findsOneWidget);
      expect(
        find.textContaining('Showing the last loaded requests'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Accept request'),
            )
            .onPressed,
        isNull,
      );
      api.failList = false;
      await tester.pump(const Duration(seconds: 16));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Accept request'),
            )
            .onPressed,
        isNotNull,
      );
      await finish(tester);
    },
  );

  testWidgets(
    'failed exact ticket read cannot be repaired by list refresh alone',
    (tester) async {
      final api = _Api();
      await _mount(
        tester,
        const DocumentRequestsScreen(homeRoute: '/staff'),
        api,
      );
      api.failExact = true;
      await tester.tap(find.text('Previously active audit ticket'));
      await tester.pumpAndSettle();
      expect(find.text('Retry request'), findsOneWidget);
      expect(find.byType(RequestDetailsSheet), findsNothing);
      await tester.pump(const Duration(seconds: 16));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Accept request'),
            )
            .onPressed,
        isNull,
      );
      api.failExact = false;
      await tester.tap(find.text('Retry request'));
      await tester.pumpAndSettle();
      expect(find.byType(RequestDetailsSheet), findsOneWidget);
      expect(api.reads.last['id'], 101);
      await finish(tester);
    },
  );

  testWidgets(
    'new From office request reveals exact ticket and preserves Past view',
    (tester) async {
      final api = _Api();
      await _mount(
        tester,
        const DocumentRequestsScreen(homeRoute: '/staff'),
        api,
      );
      await tester.tap(find.text('Past (1)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New request'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('From office'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send request to office'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Accounting Office (ACC)').last);
      await tester.pumpAndSettle();
      await tester.enterText(field('Purpose'), 'New exact audit ticket');
      await tester.ensureVisible(find.text('Submit request'));
      await tester.tap(find.text('Submit request'));
      await tester.pumpAndSettle();
      expect(api.creations.single, {
        'kind': 'pull',
        'category': 'general',
        'target': 3,
      });
      expect(find.byType(RequestDetailsSheet), findsOneWidget);
      expect(find.text('New exact audit ticket'), findsOneWidget);
      expect(api.reads.last['id'], 102);
      Navigator.of(tester.element(find.byType(RequestDetailsSheet))).pop();
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilterChip>(find.widgetWithText(FilterChip, 'Past (1)'))
            .selected,
        isTrue,
      );
      expect(find.text('Previously closed audit ticket'), findsOneWidget);
      await finish(tester);
    },
  );

  testWidgets(
    'saved creation recovery reveals its exact ticket under an old search',
    (tester) async {
      final api = _Api()..recovery = true;
      await _mount(
        tester,
        const DocumentRequestsScreen(homeRoute: '/staff'),
        api,
      );
      await tester.enterText(
        field('Search requests'),
        'older unrelated search',
      );
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      await tester.tap(find.text('New request'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Check previous submission'));
      await tester.pumpAndSettle();
      expect(api.recoveryChecks, 1);
      expect(api.creations, isEmpty);
      expect(find.byType(RequestDetailsSheet), findsOneWidget);
      expect(find.text('New exact audit ticket'), findsOneWidget);
      expect(api.reads.last['id'], 102);
      Navigator.of(tester.element(find.byType(RequestDetailsSheet))).pop();
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(field('Search requests')).controller?.text,
        'older unrelated search',
      );
      await finish(tester);
    },
  );

  testWidgets(
    'failed changed Documents tray clears previous rows, counts and update time',
    (tester) async {
      final api = _Api();
      await _mount(tester, const DocumentsScreen(), api);
      expect(find.text('Incoming audit folder'), findsOneWidget);
      api.failDocuments = true;
      await chooseDocumentsView(tester, 'Completed');
      expect(
        tester
            .widget<DropdownButton<String>>(
              find.byKey(const ValueKey('documents-view')),
            )
            .value,
        'completed',
      );
      expect(find.text('Completed (—)'), findsOneWidget);
      expect(find.text('Incoming audit folder'), findsNothing);
      expect(find.textContaining('Updated '), findsNothing);
      expect(find.text('0 documents'), findsNothing);
      expect(find.text('Document count unavailable'), findsOneWidget);
      expect(find.textContaining('Documents unavailable.'), findsOneWidget);
      api.failDocuments = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('0 documents'), findsOneWidget);
      expect(find.text('No documents in this tray.'), findsOneWidget);
      await finish(tester);
    },
  );

  testWidgets(
    'Documents same-query failed refresh retains explicitly stale records',
    (tester) async {
      final api = _Api();
      await _mount(tester, const DocumentsScreen(), api);
      api.failDocuments = true;
      await tester.tap(find.byTooltip('Refresh'));
      await tester.pumpAndSettle();
      expect(find.text('Incoming audit folder'), findsOneWidget);
      expect(find.textContaining('Last successful update'), findsOneWidget);
      expect(
        find.textContaining('Previously loaded data may be stale'),
        findsOneWidget,
      );
      await finish(tester);
    },
  );

  testWidgets(
    'Documents committed search survives changed-query failure and Retry',
    (tester) async {
      final api = _Api();
      await _mount(tester, const DocumentsScreen(), api);
      api.failDocuments = true;
      await tester.enterText(
        field('Search ID, title or reference'),
        'new folder query',
      );
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pumpAndSettle();
      expect(find.text('Incoming audit folder'), findsNothing);
      expect(
        tester
            .widget<TextField>(field('Search ID, title or reference'))
            .controller
            ?.text,
        'new folder query',
      );
      api.failDocuments = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(api.reads.last['search'], 'new folder query');
      expect(find.text('No matching documents'), findsOneWidget);
      await finish(tester);
    },
  );

  testWidgets(
    'changed account cannot retain the former account Documents results',
    (tester) async {
      final api = _Api();
      final auth = await _mount(tester, const DocumentsScreen(), api);
      api.failDocuments = true;
      auth.changeAccount();
      await tester.pumpAndSettle();
      expect(find.text('Incoming audit folder'), findsNothing);
      expect(find.textContaining('Documents unavailable.'), findsOneWidget);
      expect(find.textContaining('Updated '), findsNothing);
      await finish(tester);
    },
  );

  testWidgets(
    'choosing a tray commits the visible Documents search before its debounce',
    (tester) async {
      final api = _Api();
      await _mount(tester, const DocumentsScreen(), api);
      await tester.enterText(
        field('Search ID, title or reference'),
        'typed before tray change',
      );
      await chooseDocumentsView(tester, 'Completed');
      expect(api.reads.last['search'], 'typed before tray change');
      expect(api.reads.last['tray'], 'completed');
      await finish(tester);
    },
  );

  test(
    'named Others folders override financial words without changing legacy hints',
    () {
      for (final type in [
        'Others: Voucher records',
        ' Others: Approved budget reference ',
        'oThErS: Disbursement evidence',
      ]) {
        expect(isOtherDocumentType(type), isTrue);
        expect(isDisbursementDocumentType(type), isFalse);
        expect(isApprovedBudgetDocumentType(type), isFalse);
        expect(
          suggestForwardOffice(documentType: type, fromOfficeCode: 'ACC'),
          isNull,
        );
      }
      expect(
        suggestForwardOffice(
          documentType: 'Disbursement Voucher',
          fromOfficeCode: 'ACC',
        )?.officeCode,
        'TRE',
      );
      expect(
        suggestForwardOffice(
          documentType: 'Approved Budget',
          fromOfficeCode: 'BUD',
        )?.officeCode,
        'ACC',
      );
    },
  );

  testWidgets(
    'named Others does not show a DV payment route in the send dialog',
    (tester) async {
      final api = _Api();
      await _mount(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showMarkOutDestinationDialog(
              context,
              documentId: 'DOC-2026-000101',
              myOfficeId: 3,
              myOfficeName: 'Accounting Office',
              myOfficeCode: 'ACC',
              documentType: 'Others: Disbursement voucher records',
            ),
            child: const Text('Open send dialog'),
          ),
        ),
        api,
      );
      await tester.tap(find.text('Open send dialog'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Usual next stop is Treasury'), findsNothing);
      expect(
        find.textContaining('After Accounting, the folder goes to Treasury'),
        findsNothing,
      );
      await finish(tester);
    },
  );
}
