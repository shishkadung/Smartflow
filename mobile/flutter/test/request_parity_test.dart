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
import 'package:smartflow/screens/admin/admin_shell.dart';
import 'package:smartflow/services/api_client.dart';
import 'package:smartflow/services/smartflow_api.dart';
import 'package:smartflow/theme/smartflow_theme.dart';
import 'package:smartflow/widgets/home_folder_actions.dart';

const _request = <String, dynamic>{
  'id': 91,
  'request_code': 'REQ-2026-000091',
  'status': 'approved',
  'document_category': 'budget',
  'purpose':
      'Provide the complete approved road repair budget, including all annexes and the supporting estimates, for the engineering review and next council meeting.',
  'required_by': '2026-10-20',
  'required_by_display': 'October 20, 2026',
  'created_at': '2026-10-10 08:00:00',
  'reviewed_at': '2026-10-11 09:00:00',
  'review_notes': 'Approved for the requested annexes.',
  'requester': {
    'id': 201,
    'name': 'Engineering clerk',
    'username': 'engineer',
    'office_name': 'Engineering Office',
    'office_code': 'ENG',
  },
  'handler_office': {
    'office_id': 2,
    'office_name': 'Budget Office',
    'office_code': 'BUD',
  },
};

class _Api extends SmartflowApi {
  _Api() : super(ApiClient());
  @override
  Future<Map<String, dynamic>> reportsRegister(Map<String, String> query) async =>
      {'documents': [], 'total': 0, 'total_pages': 0, 'page': 1};
  bool failExceptions = false;
  final changes = <(int, bool)>[];
  int listReads = 0;
  @override
  Future<Map<String, dynamic>> municipalDocuments({
    String? id,
    String? tray,
    String search = '',
    String sort = 'urgency',
    bool overdue = false,
    int? currentOfficeId,
    int? limit,
    int offset = 0,
  }) async => id == null
      ? await officeDocuments()
      : {
          'read_only': true,
          'document': {
            'id': id,
            'title': 'Municipal road budget',
            'type': 'Approved Budget',
            'tray': 'in_office',
            'current_status': 'IN',
            'current_office_name': 'Budget Office',
            'last_movement_id': 1,
            'qr_payload': id,
            'journey': <Map<String, dynamic>>[],
          },
        };
  @override
  Future<Map<String, dynamic>> usersList() async => {
    'users': [
      {
        'id': 102,
        'username': 'self.admin',
        'role': 'admin',
        'office_name': 'Accounting',
        'office_code': 'ACC',
        'is_active': true,
      },
      {
        'id': 103,
        'username': 'other.staff',
        'role': 'staff',
        'office_name': 'Engineering',
        'office_code': 'ENG',
        'is_active': changes.isEmpty,
      },
    ],
  };
  @override
  Future<Map<String, dynamic>> signupPending() async => {'pending': []};
  @override
  Future<Map<String, dynamic>> setUserActive(int id, bool active) async {
    changes.add((id, active));
    return {'success': true};
  }

  @override
  Future<Map<String, dynamic>> documentRequestsSummary() async => {
    'pending_inbox_count': 3,
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
  }) async {
    listReads++;
    return {
      'requests': view == 'inbox' ? [_request] : [],
      'pending_inbox_count': 0,
    };
  }

  @override
  Future<List<Map<String, dynamic>>> offices() async => [
    {'id': 2, 'code': 'BUD', 'name': 'Budget Office'},
  ];
  @override
  Future<Map<String, dynamic>> officeDocuments({String? id}) async => {
    'documents': [
      {
        'id': 'DOC-2026-000091',
        'title': 'Road budget',
        'type': 'Approved Budget',
        'reference_no': 'BUD-91',
      },
      {
        'id': 'DOC-2026-000092',
        'title': 'Road DV',
        'type': 'Disbursement Voucher',
        'reference_no': 'DV-92',
      },
    ],
  };
  @override
  Future<Map<String, dynamic>> reportsSummary(
    int officeId,
    String month,
  ) async => {
    'period': 'month',
    'month': month,
    'compliance': <String, dynamic>{},
    'totals': <String, dynamic>{},
    'office_totals': [],
  };
  @override
  Future<Map<String, dynamic>> auditExceptions({
    int hours = 24,
    Map<String, String> period = const {},
  }) async {
    if (failExceptions) throw ApiException('Cannot reach portal');
    return {'exceptions': []};
  }
}

