import 'dart:async';

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
import 'package:smartflow/services/api_client.dart';
import 'package:smartflow/services/smartflow_api.dart';
import 'package:smartflow/theme/smartflow_theme.dart';

// The phone System page checks the same things as the web one: server health, counts and the password-reset email channel
// (same cases as web/test/email-channel.test.mjs), and it says so when it could not re-check them.

const _live = {
  'mode': 'live',
  'configured': true,
  'ready_for_real_delivery': true,
  'sender_domain': 'verified.example',
  'problems': [],
  'last_attempt': null,
};

Map<String, dynamic> _status({Map<String, dynamic> email = _live}) => {
  'status': {
    'api': 'On (PHP)',
    'php_version': 'PHP 8.2',
    'mysql_version': 'MariaDB 10.4',
    'documents': 211,
  },
  'operations': {
    'movements_today': 7,
    'pending_signups': 2,
    'flagged_total': 3,
  },
  'users': {'active': 12},
  'role_counts': {'staff': 6, 'head': 4, 'admin': 2},
  'email': email,
};

class _Api extends SmartflowApi {
  _Api() : super(ApiClient());
  bool failStatus = false;
  Map<String, dynamic> email = _live;
  Completer<Map<String, dynamic>>? pendingStatus;
  Completer<Map<String, dynamic>>? pendingTest;
  Object? testFailure;
  Map<String, dynamic> testResult = {
    'accepted': true,
    'message':
        'The mail provider accepted a test message for o***@x.test. Check that inbox.',
    'email': {
      ..._live,
      'last_attempt': {
        'at': '2026-10-26 09:00:00',
        'purpose': 'test',
        'accepted': true,
        'http': 202,
      },
    },
  };
  int statusReads = 0;
  int testCalls = 0;

  @override
  Future<Map<String, dynamic>> systemStatus() {
    statusReads++;
    if (pendingStatus != null) return pendingStatus!.future;
    if (failStatus) throw ApiException('Sample status read failure');
    return Future.value(_status(email: email));
  }

  @override
  Future<Map<String, dynamic>> systemEmailTest() {
    testCalls++;
    if (pendingTest != null) return pendingTest!.future;
    if (testFailure != null) throw testFailure!;
    return Future.value(testResult);
  }
}

class _Auth extends AuthProvider {
  _Auth(this.fixture);
  final _Api fixture;
  @override
  SmartflowApi get api => fixture;
  @override
  bool get isAuthenticated => true;
  @override
  AppUser get user => const AppUser(
    id: 101,
    name: 'System reviewer',
    username: 'system.reviewer',
    role: 'admin',
    officeId: 4,
    officeName: 'Accounting Office',
    officeCode: 'ACC',
  );
}

