import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:smartflow/widgets/sf_widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartflow/models/user.dart';
import 'package:smartflow/providers/auth_provider.dart';
import 'package:smartflow/services/api_client.dart';
import 'package:smartflow/services/smartflow_api.dart';
import 'package:smartflow/screens/shared/document_register_screen.dart';
import 'package:smartflow/screens/shared/documents_screen.dart';
import 'package:smartflow/screens/staff/scanner_screen.dart';
import 'package:smartflow/screens/staff/staff_shell.dart';
import 'package:smartflow/screens/shared/document_requests_screen.dart';
import 'package:smartflow/screens/shared/office_checklists_screen.dart';
import 'package:smartflow/widgets/folder_contents.dart';
import 'package:smartflow/theme/smartflow_theme.dart';

class _Auth extends AuthProvider {
  _Auth({this.role = 'staff'});
  final String role;
  final checklistWrites = <Map<String, dynamic>>[];
  @override
  bool get isAuthenticated => true;
  @override
  AppUser get user => AppUser(
    id: 101,
    name: 'Layout clerk',
    username: 'layout',
    role: role,
    officeId: 1,
    officeName: 'Engineering Office',
    officeCode: 'ENG',
  );
  @override
  late final api = SmartflowApi(
    ApiClient(
      client: MockClient((request) async {
        if (request.method == 'POST' &&
            request.url.pathSegments.last == 'folder-checklists.php') {
          checklistWrites.add(
            Map<String, dynamic>.from(jsonDecode(request.body) as Map),
          );
          return http.Response('{"success":true,"id":1}', 200);
        }
        final data = switch (request.url.pathSegments.last) {
          'folder-checklists.php' => {
            'checklists': [
              {
                'id': 1,
                'name': 'Office-approved supporting requirements',
                'document_type': 'Disbursement Voucher',
                'items': [
                  {'name': 'Supporting document', 'required': true},
                ],
              },
            ],
          },
          'office-documents.php' => {
            'documents': [
              {
                'id': 'DOC-2026-000001',
                'title':
                    'A long document title for road repairs and supporting papers',
                'tray': 'incoming',
                'current_status': 'OUT',
                'current_office_name': 'Budget Office',
                'hours_waiting': 12,
                'due_at': '2026-10-01 10:00:00',
                'is_overdue': true,
              },
            ],
            'total': 1,
            'has_more': false,
            'tray_counts': {'incoming': 1},
            'overdue_count': 1,
          },
          'dashboard-stats.php' => {
            'stats': {'in_flow': 0, 'out_flow': 0, 'active_tags': 0},
          },
          'head-dashboard.php' => {
            'stats': {'in_office': 0, 'overdue': 0, 'avg_hours': 0},
          },
          'alerts-list.php' => {'alerts': []},
          'document-requests.php' => {'requests': []},
          _ => <String, dynamic>{},
        };
        return http.Response(jsonEncode({'success': true, ...data}), 200);
      }),
    ),
  );
}

