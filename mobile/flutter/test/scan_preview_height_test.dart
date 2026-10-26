import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartflow/models/user.dart';
import 'package:smartflow/providers/auth_provider.dart';
import 'package:smartflow/screens/staff/scanner_screen.dart';
import 'package:smartflow/services/api_client.dart';
import 'package:smartflow/services/smartflow_api.dart';
import 'package:smartflow/theme/smartflow_theme.dart';

class _Api extends SmartflowApi {
  _Api() : super(ApiClient());
}

class _Auth extends AuthProvider {
  _Auth(this.fixture);
  final _Api fixture;

  @override
  SmartflowApi get api => fixture;

  @override
  AppUser get user => const AppUser(
    id: 702,
    name: 'Preview fixture clerk',
    username: 'preview.fixture',
    role: 'staff',
    officeId: 1,
    officeCode: 'ENG',
    officeName: 'Engineering Office',
  );
}

void main() {
  test('the preview shrinks on phone-sized screens and stays within 176 to 240', () {
    expect(scanPreviewHeight(500), 176);
    expect(scanPreviewHeight(640), 176);
    expect(scanPreviewHeight(892), closeTo(196.24, 0.01));
    expect(scanPreviewHeight(1000), closeTo(220, 0.01));
    expect(scanPreviewHeight(1090), closeTo(239.8, 0.01));
    expect(scanPreviewHeight(1400), 240);
    expect(scanPreviewHeight(3000), 240);
  });

  for (final height in [640.0, 892.0, 1200.0]) {
    testWidgets('the camera preview on a ${height.toInt()}dp-tall screen follows the rule', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final fontDownloads = GoogleFonts.config.allowRuntimeFetching;
      GoogleFonts.config.allowRuntimeFetching = false;
      // An Android phone shows the camera card; desktop platforms start on manual lookup.
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() {
        GoogleFonts.config.allowRuntimeFetching = fontDownloads;
        debugDefaultTargetPlatformOverride = null;
      });
      tester.view.physicalSize = Size(412, height);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => _Auth(_Api()),
          child: MaterialApp(
            theme: buildSmartflowTheme(),
            home: const Scaffold(body: ScannerScreen()),
          ),
        ),
      );
      // The camera plugin is absent in tests; look before it reports the camera as unavailable.
      final preview = find.ancestor(
        of: find.byType(MobileScanner),
        matching: find.byType(SizedBox),
      );
      expect(preview, findsWidgets);
      expect(
        tester.getSize(preview.first).height,
        closeTo(scanPreviewHeight(height), 0.01),
      );
      expect(tester.takeException(), isNull);
      // Flutter checks foundation overrides before tear-down callbacks run.
      debugDefaultTargetPlatformOverride = null;
    });
  }
}
