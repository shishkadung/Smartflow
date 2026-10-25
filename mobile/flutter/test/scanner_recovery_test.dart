import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartflow/models/user.dart';
import 'package:smartflow/providers/auth_provider.dart';
import 'package:smartflow/screens/staff/scanner_screen.dart';
import 'package:smartflow/services/api_client.dart';
import 'package:smartflow/services/smartflow_api.dart';
import 'package:smartflow/widgets/sf_widgets.dart';

const _firstId = 'DOC-2026-000101';
const _recoveryId = 'DOC-2026-000102';
const _missingId = 'DOC-2026-999999';
const _firstTitle = 'First controlled folder';
const _recoveryTitle = 'Recovered controlled folder';
const _rejectedQr = 'SF1.test-payload.test-signature';

/// Only these explicit responses are allowed. No request reaches a real API.
class _ScannerApi extends SmartflowApi {
  _ScannerApi() : super(ApiClient());

  final documentRequests = <String>[];
  final verifyRequests = <String>[];
  Completer<Map<String, dynamic>>? pendingRecovery;

  static Map<String, dynamic> document(String id, String title) => {
    'document': {
      'id': id,
      'title': title,
      'type': 'Others: Controlled folder',
      'origin_office_name': 'Engineering Office',
      'current_status': 'IN',
      'current_office_id': 1,
      'current_office_name': 'Engineering Office',
      'is_overdue': false,
    },
  };

  @override
  Future<Map<String, dynamic>> documentShow(String id) async {
    documentRequests.add(id);
    if (documentRequests.length > 3) {
      throw StateError('Unexpected repeated document request');
    }
    switch (id) {
      case _firstId:
        return document(id, _firstTitle);
      case _recoveryId:
        final pending = pendingRecovery;
        if (pending != null) return pending.future;
        return document(id, _recoveryTitle);
      case _missingId:
        throw ApiException('Document not found', 404);
      default:
        throw StateError('Unexpected document ID: $id');
    }
  }

  @override
  Future<Map<String, dynamic>> verifyQr(String qrPayload) async {
    verifyRequests.add(qrPayload);
    if (qrPayload != _rejectedQr || verifyRequests.length != 1) {
      throw StateError('Unexpected secured QR verification');
    }
    throw ApiException('QR signature invalid', 400, null, 'qr_tampered');
  }
}

class _ScannerAuth extends AuthProvider {
  _ScannerAuth(this.scannerApi);

  final _ScannerApi scannerApi;

  @override
  SmartflowApi get api => scannerApi;

  @override
  AppUser get user => const AppUser(
    id: 101,
    name: 'Scanner regression staff',
    username: 'scanner.test',
    role: 'staff',
    officeId: 1,
    officeName: 'Engineering Office',
    officeCode: 'ENG',
  );

  @override
  bool get isAuthenticated => true;

  @override
  bool get loading => false;
}

