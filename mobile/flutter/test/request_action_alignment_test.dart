import 'dart:async';
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
import 'package:smartflow/services/api_client.dart';
import 'package:smartflow/services/smartflow_api.dart';
import 'package:smartflow/theme/smartflow_theme.dart';

class _Fixture {
  _Fixture({
    this.status = 'pending',
    this.category = 'budget',
    this.outbox = false,
    this.linked = 'DOC-2026-000091',
  });

  String status;
  final String category;
  final bool outbox;
  final String? linked;
  String revision = 'reviewed-request-revision';
  String? exactRevision;
  Completer<http.Response>? pendingWrite;
  http.Response? updateFailure;
  final writes = <http.Request>[];
  final reads = <Map<String, String>>[];

  Map<String, dynamic> get request => {
    'id': 91,
    'request_code': 'REQ-2026-000091',
    'status': status,
    'revision': revision,
    'document_category': category,
    'purpose': 'Provide the complete supporting folder for the office review.',
    'required_by': '2026-10-25',
    if (linked != null) 'related_document_id': linked,
    'requester': {
      'user_id': outbox ? 102 : 201,
      'office_code': 'ENG',
      'office_name': 'Engineering Office',
    },
    'handler_office': {
      'office_id': 2,
      'office_code': 'BUD',
      'office_name': 'Budget Office',
    },
  };

  late final client = MockClient((request) async {
    switch (request.url.pathSegments.last) {
      case 'document-requests-list.php':
        final query = request.url.queryParameters;
        reads.add(query);
        final matches = query['view'] == (outbox ? 'outbox' : 'inbox');
        final row = {
          ...this.request,
          if (query['id'] != null && exactRevision != null)
            'revision': exactRevision,
        };
        return http.Response(
          jsonEncode({
            'requests': matches ? [row] : [],
            'total': matches ? 1 : 0,
            'page': 1,
            'page_size': 25,
            'counts': {
              'active': matches && ['pending', 'approved'].contains(status)
                  ? 1
                  : 0,
              'past': 0,
              'overdue': 0,
            },
          }),
          200,
        );
      case 'document-requests-update.php':
        writes.add(request);
        if (pendingWrite case final pending?) return pending.future;
        if (updateFailure case final failure?) return failure;
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        status = switch (body['action']) {
          'approve' => 'approved',
          'reject' => 'rejected',
          'cancel' => 'cancelled',
          _ => 'fulfilled',
        };
        return http.Response('{"success":true}', 200);
      default:
        throw StateError('Unexpected fixture endpoint: ${request.url.path}');
    }
  });

  Map<String, dynamic> get saved =>
      jsonDecode(writes.single.body) as Map<String, dynamic>;
}

class _Auth extends AuthProvider {
  _Auth(this.fixture);
  final _Fixture fixture;
  String currentToken = 'synthetic-original-login';
  bool endingSession = false;
  @override
  String get token => currentToken;
  @override
  bool get loggingOut => endingSession;
  @override
  AppUser get user => AppUser(
    id: currentToken == 'synthetic-original-login' ? 102 : 103,
    username: 'synthetic.reviewer',
    name: 'Synthetic reviewer',
    role: 'admin',
    officeId: 2,
    officeCode: 'BUD',
    officeName: 'Budget Office',
  );
  @override
  SmartflowApi get api =>
      SmartflowApi(ApiClient(token: token, client: fixture.client));

  void replaceLogin() {
    currentToken = 'synthetic-replacement-login';
    notifyListeners();
  }

  void setLogoutPending(bool pending) {
    endingSession = pending;
    notifyListeners();
  }
}

Future<_Auth> _mount(
  WidgetTester tester,
  _Fixture fixture, {
  Size size = const Size(600, 1100),
  double scale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetViewInsets);
  final auth = _Auth(fixture);
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const DocumentRequestsScreen(homeRoute: '/admin'),
      ),
    ],
  );
  addTearDown(auth.dispose);
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
  if (fixture.outbox) {
    await tester.tap(find.text('My requests'));
    await tester.pumpAndSettle();
  }
  return auth;
}