class _Auth extends AuthProvider {
  _Auth(this.fixture, {this.role = 'admin', this.officeCode = 'ACC'});
  final _Api fixture;
  final String role;
  final String officeCode;
  @override
  SmartflowApi get api => fixture;
  @override
  AppUser get user => AppUser(
    id: 102,
    name: 'QA user',
    username: 'self.admin',
    role: role,
    officeId: officeCode == 'BUD' ? 2 : 4,
    officeName: '$officeCode Office',
    officeCode: officeCode,
  );
}

Future<void> _mount(
  WidgetTester tester,
  Widget child,
  _Api api, {
  String role = 'admin',
  String office = 'ACC',
  double scale = 1,
}) async {
  tester.view.physicalSize = const Size(320, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => Scaffold(body: child),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ChangeNotifierProvider<AuthProvider>(
      create: (_) => _Auth(api, role: role, officeCode: office),
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
  await tester.pump();
  await tester.pump();
}

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
  });
  test(
    'request linking, atomic registration and activation use backend contract',
    () async {
      final calls = <http.Request>[];
      final api = SmartflowApi(
        ApiClient(
          client: MockClient((r) async {
            calls.add(r);
            return http.Response('{"success":true}', 200);
          }),
        ),
      );
      await api.documentRequestUpdate(
        requestId: 91,
        action: 'link',
        relatedDocumentId: 'DOC-2026-000091',
      );
      await api.createDocument(
        title: 'Road budget',
        type: 'Approved Budget',
        originOfficeId: 2,
        requestId: 91,
      );
      await api.setUserActive(103, false);
      expect(jsonDecode(calls[0].body), {
        'request_id': 91,
        'action': 'link',
        'related_document_id': 'DOC-2026-000091',
      });
      expect(jsonDecode(calls[1].body)['request_id'], 91);
      expect(jsonDecode(calls[2].body), {'user_id': 103, 'active': false});
    },
  );
  testWidgets(
    'request detail keeps full purpose, reasons and guided actions at large text',
    (tester) async {
      await _mount(
        tester,
        const RequestDetailsSheet(
          request: _request,
          inbox: true,
          canLink: true,
          myOfficeCode: 'BUD',
        ),
        _Api(),
        role: 'staff',
        office: 'BUD',
        scale: 2,
      );
      expect(find.text(_request['purpose'] as String), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Approved for the requested annexes.'),
        300,
        scrollable: find
            .descendant(
              of: find.byType(ListView).first,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text('Approved for the requested annexes.'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Select existing folder'),
        300,
        scrollable: find
            .descendant(
              of: find.byType(ListView).first,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pump();
      expect(find.text('Register new physical folder'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'request history preserves distinct full review and payment evidence at enlarged text',
    (tester) async {
      final review =
          '${List.filled(30, 'Acceptance includes the complete supporting pages. ').join()}END OF REVIEW';
      final outcome =
          '${List.filled(30, 'Payment release was recorded with the supporting reference. ').join()}END OF RELEASE';
      await _mount(
        tester,
        SingleChildScrollView(
          child: RequestDecisionHistory(
            request: {
              ..._request,
              'status': 'fulfilled',
              'document_category': 'disbursement',
              'review_notes_kind': 'review',
              'review_notes': review,
              'reviewed_at': '2026-10-11 09:00:00',
              'reviewer': {
                'name': 'Initial reviewer',
                'office_name': 'Accounting Office',
              },
              'fulfilled_notes': outcome,
              'fulfilled_at': '2026-10-14 16:00:00',
              'fulfiller': {
                'name': 'Closing administrator',
                'office_name': 'Engineering Office',
              },
            },
          ),
        ),
        _Api(),
        scale: 2,
      );
      expect(find.text('Review'), findsOneWidget);
      expect(find.text('Payment release'), findsOneWidget);
      expect(find.text('Initial reviewer · Accounting Office'), findsOneWidget);
      expect(
        find.text('Closing administrator · Engineering Office'),
        findsOneWidget,
      );
      expect(find.text('2026-10-11 09:00:00'), findsOneWidget);
      expect(find.text('2026-10-14 16:00:00'), findsOneWidget);
      expect(find.text(review), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text(outcome),
        400,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 100,
      );
      expect(find.text(outcome), findsOneWidget);
      expect(
        tester
            .widget<SelectableText>(
              find.byWidgetPredicate(
                (w) => w is SelectableText && w.data == outcome,
              ),
            )
            .maxLines,
        isNull,
      );
      expect(find.text('Existing recorded notes'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'cancelled request preserves acceptance and cancellation actors notes and times separately',
    (tester) async {
      await _mount(
        tester,
        SingleChildScrollView(
          child: RequestDecisionHistory(
            request: {
              ..._request,
              'status': 'cancelled',
              'review_notes_kind': 'review',
              'reviewer': {
                'name': 'Initial reviewer',
                'office_name': 'Budget Office',
              },
              'cancelled_notes':
                  'Cancelled because the author withdrew the requested annexes.',
              'cancelled_at': '2026-10-14 16:00:00',
              'canceller': {'username': 'request.author', 'office_code': 'ENG'},
            },
          ),
        ),
        _Api(),
      );
      expect(find.text('Review'), findsOneWidget);
      expect(find.text('Cancellation'), findsOneWidget);
      expect(find.text('Approved for the requested annexes.'), findsOneWidget);
      expect(
        find.text(
          'Cancelled because the author withdrew the requested annexes.',
        ),
        findsOneWidget,
      );
      expect(find.text('Initial reviewer · Budget Office'), findsOneWidget);
      expect(find.text('@request.author · ENG'), findsOneWidget);
      expect(find.text('2026-10-11 09:00:00'), findsOneWidget);
      expect(find.text('2026-10-14 16:00:00'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  for (final status in ['fulfilled', 'cancelled']) {
    testWidgets(
      'legacy $status notes stay neutral and unknown actors offices and times are not guessed',
      (tester) async {
        await _mount(
          tester,
          SingleChildScrollView(
            child: RequestDecisionHistory(
              request: {
                ..._request,
                'status': status,
                'review_notes_kind': 'legacy',
                'review_notes':
                    'Older recorded notes whose original stage is unknown.',
                'reviewed_at': null,
                'reviewer': null,
                'fulfilled_notes': null,
                'fulfilled_at': null,
                'fulfiller': null,
                'cancelled_notes': null,
                'cancelled_at': null,
                'canceller': null,
              },
            ),
          ),
          _Api(),
        );
        expect(find.text('Existing recorded notes'), findsOneWidget);
        expect(
          find.text('Older recorded notes whose original stage is unknown.'),
          findsOneWidget,
        );
        expect(
          find.textContaining(
            'The notes and recorded metadata may refer to either stage.',
          ),
          findsOneWidget,
        );
        expect(
          find.text('Actor not recorded · Office not recorded'),
          findsOneWidget,
        );
        expect(find.text('Time not recorded'), findsOneWidget);
        expect(find.text('Review'), findsNothing);
        expect(find.text('Review notes'), findsNothing);
        expect(find.textContaining('QA user'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'legacy mixed reviewer metadata stays available without asserting an initial review',
    (tester) async {
      await _mount(
        tester,
        SingleChildScrollView(
          child: RequestDecisionHistory(
            request: {
              ..._request,
              'status': 'fulfilled',
              'review_notes_kind': 'legacy',
              'reviewer': {
                'name': 'Historical recorded actor',
                'office_name': null,
              },
              'fulfilled_notes': null,
              'fulfilled_at': null,
              'fulfiller': null,
            },
          ),
        ),
        _Api(),
      );
      expect(find.text('Existing recorded notes'), findsOneWidget);
      expect(
        find.text('Historical recorded actor · Office not recorded'),
        findsOneWidget,
      );
      expect(find.text('2026-10-11 09:00:00'), findsOneWidget);
      expect(find.text('Review'), findsNothing);
      expect(
        find.textContaining('recorded metadata may refer to either stage'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'new blank closing notes remain distinct from unknown legacy evidence',
    (tester) async {
      await _mount(
        tester,
        SingleChildScrollView(
          child: RequestDecisionHistory(
            request: {
              ..._request,
              'status': 'fulfilled',
              'review_notes_kind': 'review',
              'fulfilled_notes': '',
              'fulfilled_at': '2026-10-14 16:00:00',
              'fulfiller': {
                'name': 'Known closer',
                'office_name': null,
                'office_code': null,
              },
            },
          ),
        ),
        _Api(),
      );
      expect(find.text('Review'), findsOneWidget);
      expect(find.text('Closing'), findsOneWidget);
      expect(find.text('No notes added.'), findsOneWidget);
      expect(find.text('Known closer · Office not recorded'), findsOneWidget);
      expect(find.text('Existing recorded notes'), findsNothing);
      expect(
        find.textContaining('Separate outcome notes were not recorded'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Accounting staff cannot record DV payment release or register from Treasury queue',
    (tester) async {
      await _mount(
        tester,
        RequestDetailsSheet(
          request: {..._request, 'document_category': 'disbursement'},
          inbox: true,
          canLink: false,
          myOfficeCode: 'ACC',
        ),
        _Api(),
        role: 'staff',
      );
      expect(find.text('Select existing folder'), findsNothing);
      expect(find.text('Register new physical folder'), findsNothing);
      expect(find.text('Close request'), findsNothing);
      expect(find.text('Mark payment released'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'folder picker filters by category and searches real accessible folders',
    (tester) async {
      await _mount(
        tester,
        const RequestFolderPicker(request: _request),
        _Api(),
      );
      expect(find.text('Road budget'), findsOneWidget);
      expect(find.text('Road DV'), findsNothing);
      await tester.enterText(find.byType(TextField), 'missing');
      await tester.pump();
      expect(find.text('Road budget'), findsNothing);
      expect(
        find.textContaining('No matching accessible folders'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'user activation confirms before mutation and never offers self deactivation',
    (tester) async {
      final api = _Api();
      await _mount(tester, const AdminUsersScreen(), api);
      expect(find.text('Your account'), findsOneWidget);
      expect(find.text('Deactivate'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Deactivate'),
        200,
        scrollable: find
            .descendant(
              of: find.byType(ListView).first,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.text('Deactivate'));
      await tester.pumpAndSettle();
      expect(api.changes, isEmpty);
      await tester.tap(find.text('Deactivate account'));
      await tester.pumpAndSettle();
      expect(api.changes, [(103, false)]);
      expect(find.text('Activate'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('exception fetch failure never presents No exceptions', (
    tester,
  ) async {
    final api = _Api()..failExceptions = true;
    await _mount(tester, const AdminReportsScreen(), api);
    await tester.scrollUntilVisible(
      find.textContaining('Audit exceptions unavailable'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    expect(find.textContaining('No exceptions ·'), findsNothing);
    expect(find.text('Retry exceptions'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Home actions and pending count remain readable on a narrow phone',
    (tester) async {
      await _mount(
        tester,
        const HomeFolderActions(),
        _Api(),
        role: 'staff',
        scale: 2,
      );
      expect(find.text('Scan QR'), findsNothing);
      expect(find.text('Register folder'), findsOneWidget);
      expect(find.text('Requests'), findsOneWidget);
      expect(find.text('3 pending · 0 overdue'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Register folder')).dx,
        tester.getTopLeft(find.text('Requests')).dx,
      );
      expect(
        tester.getTopLeft(find.text('Register folder')).dy,
        greaterThan(tester.getTopLeft(find.text('Requests')).dy),
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'request refresh pauses under an open draft and resumes without losing it',
    (tester) async {
      final api = _Api();
      await _mount(
        tester,
        const DocumentRequestsScreen(homeRoute: '/admin'),
        api,
      );
      expect(api.listReads, 2);
      await tester.tap(find.text('New request'));
      await tester.pumpAndSettle();
      final purpose = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == 'Purpose',
      );
      await tester.scrollUntilVisible(
        purpose,
        200,
        scrollable: find
            .descendant(
              of: find.byType(ListView).last,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.enterText(purpose, 'Keep this unfinished request');
      await tester.pump(const Duration(seconds: 16));
      await tester.pump();
      expect(api.listReads, 2);
      expect(
        tester.widget<TextField>(purpose).controller!.text,
        'Keep this unfinished request',
      );
      Navigator.of(tester.element(purpose)).pop();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 16));
      await tester.pump();
      await tester.pump();
      expect(api.listReads, greaterThan(2));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('admin Home keeps request oversight without clerk shortcuts', (
    tester,
  ) async {
    await _mount(tester, const HomeFolderActions(), _Api());
    expect(find.text('Scan QR'), findsNothing);
    expect(find.text('Register folder'), findsNothing);
    expect(find.text('Requests'), findsOneWidget);
    expect(find.text('3 pending · 0 overdue'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'head Home keeps request oversight without physical registration',
    (tester) async {
      await _mount(
        tester,
        const HomeFolderActions(),
        _Api(),
        role: 'head',
        scale: 2,
      );
      expect(find.text('Register folder'), findsNothing);
      expect(find.text('Requests'), findsOneWidget);
      expect(find.text('3 pending · 0 overdue'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'municipal document detail displays custody without physical movement controls',
    (tester) async {
      await _mount(
        tester,
        const DocumentsScreen(
          municipal: true,
          initialDocumentId: 'DOC-2026-000091',
        ),
        _Api(),
      );
      expect(find.text('Municipal road budget'), findsOneWidget);
      expect(find.textContaining('Municipal oversight'), findsOneWidget);
      expect(find.text('Send (OUT)'), findsNothing);
      expect(find.text('Receive (IN)'), findsNothing);
      expect(find.text('Next: send this folder'), findsNothing);
      expect(find.text('Currently held by Budget Office.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
