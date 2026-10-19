import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartflow/models/user.dart';
import 'package:smartflow/providers/auth_provider.dart';
import 'package:smartflow/screens/staff/staff_shell.dart';
import 'package:smartflow/services/api_client.dart';
import 'package:smartflow/services/smartflow_api.dart';
import 'package:smartflow/screens/staff/clerk_widgets.dart';
import 'package:smartflow/theme/smartflow_theme.dart';

class _DeskAuth extends AuthProvider {
  _DeskAuth(this.fixture);
  final SmartflowApi fixture;
  @override
  SmartflowApi get api => fixture;
  @override
  bool get isAuthenticated => true;
  @override
  AppUser get user => AppUser(
    id: 1,
    name: 'Desk test',
    username: 'desk.test',
    role: 'staff',
    officeId: 1,
    officeName: 'Engineering Office',
    officeCode: 'ENG',
  );
}

void main() {
  testWidgets(
    'Home quick receive checks contents and cancellation never writes',
    (tester) async {
      GoogleFonts.config.allowRuntimeFetching = false;
      SharedPreferences.setMockInitialValues({
        'sf_role_tip_seen_v2_desk.test': true,
      });
      final writes = <Map<String, dynamic>>[];
      final api = SmartflowApi(
        ApiClient(
          token: 'fixture',
          client: MockClient((request) async {
            Map<String, dynamic> data = {};
            switch (request.url.pathSegments.last) {
              case 'dashboard-stats.php':
                data = {
                  'stats': {'in_flow': 0, 'out_flow': 0, 'active_tags': 0},
                  'in_transit': [
                    {
                      'document_id': 'DOC-2026-000001',
                      'title': 'Folder',
                      'last_office_name': 'Budget Office',
                      'last_office_code': 'BUD',
                    },
                  ],
                };
              case 'office-documents.php':
                data = {
                  'document': {
                    'id': 'DOC-2026-000001',
                    'last_movement_id': 2,
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
                  },
                };
              case 'movements-create.php':
                writes.add(jsonDecode(request.body) as Map<String, dynamic>);
                data = {'message': 'Incomplete contents recorded'};
            }
            return http.Response(jsonEncode({'success': true, ...data}), 200);
          }),
        ),
      );
      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => _DeskAuth(api),
          child: MaterialApp(
            theme: buildSmartflowTheme(),
            home: const Scaffold(body: StaffDashboardScreen()),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 350));
      await tester.ensureVisible(find.text('Receive (IN)'));
      await tester.pump();
      await tester.tap(find.text('Receive (IN)'));
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('Check folder contents'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pump(const Duration(milliseconds: 350));
      expect(writes, isEmpty);
      await tester.tap(find.text('Receive (IN)'));
      await tester.pump(const Duration(milliseconds: 350));
      Finder input(String label) => find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == label,
      );
      for (final entry in {
        'Main document — received pages': '2',
        'Supporting document — received pages': '0',
        'Discrepancy / missing item details':
            'Supporting document did not arrive',
      }.entries) {
        await tester.ensureVisible(input(entry.key));
        await tester.enterText(input(entry.key), entry.value);
        await tester.pump(const Duration(milliseconds: 350));
      }
      final confirm = find.text(
        'I physically received this folder and checked its reference and contents.',
      );
      await tester.ensureVisible(confirm);
      await tester.tap(confirm);
      await tester.pump(const Duration(milliseconds: 350));
      await tester.tap(find.text('Receive incomplete folder'));
      await tester.pump(const Duration(milliseconds: 350));
      expect(writes.single['movement_source'], 'system');
      expect(writes.single['expected_movement_id'], 2);
      expect(writes.single['receipt_confirmed'], isTrue);
      expect(writes.single['contents_receipt']['items'][1]['pages'], 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'Desk custody labels fit at normal and enlarged phone text sizes',
    (tester) async {
      GoogleFonts.config.allowRuntimeFetching = false;
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final scale in [1.0, 1.6, 2.0]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: buildSmartflowTheme(),
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: Scaffold(
                body: ListView(
                  children: [
                    SfClerkIncomingDocRow(
                      documentId: 'DOC-2026-000001',
                      title: 'Folder',
                      fromOfficeCode: 'BUD',
                      fromOfficeName: 'Budget Office',
                      outAt: null,
                      onTap: () {},
                      onMarkIn: () {},
                    ),
                    SfClerkActiveDocumentRow(
                      documentId: 'DOC-2026-000002',
                      title: 'Folder',
                      lastScannedAt: null,
                      onTap: () {},
                      onMarkOut: () {},
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        for (final label in ['Receive (IN)', 'Send (OUT)']) {
          final text = find.text(label);
          final paragraph = tester.renderObject<RenderParagraph>(text);
          expect(
            paragraph.size.height,
            greaterThanOrEqualTo(
              paragraph.getMinIntrinsicHeight(paragraph.size.width) - .01,
            ),
            reason:
                '$label must show its full line height at $scale text scale',
          );
        }
        expect(tester.takeException(), isNull);
      }
    },
  );
}