Finder _button(String label) => find.widgetWithText(FilledButton, label);
Finder _dialogButton(String label) =>
    find.descendant(of: find.byType(AlertDialog), matching: _button(label));
Finder get _notes => find.descendant(
  of: find.byType(AlertDialog),
  matching: find.byType(TextField),
);

Future<void> _open(WidgetTester tester, String label) async {
  final action = find.text(label).last;
  await tester.ensureVisible(action);
  await tester.pumpAndSettle();
  await tester.tap(action);
  await tester.pumpAndSettle();
  expect(find.byType(AlertDialog), findsOneWidget);
}

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('accept asks for confirmation and sends optional review notes', (
    tester,
  ) async {
    final fixture = _Fixture();
    await _mount(tester, fixture);
    await _open(tester, 'Accept request');
    expect(
      find.textContaining('does not receive, send or complete'),
      findsOneWidget,
    );
    expect(find.text('Review notes (optional)'), findsOneWidget);
    expect(fixture.writes, isEmpty);
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(fixture.writes, isEmpty);

    await _open(tester, 'Accept request');
    await tester.enterText(_notes, '  Include the full supporting annexes.  ');
    await tester.tap(_dialogButton('Accept request'));
    await tester.pumpAndSettle();
    expect(fixture.saved, {
      'request_id': 91,
      'action': 'approve',
      'expected_status': 'pending',
      'expected_revision': 'reviewed-request-revision',
      'review_notes': 'Include the full supporting annexes.',
    });
    expect(
      fixture.writes.single.headers['authorization'],
      'Bearer synthetic-original-login',
    );
    expect(find.textContaining('Accepted —'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'accept from exact details retains its reviewed revision and blank notes',
    (tester) async {
      final fixture = _Fixture()..exactRevision = 'exact-current-revision';
      await _mount(tester, fixture);
      await tester.tap(find.text(fixture.request['purpose'] as String));
      await tester.pumpAndSettle();
      expect(find.byType(RequestDetailsSheet), findsOneWidget);
      await _open(tester, 'Accept request');
      await tester.tap(_dialogButton('Accept request'));
      await tester.pumpAndSettle();
      expect(fixture.reads.any((read) => read['id'] == '91'), isTrue);
      expect(fixture.saved['expected_revision'], 'exact-current-revision');
      expect(fixture.saved.containsKey('review_notes'), isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  for (final status in ['pending', 'approved']) {
    testWidgets(
      'cancel $status ticket keeps custody separate and records optional notes',
      (tester) async {
        final fixture = _Fixture(status: status, outbox: true);
        await _mount(tester, fixture);
        await _open(tester, 'Cancel request');
        expect(find.textContaining('cannot be undone'), findsOneWidget);
        expect(
          find.textContaining('custody and history remain unchanged'),
          findsOneWidget,
        );
        expect(find.text('Cancellation notes (optional)'), findsOneWidget);
        await tester.tap(find.widgetWithText(TextButton, 'Keep request'));
        await tester.pumpAndSettle();
        expect(fixture.writes, isEmpty);
        await _open(tester, 'Cancel request');
        await tester.enterText(
          _notes,
          'The requested work is no longer needed.',
        );
        await tester.tap(_dialogButton('Cancel request'));
        await tester.pumpAndSettle();
        expect(fixture.saved, {
          'request_id': 91,
          'action': 'cancel',
          'expected_status': status,
          'expected_revision': 'reviewed-request-revision',
          'review_notes': 'The requested work is no longer needed.',
        });
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final disbursement in [false, true]) {
    testWidgets(
      '${disbursement ? 'payment release' : 'close'} has a named action and linked evidence',
      (tester) async {
        final fixture = _Fixture(
          status: 'approved',
          category: disbursement ? 'disbursement' : 'budget',
        );
        await _mount(tester, fixture);
        final label = disbursement ? 'Mark payment released' : 'Close request';
        await _open(tester, label);
        expect(
          find.textContaining(
            disbursement
                ? 'Treasury has actually released'
                : 'requested work is complete',
          ),
          findsOneWidget,
        );
        expect(find.text('Linked folder: DOC-2026-000091'), findsOneWidget);
        expect(find.text('Closing notes (optional)'), findsOneWidget);
        expect(find.text('OK'), findsNothing);
        expect(fixture.writes, isEmpty);
        await tester.enterText(
          _notes,
          'Actual outcome and supporting reference.',
        );
        await tester.tap(_dialogButton(label));
        await tester.pumpAndSettle();
        expect(fixture.saved, {
          'request_id': 91,
          'action': 'fulfill',
          'expected_status': 'approved',
          'expected_revision': 'reviewed-request-revision',
          'related_document_id': 'DOC-2026-000091',
          'review_notes': 'Actual outcome and supporting reference.',
        });
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'close without a folder offers the details linking cue and cancels without saving',
    (tester) async {
      final fixture = _Fixture(status: 'approved', linked: null);
      await _mount(tester, fixture);
      await _open(tester, 'Close request');
      expect(find.textContaining('No folder linked.'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(fixture.writes, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'decline requires a nonblank reason and preserves separate notice',
    (tester) async {
      final fixture = _Fixture();
      await _mount(tester, fixture);
      await _open(tester, 'Decline');
      expect(find.text('Decline notes (required)'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(_dialogButton('Decline request')).onPressed,
        isNull,
      );
      await tester.enterText(_notes, '   ');
      await tester.pump();
      expect(
        tester.widget<FilledButton>(_dialogButton('Decline request')).onPressed,
        isNull,
      );
      await tester.enterText(
        _notes,
        'Please provide the complete supporting requirements.',
      );
      await tester.pump();
      expect(
        tester.widget<FilledButton>(_dialogButton('Decline request')).onPressed,
        isNotNull,
      );
      await tester.tap(_dialogButton('Decline request'));
      await tester.pumpAndSettle();
      expect(
        fixture.saved['review_notes'],
        'Please provide the complete supporting requirements.',
      );
      expect(find.text('Separate notice required'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'OK'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('decision is reserved before awaiting the confirmation dialog', (
    tester,
  ) async {
    final fixture = _Fixture();
    await _mount(tester, fixture);
    final approve = tester
        .widget<FilledButton>(_button('Accept request'))
        .onPressed!;
    final reject = tester
        .widget<TextButton>(find.widgetWithText(TextButton, 'Decline'))
        .onPressed!;
    approve();
    approve();
    reject();
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(fixture.writes, isEmpty);
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<FilledButton>(_button('Accept request')).onPressed,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'retained row callback cannot open a decision for a replacement login',
    (tester) async {
      final fixture = _Fixture();
      final auth = await _mount(tester, fixture);
      final approve = tester
          .widget<FilledButton>(_button('Accept request'))
          .onPressed!;
      auth.replaceLogin();
      approve();
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(fixture.writes, isEmpty);
      await _open(tester, 'Accept request');
      await tester.tap(_dialogButton('Accept request'));
      await tester.pumpAndSettle();
      expect(fixture.writes.length, 1);
      expect(
        fixture.writes.single.headers['authorization'],
        'Bearer ${auth.token}',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('disposed request page ignores a retained decision callback', (
    tester,
  ) async {
    final fixture = _Fixture();
    await _mount(tester, fixture);
    final approve = tester
        .widget<FilledButton>(_button('Accept request'))
        .onPressed!;
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    approve();
    await tester.pump();
    expect(fixture.writes, isEmpty);
    expect(tester.takeException(), isNull);
  });

  for (final replacement in [false, true]) {
    testWidgets(
      '${replacement ? 'replacement login' : 'pending logout'} blocks a previously opened confirmation',
      (tester) async {
        final fixture = _Fixture();
        final auth = await _mount(tester, fixture);
        await _open(tester, 'Accept request');
        final confirm = tester
            .widget<FilledButton>(_dialogButton('Accept request'))
            .onPressed!;
        if (replacement) {
          auth.replaceLogin();
        } else {
          auth.setLogoutPending(true);
        }
        // Invoke the retained dialog callback before another frame can replace it.
        confirm();
        await tester.pumpAndSettle();
        expect(fixture.writes, isEmpty);
        auth.setLogoutPending(false);
        await tester.pumpAndSettle();
        await _open(tester, 'Accept request');
        await tester.tap(_dialogButton('Accept request'));
        await tester.pumpAndSettle();
        expect(fixture.writes.length, 1);
        expect(
          fixture.writes.single.headers['authorization'],
          'Bearer ${auth.token}',
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final success in [false, true]) {
    testWidgets(
      'dispatched ${success ? 'success' : 'failure'} settles while unchanged-login logout is pending',
      (tester) async {
        final fixture = _Fixture()..pendingWrite = Completer<http.Response>();
        final auth = await _mount(tester, fixture);
        await _open(tester, 'Accept request');
        await tester.tap(_dialogButton('Accept request'));
        await tester.pumpAndSettle();
        expect(fixture.writes.length, 1);
        auth.setLogoutPending(true);
        fixture.pendingWrite!.complete(
          success
              ? http.Response('{"success":true}', 200)
              : http.Response(
                  '{"message":"Synthetic request save unavailable"}',
                  503,
                ),
        );
        await tester.pumpAndSettle();
        expect(
          find.textContaining(
            success ? 'Accepted —' : 'Synthetic request save unavailable',
          ),
          findsOneWidget,
        );
        auth.setLogoutPending(false);
        await tester.pumpAndSettle();
        expect(
          tester.widget<FilledButton>(_button('Accept request')).onPressed,
          isNotNull,
        );
        expect(fixture.writes.length, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'conflict rereads exact details and never repeats the saved decision',
    (tester) async {
      final fixture = _Fixture()
        ..updateFailure = http.Response(
          '{"message":"This request changed"}',
          409,
        )
        ..exactRevision = 'changed-request-revision';
      await _mount(tester, fixture);
      await _open(tester, 'Accept request');
      await tester.tap(_dialogButton('Accept request'));
      await tester.pumpAndSettle();
      expect(fixture.writes.length, 1);
      expect(fixture.saved['expected_revision'], 'reviewed-request-revision');
      expect(find.byType(RequestDetailsSheet), findsOneWidget);
      expect(fixture.reads.any((read) => read['id'] == '91'), isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'payment dialog remains usable with long linked ID, enlarged text and keyboard',
    (tester) async {
      final fixture = _Fixture(
        status: 'approved',
        category: 'disbursement',
        linked: 'DOC-2026-000091-LONG-SYNTHETIC-REFERENCE',
      );
      await _mount(tester, fixture, size: const Size(320, 844), scale: 2);
      await _open(tester, 'Mark payment released');
      await tester.ensureVisible(_notes);
      await tester.tap(_notes);
      tester.view.viewInsets = FakeViewPadding(bottom: 280);
      await tester.pumpAndSettle();
      await tester.ensureVisible(_notes);
      await tester.enterText(
        _notes,
        'Actual release reviewed with the complete supporting reference.',
      );
      await tester.pumpAndSettle();
      expect(
        _dialogButton('Mark payment released').hitTestable(),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(TextButton, 'Cancel').hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.tap(_dialogButton('Mark payment released'));
      await tester.pumpAndSettle();
      expect(
        fixture.saved['review_notes'],
        'Actual release reviewed with the complete supporting reference.',
      );
      expect(tester.takeException(), isNull);
    },
  );
}
