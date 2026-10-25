import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:smartflow/widgets/sf_widgets.dart';
import 'package:smartflow/widgets/document_summary.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartflow/models/user.dart';
import 'package:smartflow/providers/auth_provider.dart';
import 'package:smartflow/screens/shared/document_register_screen.dart';
import 'package:smartflow/screens/staff/scanner_screen.dart';
import 'package:smartflow/services/api_client.dart';
import 'package:smartflow/services/smartflow_api.dart';
import 'package:smartflow/theme/smartflow_theme.dart';

const _id = 'DOC-2026-000701';
const _title =
    'Road maintenance folder with a long title and supporting papers';
const _office = 'Engineering and Municipal Infrastructure Office';

/// Every read is synthetic; recovering the saved result never submits a write.
class _LayoutApi extends SmartflowApi {
  _LayoutApi() : super(ApiClient());

  int lookups = 0;
  int recoveries = 0;

  static Map<String, dynamic> get document => {
    'id': _id,
    'title': _title,
    'type': 'Others: Road maintenance supporting papers',
    'origin_office_name': _office,
    'current_status': 'IN',
    'current_office_id': 1,
    'current_office_name': _office,
    'last_movement_id': 71,
    'due_at_display': '17 October 2026, 5:00 PM',
    'is_overdue': true,
    'can_file': true,
    'initial_in_recorded': true,
    'qr_payload': _id,
  };

  @override
  Future<Map<String, dynamic>> documentShow(String id) async {
    if (id != _id) throw StateError('Unexpected folder lookup');
    lookups++;
    return {'document': document};
  }

  @override
  Future<Map<String, dynamic>> folderChecklists() async => {'checklists': []};

  @override
  Future<Map<String, dynamic>?> pendingCreation(String kind) async => {
    'body': {'title': _title},
  };

  @override
  Future<Map<String, dynamic>?> checkCreation(String kind) async {
    if (kind != 'document') throw StateError('Unexpected recovery kind');
    recoveries++;
    return {
      'state': 'recorded',
      'result': {'document': document},
    };
  }
}

class _LayoutAuth extends AuthProvider {
  _LayoutAuth(this.fixture);
  final _LayoutApi fixture;

  @override
  SmartflowApi get api => fixture;

  @override
  AppUser get user => const AppUser(
    id: 701,
    name: 'Layout fixture clerk',
    username: 'layout.fixture',
    role: 'staff',
    officeId: 1,
    officeCode: 'ENG',
    officeName: _office,
  );
}

void main() {
  for (final width in [320.0, 360.0, 390.0]) {
    testWidgets('Scan result and recovered registration fit at ${width}px / 2x', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final fontDownloads = GoogleFonts.config.allowRuntimeFetching;
      GoogleFonts.config.allowRuntimeFetching = false;
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() {
        GoogleFonts.config.allowRuntimeFetching = fontDownloads;
        debugDefaultTargetPlatformOverride = null;
      });
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      final api = _LayoutApi();
      final router = GoRouter(
        initialLocation: '/staff/scan',
        routes: [
          GoRoute(
            path: '/staff/scan',
            builder: (_, _) => const Scaffold(body: ScannerScreen()),
          ),
          GoRoute(
            path: '/staff/register',
            builder: (_, _) => const Scaffold(
              body: DocumentRegisterScreen(homeRoute: '/staff'),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => _LayoutAuth(api),
          child: MaterialApp.router(
            theme: buildSmartflowTheme(),
            routerConfig: router,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(2)),
              child: child!,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(TextField));
      await tester.enterText(find.byType(TextField), _id);
      await tester.ensureVisible(find.text('Look up document'));
      await tester.tap(find.text('Look up document'));
      await tester.pumpAndSettle();
      expect(find.text(_title), findsOneWidget);
      expect(find.text('Overdue'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text('File this folder'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Send (OUT)'), findsOneWidget);
      expect(api.lookups, 1);
      expect(tester.takeException(), isNull);

      router.go('/staff/register');
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(SfPrimaryButton, 'Register folder'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Register an unlabelled folder already held by your office. Registration records its initial IN.',
        ),
        findsOneWidget,
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.pump();
      await tester.ensureVisible(
        find.widgetWithText(SfPrimaryButton, 'Register folder'),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Check previous submission'));
      await tester.pumpAndSettle();
      expect(
        find.text('Check previous submission').hitTestable(),
        findsOneWidget,
      );
      await tester.tap(find.text('Check previous submission'));
      await tester.pumpAndSettle();
      expect(find.text('Document registered'), findsOneWidget);
      expect(find.text(_title), findsOneWidget);
      expect(api.recoveries, 1);
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text('Registration details'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('Registration details'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Registration details'));
      await tester.pumpAndSettle();
      final savedSummary = tester.widget<DocumentSummary>(
        find.byType(DocumentSummary),
      );
      expect(savedSummary.showCustody, isFalse);
      expect(savedSummary.document['current_status'], 'IN');
      expect(find.byType(DocumentStatus), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Download QR image'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      debugDefaultTargetPlatformOverride = null;
    });
  }
}