void main() {
  for (final width in [320.0, 360.0, 390.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'Core mobile pages and receipt at ${width}px / ${scale}x text',
        (tester) async {
          GoogleFonts.config.allowRuntimeFetching = false;
          SharedPreferences.setMockInitialValues({
            'sf_role_tip_seen_v2_layout': true,
          });
          tester.view.physicalSize = Size(width, 740);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetViewInsets);
          final router = GoRouter(
            initialLocation: '/register',
            routes: [
              GoRoute(
                path: '/register',
                builder: (_, _) =>
                    const DocumentRegisterScreen(homeRoute: '/documents'),
              ),
              GoRoute(
                path: '/documents',
                builder: (_, _) => const Scaffold(body: DocumentsScreen()),
              ),
              GoRoute(
                path: '/scan',
                builder: (_, _) => const Scaffold(body: ScannerScreen()),
              ),
              GoRoute(
                path: '/home',
                builder: (_, _) => const Scaffold(body: StaffDashboardScreen()),
              ),
              GoRoute(
                path: '/history',
                builder: (_, _) => const Scaffold(body: StaffHistoryScreen()),
              ),
              GoRoute(
                path: '/alerts',
                builder: (_, _) => const Scaffold(body: StaffAlertsScreen()),
              ),
              GoRoute(
                path: '/profile',
                builder: (_, _) => const Scaffold(body: ProfileScreen()),
              ),
              GoRoute(
                path: '/requests',
                builder: (_, _) =>
                    const DocumentRequestsScreen(homeRoute: '/head'),
              ),
              GoRoute(
                path: '/receipt',
                builder: (_, _) => Scaffold(
                  body: Builder(
                    builder: (context) => Center(
                      child: ElevatedButton(
                        onPressed: () => showFolderReceiptDialog(context, {
                          'id': 'DOC-2026-000001',
                          'folder_inventory': {
                            'total_pages': 8,
                            'items': [
                              {
                                'id': 'main',
                                'name': 'Main document',
                                'pages': 2,
                                'required': true,
                              },
                              {
                                'id': 'attachment-1',
                                'name': 'Supporting document',
                                'pages': 6,
                                'required': true,
                              },
                            ],
                          },
                        }),
                        child: const Text('Open receipt'),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
          addTearDown(router.dispose);
          await tester.pumpWidget(
            ChangeNotifierProvider<AuthProvider>(
              create: (_) => _Auth(),
              child: MaterialApp.router(
                theme: buildSmartflowTheme().copyWith(
                  platform: TargetPlatform.windows,
                ),
                routerConfig: router,
                builder: (c, child) => MediaQuery(
                  data: MediaQuery.of(
                    c,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 400));
          expect(tester.takeException(), isNull);
          tester.view.viewInsets = const FakeViewPadding(bottom: 260);
          await tester.pump(const Duration(milliseconds: 300));
          await tester.ensureVisible(
            find.widgetWithText(SfPrimaryButton, 'Register folder'),
          );
          await tester.pump(const Duration(milliseconds: 300));
          expect(tester.takeException(), isNull);
          tester.view.resetViewInsets();
          FocusManager.instance.primaryFocus?.unfocus();
          await tester.pump(const Duration(milliseconds: 350));
          final checklist = find.text(
            'Use Office-approved supporting requirements',
          );
          await tester.ensureVisible(checklist);
          await tester.pump(const Duration(milliseconds: 350));
          await tester.tap(checklist);
          await tester.pump(const Duration(milliseconds: 350));
          expect(find.text('Publish attachments as checklist'), findsNothing);
          router.go('/documents');
          await tester.pump(const Duration(milliseconds: 400));
          await tester.pump();
          expect(tester.takeException(), isNull);
          router.go('/scan');
          await tester.pump(const Duration(milliseconds: 400));
          await tester.pump();
          expect(tester.takeException(), isNull);
          router.go('/receipt');
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          await tester.tap(find.text('Open receipt'));
          await tester.pump(const Duration(milliseconds: 400));
          tester.view.viewInsets = const FakeViewPadding(bottom: 260);
          await tester.pump(const Duration(milliseconds: 300));
          expect(tester.takeException(), isNull);
          await tester.tap(find.text('Cancel'));
          await tester.pump(const Duration(milliseconds: 400));
          tester.view.resetViewInsets();
          for (final route in [
            '/home',
            '/requests',
            '/history',
            '/alerts',
            '/profile',
          ]) {
            router.go(route);
            await tester.pump(const Duration(milliseconds: 400));
            await tester.pump();
            expect(
              tester.takeException(),
              isNull,
              reason: '$route at $width / $scale',
            );
          }
          await tester.pumpWidget(const SizedBox());
          await tester.pump();
        },
      );
    }
  }

  for (final role in ['head', 'admin']) {
    for (final viewport in [(320.0, 2.0), (390.0, 1.0)]) {
      testWidgets(
        '$role manages own-office checklist independently at ${viewport.$1}px / ${viewport.$2}x',
        (tester) async {
          GoogleFonts.config.allowRuntimeFetching = false;
          tester.view.physicalSize = Size(viewport.$1, 740);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetViewInsets);
          final auth = _Auth(role: role);
          await tester.pumpWidget(
            ChangeNotifierProvider<AuthProvider>.value(
              value: auth,
              child: MaterialApp(
                theme: buildSmartflowTheme().copyWith(
                  platform: TargetPlatform.windows,
                ),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(viewport.$2)),
                  child: child!,
                ),
                home: const Scaffold(body: OfficeChecklistsScreen()),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('Office checklists'), findsOneWidget);
          expect(find.text('Applies to Engineering Office'), findsOneWidget);
          expect(find.text('Main document pages'), findsNothing);
          expect(
            find.text(
              'I physically hold this folder and counted its contents.',
            ),
            findsNothing,
          );
          final publish = find.text('Publish attachments as checklist');
          await tester.ensureVisible(publish);
          await tester.pumpAndSettle();
          await tester.tap(publish);
          await tester.pumpAndSettle();
          expect(
            find.text('Add at least one attachment before publishing.'),
            findsOneWidget,
          );
          expect(auth.checklistWrites, isEmpty);
          final use = find.text('Use Office-approved supporting requirements');
          await tester.ensureVisible(use);
          await tester.pumpAndSettle();
          await tester.tap(use);
          await tester.pumpAndSettle();
          expect(find.text('Attachment pages'), findsNothing);
          expect(find.text('Required attachment'), findsOneWidget);
          await tester.ensureVisible(publish);
          await tester.pumpAndSettle();
          await tester.tap(publish);
          await tester.pumpAndSettle();
          tester.view.viewInsets = const FakeViewPadding(bottom: 260);
          await tester.pumpAndSettle();
          expect(find.text('Publish office checklist'), findsOneWidget);
          final name = find.byWidgetPredicate(
            (widget) =>
                widget is TextField &&
                widget.decoration?.labelText == 'Checklist name',
          );
          await tester.enterText(name, 'Road project supporting papers');
          await tester.ensureVisible(find.text('Publish'));
          await tester.tap(find.text('Publish'));
          await tester.pumpAndSettle(const Duration(milliseconds: 350));
          expect(auth.checklistWrites.single, {
            'name': 'Road project supporting papers',
            'document_type': 'Disbursement Voucher',
            'items': [
              {'name': 'Supporting document', 'required': true},
            ],
          });
          expect(tester.takeException(), isNull);
          tester.view.resetViewInsets();
          await tester.pumpWidget(const SizedBox());
          auth.dispose();
        },
      );
    }
  }
}