Future<void> _mount(
  WidgetTester tester,
  _Api api, {
  double width = 390,
  double height = 3200,
  double scale = 1,
  bool settle = true,
}) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final auth = _Auth(api);
  addTearDown(auth.dispose);
  final router = GoRouter(
    initialLocation: '/admin/system',
    routes: [
      GoRoute(
        path: '/admin/system',
        builder: (_, _) => const Scaffold(body: AdminSystemScreen()),
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
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _refresh(WidgetTester tester) async {
  await tester
      .widget<RefreshIndicator>(find.byType(RefreshIndicator))
      .onRefresh();
  await tester.pumpAndSettle();
}

Widget _card(
  Map? email, {
  bool stale = false,
  bool testing = false,
  Map? result,
  String error = '',
}) => MaterialApp(
  home: Scaffold(
    body: SingleChildScrollView(
      child: SfEmailChannelCard(
        email: email,
        stale: stale,
        testing: testing,
        result: result,
        testError: error,
        onTest: () {},
      ),
    ),
  ),
);

void main() {
  group('the email card (same cases as the web)', () {
    testWidgets(
      'it reports the exact problem of a sandbox address that the provider rejects',
      (tester) async {
        await tester.pumpWidget(
          _card({
            'mode': 'sandbox',
            'configured': true,
            'ready_for_real_delivery': false,
            'sender_domain': 'urbiztondo.gov.ph',
            'problems': [
              'Sandbox mode captures messages in a test inbox; they never reach real recipients.',
              'The sandbox address has no inbox number, so the provider rejects every request (HTTP 404).',
            ],
            'last_attempt': {
              'at': '2026-10-19 11:30:03',
              'purpose': 'password_reset',
              'accepted': false,
              'http': 404,
            },
          }),
        );
        expect(find.text('Last attempt failed'), findsOneWidget);
        expect(
          find.text(
            'Sandbox (test inbox only) · sender domain urbiztondo.gov.ph',
          ),
          findsOneWidget,
        );
        expect(
          find.textContaining('never reach real recipients'),
          findsOneWidget,
        );
        expect(
          find.textContaining('rejects every request (HTTP 404)'),
          findsOneWidget,
        );
        expect(
          find.text(
            'Last attempt (password reset): rejected (HTTP 404) · 2026-10-19 11:30:03',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'it distinguishes ready, not configured, unverified and no-history states',
      (tester) async {
        await tester.pumpWidget(_card(_live));
        expect(find.text('Ready'), findsOneWidget);
        expect(
          find.text('No email has been sent since this check was added.'),
          findsOneWidget,
        );
        await tester.pumpWidget(
          _card({
            ..._live,
            'configured': false,
            'mode': 'not_configured',
            'ready_for_real_delivery': false,
            'problems': [
              'No sending token is configured, so no email can be sent.',
            ],
          }),
        );
        expect(find.text('Not configured'), findsWidgets);
        expect(
          find.textContaining('No sending token is configured'),
          findsOneWidget,
        );
        await tester.pumpWidget(
          _card({
            ..._live,
            'last_attempt': {
              'at': '2026-10-19 12:00:00',
              'purpose': 'test',
              'accepted': true,
              'http': 202,
            },
          }),
        );
        expect(
          find.text(
            'Last attempt (test email): accepted by the provider · 2026-10-19 12:00:00',
          ),
          findsOneWidget,
        );
        await tester.pumpWidget(_card(_live, stale: true));
        expect(find.text('Unverified'), findsOneWidget);
        expect(find.text('Ready'), findsNothing);
        await tester.pumpWidget(_card(null));
        expect(find.byType(Card), findsNothing);
        expect(find.text('Password reset email'), findsNothing);
      },
    );

    testWidgets(
      'it describes a Gmail channel, its missing App Password and SMTP rejection codes',
      (tester) async {
        await tester.pumpWidget(
          _card({
            'mode': 'gmail',
            'configured': true,
            'ready_for_real_delivery': true,
            'sender_domain': 'gmail.com',
            'problems': [],
            'last_attempt': {
              'at': '2026-10-19 13:00:00',
              'purpose': 'test',
              'accepted': true,
              'http': null,
              'code': 250,
            },
          }),
        );
        expect(
          find.text('Gmail (SMTP) · sender domain gmail.com'),
          findsOneWidget,
        );
        expect(find.text('Ready'), findsOneWidget);
        await tester.pumpWidget(
          _card({
            'mode': 'gmail',
            'configured': false,
            'ready_for_real_delivery': false,
            'sender_domain': 'gmail.com',
            'problems': [
              'No Gmail App Password is configured. Gmail needs an App Password (2-Step Verification must be on), not the normal Gmail password.',
            ],
            'last_attempt': null,
          }),
        );
        expect(find.text('Not configured'), findsWidgets);
        expect(
          find.textContaining('Gmail needs an App Password'),
          findsOneWidget,
        );
        await tester.pumpWidget(
          _card({
            'mode': 'gmail',
            'configured': true,
            'ready_for_real_delivery': true,
            'sender_domain': 'gmail.com',
            'problems': [],
            'last_attempt': {
              'at': '2026-10-19 13:05:00',
              'purpose': 'password_reset',
              'accepted': false,
              'http': null,
              'code': 535,
            },
          }),
        );
        expect(find.text('Last attempt failed'), findsOneWidget);
        expect(
          find.text(
            'Last attempt (password reset): rejected (code 535) · 2026-10-19 13:05:00',
          ),
          findsOneWidget,
        );
        await tester.pumpWidget(_card({..._live, 'mode': 'smtp'}));
        expect(find.textContaining('SMTP mail server'), findsOneWidget);
      },
    );

    testWidgets(
      'the test button reflects progress, shows the provider result and is honest about delivery',
      (tester) async {
        await tester.pumpWidget(_card(_live));
        expect(find.text('Send test email to my address'), findsOneWidget);
        expect(
          find.textContaining('does not guarantee it reaches the inbox'),
          findsOneWidget,
        );
        await tester.pumpWidget(_card(_live, testing: true));
        expect(find.text('Sending test…'), findsOneWidget);
        expect(
          tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
          isNull,
        );
        await tester.pumpWidget(
          _card(
            _live,
            result: {
              'accepted': true,
              'message':
                  'The mail provider accepted a test message for o***@x.test.',
            },
          ),
        );
        expect(find.byKey(const Key('email-test-accepted')), findsOneWidget);
        await tester.pumpWidget(
          _card(
            _live,
            result: {
              'accepted': false,
              'message':
                  'The mail provider could not find the address it was given (HTTP 404).',
            },
          ),
        );
        expect(find.byKey(const Key('email-test-accepted')), findsNothing);
        expect(
          find.textContaining('could not find the address'),
          findsOneWidget,
        );
        await tester.pumpWidget(
          _card(
            _live,
            error: 'Your administrator account has no valid email address.',
          ),
        );
        expect(find.textContaining('no valid email address'), findsOneWidget);
      },
    );
  });

  group('the System page', () {
    testWidgets(
      'it shows health, counts and the email channel with the web wording',
      (tester) async {
        await _mount(tester, _Api());
        expect(find.text('API / PHP'), findsOneWidget);
        expect(find.text('online'), findsOneWidget);
        expect(find.text('Accounts by role'), findsOneWidget);
        expect(find.text('6 clerks · 4 heads · 2 admin'), findsOneWidget);
        expect(find.text('MOVEMENTS TODAY'), findsOneWidget);
        expect(find.text('Accounts on duty'), findsNothing);
        expect(find.text('SCANS TODAY'), findsNothing);
        expect(find.text('Password reset email'), findsOneWidget);
        expect(find.text('Ready'), findsOneWidget);
        expect(find.text('Refresh status'), findsOneWidget);
        expect(find.textContaining('Updated Just now'), findsOneWidget);
        expect(find.text('Unverified'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Send test email sends once, shows progress and updates the card from the answer',
      (tester) async {
        final api = _Api()..pendingTest = Completer();
        await _mount(tester, api);
        await tester.ensureVisible(find.text('Send test email to my address'));
        await tester.tap(find.text('Send test email to my address'));
        await tester.pump();
        expect(find.text('Sending test…'), findsOneWidget);
        // A second tap while it is sending does nothing.
        await tester.tap(find.text('Sending test…'), warnIfMissed: false);
        await tester.pump();
        expect(api.testCalls, 1);
        api.pendingTest!.complete(api.testResult);
        await tester.pumpAndSettle();
        expect(find.text('Send test email to my address'), findsOneWidget);
        expect(find.byKey(const Key('email-test-accepted')), findsOneWidget);
        expect(
          find.textContaining('accepted a test message for o***@x.test'),
          findsOneWidget,
        );
        expect(
          find.text(
            'Last attempt (test email): accepted by the provider · 2026-10-26 09:00:00',
          ),
          findsOneWidget,
        );
        expect(api.testCalls, 1);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'a test the provider rejected and a test that could not be sent are shown, never repeated by themselves',
      (tester) async {
        final api = _Api()
          ..testResult = {
            'accepted': false,
            'message':
                'The mail provider could not find the address it was given (HTTP 404).',
            'email': _live,
          };
        await _mount(tester, api);
        await tester.ensureVisible(find.text('Send test email to my address'));
        await tester.tap(find.text('Send test email to my address'));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('could not find the address'),
          findsOneWidget,
        );
        expect(find.byKey(const Key('email-test-accepted')), findsNothing);
        api.testFailure = ApiException(
          'Too many test emails. Try again in a few minutes.',
          429,
        );
        await tester.tap(find.text('Send test email to my address'));
        await tester.pumpAndSettle();
        expect(find.textContaining('Too many test emails'), findsOneWidget);
        expect(find.textContaining('could not find the address'), findsNothing);
        expect(api.testCalls, 2);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'a failed refresh keeps the earlier answer but marks it unverified, until a check succeeds',
      (tester) async {
        final api = _Api();
        await _mount(tester, api);
        expect(find.text('online'), findsOneWidget);
        api.failStatus = true;
        await _refresh(tester);
        expect(find.textContaining('Status refresh failed.'), findsOneWidget);
        expect(
          find.textContaining(
            'Showing the last successful check; current health and counts are unverified.',
          ),
          findsOneWidget,
        );
        expect(find.text('online'), findsNothing);
        expect(find.text('Ready'), findsNothing);
        expect(
          find.text('Unverified'),
          findsNWidgets(2),
          reason: 'the API pill and the email pill',
        );
        expect(find.text('Last reported: On (PHP)'), findsOneWidget);
        expect(find.textContaining('Last successful check'), findsOneWidget);
        expect(find.text('Status unavailable'), findsNothing);
        api.failStatus = false;
        await tester.tap(find.text('Refresh status'));
        await tester.pumpAndSettle();
        expect(find.textContaining('Status refresh failed.'), findsNothing);
        expect(find.text('online'), findsOneWidget);
        expect(find.text('Ready'), findsOneWidget);
        expect(find.text('Unverified'), findsNothing);
        expect(find.textContaining('Updated Just now'), findsOneWidget);
      },
    );

    testWidgets(
      'while a new check runs the earlier answer stays and is called unverified',
      (tester) async {
        final api = _Api();
        await _mount(tester, api);
        api.pendingStatus = Completer();
        final refresh = tester
            .widget<RefreshIndicator>(find.byType(RefreshIndicator))
            .onRefresh();
        await tester.pump();
        expect(find.text('Refreshing…'), findsOneWidget);
        expect(find.textContaining('Checking current health.'), findsOneWidget);
        expect(find.text('Unverified'), findsNWidgets(2));
        expect(find.text('online'), findsNothing);
        api.pendingStatus!.complete(_status());
        await refresh;
        await tester.pumpAndSettle();
        expect(find.text('online'), findsOneWidget);
        expect(find.textContaining('Checking current health.'), findsNothing);
      },
    );

    testWidgets(
      'a first check that fails is unavailable, with no invented health',
      (tester) async {
        final api = _Api()..failStatus = true;
        await _mount(tester, api);
        expect(
          find.textContaining('System status unavailable.'),
          findsOneWidget,
        );
        expect(
          find.textContaining('Retry with Refresh status.'),
          findsOneWidget,
        );
        expect(find.text('online'), findsNothing);
        expect(find.text('offline'), findsNothing);
        expect(find.text('Password reset email'), findsNothing);
        expect(find.text('Status unavailable'), findsNothing);
        api.failStatus = false;
        await tester.tap(find.text('Refresh status'));
        await tester.pumpAndSettle();
        expect(find.text('online'), findsOneWidget);
        expect(find.text('Password reset email'), findsOneWidget);
      },
    );

    testWidgets(
      'the email card fits 320px with doubled text, long problems and a long answer',
      (tester) async {
        final api = _Api()
          ..email = {
            'mode': 'sandbox',
            'configured': true,
            'ready_for_real_delivery': false,
            'sender_domain': 'a-very-long-sender-domain.urbiztondo.gov.ph',
            'problems': [
              'The sandbox address has no inbox number, so the provider rejects every request (HTTP 404) and no reset email is delivered to anyone.',
            ],
            'last_attempt': {
              'at': '2026-10-19 11:30:03',
              'purpose': 'password_reset',
              'accepted': false,
              'http': 404,
            },
          }
          ..testResult = {
            'accepted': true,
            'message':
                'The mail provider accepted a test message for o***@verylongaddress.example. Check that inbox and its spam folder; acceptance does not guarantee delivery.',
            'email': _live,
          };
        await _mount(tester, api, width: 320, height: 6000, scale: 2);
        await tester.scrollUntilVisible(
          find.text('Send test email to my address'),
          240,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(find.text('Send test email to my address'));
        await tester.tap(find.text('Send test email to my address'));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('email-test-accepted')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