Future<void> _mountScanner(WidgetTester tester, _ScannerApi api) async {
  // The Windows test variant uses manual fallback without starting a camera.
  SharedPreferences.setMockInitialValues({});
  final allowFontDownloads = GoogleFonts.config.allowRuntimeFetching;
  GoogleFonts.config.allowRuntimeFetching = false;
  addTearDown(
    () => GoogleFonts.config.allowRuntimeFetching = allowFontDownloads,
  );
  tester.view.physicalSize = const Size(900, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ChangeNotifierProvider<AuthProvider>(
      create: (_) => _ScannerAuth(api),
      child: MaterialApp(
        theme: ThemeData(platform: TargetPlatform.windows),
        home: const Scaffold(body: ScannerScreen()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(find.text('Tracking ID'), findsOneWidget);
  expect(tester.takeException(), isNull);
}

Future<void> _lookUp(WidgetTester tester, String input) async {
  if (find.byType(TextField).evaluate().isEmpty) {
    await tester.ensureVisible(find.text('Look up another'));
    await tester.tap(find.text('Look up another'));
    await tester.pumpAndSettle();
  }
  final field = find.byType(TextField);
  await tester.ensureVisible(field);
  await tester.enterText(field, input);
  final button = find.text('Look up document');
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pump();
}

void _expectLoaded(WidgetTester tester, String title) {
  expect(find.text(title), findsWidgets);
  expect(find.text('Document details'), findsOneWidget);
  expect(find.text('Send (OUT)'), findsOneWidget);
  expect(find.text('Look up another'), findsOneWidget);
  expect(find.byType(TextField), findsNothing);
  expect(tester.takeException(), isNull);
}

void _expectCleared(WidgetTester tester) {
  expect(find.text('DOCUMENT LOADED'), findsNothing);
  expect(find.text('Document loaded'), findsNothing);
  expect(find.text(_firstTitle), findsNothing);
  expect(find.text('Document details'), findsNothing);
  expect(find.text('Receive (IN)'), findsNothing);
  expect(find.text('Send (OUT)'), findsNothing);
  expect(find.text('Tracking ID'), findsOneWidget);
  expect(tester.takeException(), isNull);
}

Future<void> _recover(WidgetTester tester, _ScannerApi api) async {
  await _lookUp(tester, _recoveryId);
  await tester.pumpAndSettle();
  _expectLoaded(tester, _recoveryTitle);
  expect(find.text(_firstTitle), findsNothing);
  expect(api.documentRequests.last, _recoveryId);
}

void main() {
  final desktop = TargetPlatformVariant({TargetPlatform.windows});
  testWidgets(
    'valid lookup clears success/actions on invalid syntax and recovers',
    (tester) async {
      final api = _ScannerApi();
      await _mountScanner(tester, api);
      await _lookUp(tester, _firstId);
      await tester.pumpAndSettle();
      _expectLoaded(tester, _firstTitle);

      await _lookUp(tester, 'NOT-A-QR');
      await tester.pumpAndSettle();
      _expectCleared(tester);
      expect(find.textContaining('Invalid tracking ID.'), findsOneWidget);
      expect(api.documentRequests, [_firstId]);
      expect(api.verifyRequests, isEmpty);
      await _recover(tester, api);
    },
    variant: desktop,
  );

  testWidgets(
    'valid lookup clears success/actions on missing document and recovers',
    (tester) async {
      final api = _ScannerApi();
      await _mountScanner(tester, api);
      await _lookUp(tester, _firstId);
      await tester.pumpAndSettle();
      _expectLoaded(tester, _firstTitle);

      await _lookUp(tester, _missingId);
      await tester.pumpAndSettle();
      _expectCleared(tester);
      expect(find.text('Document not found'), findsOneWidget);
      expect(api.documentRequests, [_firstId, _missingId]);
      await _recover(tester, api);
    },
    variant: desktop,
  );

  testWidgets(
    'rejected signed QR clears success/actions and allows a new lookup',
    (tester) async {
      final api = _ScannerApi();
      await _mountScanner(tester, api);
      await _lookUp(tester, _firstId);
      await tester.pumpAndSettle();
      _expectLoaded(tester, _firstTitle);

      await _lookUp(tester, _rejectedQr);
      await tester.pumpAndSettle();
      _expectCleared(tester);
      expect(find.textContaining('QR signature invalid'), findsOneWidget);
      expect(api.verifyRequests, [_rejectedQr]);
      expect(api.documentRequests, [_firstId]);
      await _recover(tester, api);
    },
    variant: desktop,
  );

  testWidgets(
    'new lookup removes old custody actions while awaiting its result',
    (tester) async {
      final api = _ScannerApi();
      await _mountScanner(tester, api);
      await _lookUp(tester, _firstId);
      await tester.pumpAndSettle();
      _expectLoaded(tester, _firstTitle);

      final pending = Completer<Map<String, dynamic>>();
      api.pendingRecovery = pending;
      await _lookUp(tester, _recoveryId);
      await tester.pump(const Duration(milliseconds: 100));
      _expectCleared(tester);
      final lookupButton = tester.widget<SfPrimaryButton>(
        find.byType(SfPrimaryButton),
      );
      expect(lookupButton.loading, isTrue);
      expect(lookupButton.onPressed, isNull);
      expect(api.documentRequests, [_firstId, _recoveryId]);
      final input = tester.widget<TextField>(find.byType(TextField));
      expect(input.onSubmitted, isNull);

      pending.complete(_ScannerApi.document(_recoveryId, _recoveryTitle));
      await tester.pumpAndSettle();
      _expectLoaded(tester, _recoveryTitle);
      expect(find.text(_firstTitle), findsNothing);
    },
    variant: desktop,
  );
}
