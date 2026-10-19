import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:smartflow/models/user.dart';
import 'package:smartflow/providers/auth_provider.dart';
import 'package:smartflow/screens/shared/documents_screen.dart';
import 'package:smartflow/services/api_client.dart';
import 'package:smartflow/services/smartflow_api.dart';
import 'package:smartflow/theme/smartflow_theme.dart';
import 'package:smartflow/utils/tracking_id.dart';

class _CustodyApi extends SmartflowApi {
  _CustodyApi() : super(ApiClient());
  @override
  Future<Map<String, dynamic>> officeDocuments({String? id}) async => {
    'document': {
      'id': 'DOC-2026-000001',
      'title': 'Received evidence folder',
      'type': 'Others: Evidence',
      'tray': 'in_office',
      'current_status': 'IN',
      'current_office_name': 'Engineering Office',
      'current_office_id': 1,
      'origin_office_name': 'Engineering Office',
      'last_movement_id': 1,
      'qr_payload': 'DOC-2026-000001',
      'can_file': true,
      'journey': [],
    },
    // Intentionally missing read_only: client must still enforce its role.
  };
}

class _CustodyAuth extends AuthProvider {
  _CustodyAuth(this.role, {SmartflowApi? custom})
    : fixture = custom ?? _CustodyApi();
  final String role;
  final SmartflowApi fixture;
  @override
  SmartflowApi get api => fixture;
  @override
  AppUser get user => AppUser(
    id: 1,
    name: 'Test user',
    username: 'test.$role',
    role: role,
    officeId: 1,
    officeName: 'Engineering Office',
    officeCode: 'ENG',
  );
}

class _ForeignApi extends _CustodyApi {
  @override
  Future<Map<String, dynamic>> officeDocuments({String? id}) async =>
      throw ApiException('Outside office tray', 404);
  @override
  Future<Map<String, dynamic>> documentShow(String id) async => {
    'document': {
      'id': id,
      'title': 'Linked folder at Treasury',
      'type': 'Others: Evidence',
      'current_status': 'IN',
      'current_office_name': 'Treasury Office',
      'current_office_id': 5,
      'can_file': true,
      'can_correct_destination': true,
    },
  };
  @override
  Future<Map<String, dynamic>> documentMovements(String id) async => {
    'movements': [],
  };
}

void main() {
  testWidgets(
    'linked foreign folder opens tracking details without granting custody writes',
    (tester) async {
      GoogleFonts.config.allowRuntimeFetching = false;
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => _CustodyAuth('staff', custom: _ForeignApi()),
          child: MaterialApp(
            theme: buildSmartflowTheme(),
            home: const Scaffold(
              body: DocumentsScreen(initialDocumentId: 'DOC-2026-000001'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Linked folder at Treasury'), findsOneWidget);
      expect(find.textContaining('outside your office tray'), findsOneWidget);
      expect(find.text('File this folder'), findsNothing);
      expect(find.text('Send (OUT)'), findsNothing);
      expect(find.text('Correct recorded destination'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
  test('monitor scan lookups expose no custody writes', () {
    for (final role in ['head', 'admin', 'auditor']) {
      for (final status in ['IN', 'OUT', null]) {
        final actions = clerkScanActions(
          lastMovement: null,
          myOfficeId: 1,
          currentStatus: status,
          currentOfficeId: status == null ? null : 1,
          role: role,
        );
        expect(actions.canIn, isFalse);
        expect(actions.canOut, isFalse);
        expect(actions.blockReason, contains('Read-only custody'));
      }
    }
    expect(
      clerkScanActions(
        lastMovement: null,
        myOfficeId: 1,
        currentStatus: 'IN',
        currentOfficeId: 1,
        role: 'staff',
      ).canOut,
      isTrue,
    );
  });

  for (final role in ['staff', 'head', 'admin']) {
    testWidgets(
      '$role folder details keep custody controls in their permitted role',
      (tester) async {
        GoogleFonts.config.allowRuntimeFetching = false;
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          ChangeNotifierProvider<AuthProvider>(
            create: (_) => _CustodyAuth(role),
            child: MaterialApp(
              theme: buildSmartflowTheme(),
              home: const Scaffold(
                body: DocumentsScreen(initialDocumentId: 'DOC-2026-000001'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Received evidence folder'), findsOneWidget);
        expect(
          find.text('File this folder'),
          role == 'staff' ? findsOneWidget : findsNothing,
        );
        expect(
          find.text('Send (OUT)'),
          role == 'staff' ? findsOneWidget : findsNothing,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );
  }
}
