import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartflow/models/user.dart';
import 'package:smartflow/providers/auth_provider.dart';
import 'package:smartflow/screens/staff/clerk_widgets.dart';
import 'package:smartflow/screens/staff/scanner_screen.dart';
import 'package:smartflow/services/api_client.dart';
import 'package:smartflow/services/smartflow_api.dart';
import 'package:smartflow/widgets/sf_motion.dart';

const _id = 'DOC-2026-000741';

class _CameraPlatform extends MobileScannerPlatform {
  final frames = StreamController<BarcodeCapture?>.broadcast();

  @override
  Stream<BarcodeCapture?> get barcodesStream => frames.stream;
  @override
  Stream<TorchState> get torchStateStream => const Stream.empty();
  @override
  Stream<double> get zoomScaleStateStream => const Stream.empty();
  @override
  Widget buildCameraView() => const ColoredBox(color: Colors.black);
  @override
  Future<void> updateScanWindow(Rect? window) async {}
  @override
  Future<MobileScannerViewAttributes> start(StartOptions options) async =>
      const MobileScannerViewAttributes(
        cameraDirection: CameraFacing.back,
        currentTorchMode: TorchState.unavailable,
        size: Size(640, 480),
      );
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
}

class _Auth extends AuthProvider {
  _Auth(this.clientApi);
  final SmartflowApi clientApi;
  @override
  SmartflowApi get api => clientApi;
  @override
  bool get isAuthenticated => true;
  @override
  bool get loading => false;
  @override
  AppUser get user => const AppUser(
    id: 741,
    username: 'synthetic.motion',
    name: 'Synthetic staff',
    role: 'staff',
    officeId: 1,
    officeCode: 'ENG',
    officeName: 'Engineering Office',
  );
}

Future<void> _frames(WidgetTester tester, [int count = 8]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  // The camera plugin finishes some work outside the test clock.
  await tester.runAsync(() async {});
  await tester.pump();
}

Widget _app(Widget child, {bool reduceMotion = false}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduceMotion),
    child: Scaffold(body: child),
  ),
);

double _opacityAbove(WidgetTester tester, Finder child) => tester
    .widget<Opacity>(
      find.ancestor(of: child, matching: find.byType(Opacity)).first,
    )
    .opacity;

void main() {
  setUp(() {
    SfMotion.enabled = true;
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
  });
  tearDown(() => SfMotion.enabled = false);

  group('entrance and route line', () {
    testWidgets('an entrance fades in once and then stays put', (tester) async {
      await tester.pumpWidget(_app(const SfEntrance(child: Text('Stop'))));
      expect(_opacityAbove(tester, find.text('Stop')), lessThan(0.2));
      await tester.pump(const Duration(milliseconds: 400));
      expect(_opacityAbove(tester, find.text('Stop')), 1);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets(
      'later stops wait a moment, but never more than a fraction of a second',
      (tester) async {
        await tester.pumpWidget(
          _app(
            const Column(
              children: [
                SfEntrance(index: 0, child: Text('First')),
                SfEntrance(index: 40, child: Text('Fortieth')),
              ],
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 120));
        expect(_opacityAbove(tester, find.text('First')), greaterThan(0.5));
        expect(_opacityAbove(tester, find.text('Fortieth')), 0);
        // The stagger is capped, so a long list is fully shown well inside a second.
        await tester.pump(const Duration(milliseconds: 700));
        expect(_opacityAbove(tester, find.text('Fortieth')), 1);
        expect(tester.hasRunningAnimations, isFalse);
      },
    );

    testWidgets('a system request for reduced motion skips every animation', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          const Column(
            children: [
              SfEntrance(child: Text('Entrance')),
              SfPop(child: Text('Pop')),
              SfGrowDown(child: SizedBox(width: 2, height: 20)),
              SfCountUp(id: 'reduced', value: 12, style: TextStyle()),
            ],
          ),
          reduceMotion: true,
        ),
      );
      expect(find.byType(Opacity), findsNothing);
      expect(find.byType(TweenAnimationBuilder<double>), findsNothing);
      expect(find.text('12'), findsOneWidget);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('the route line grows from the top and ends full length', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(const SfGrowDown(child: SizedBox(width: 2, height: 40))),
      );
      double yScale() => tester
          .widget<Transform>(
            find.descendant(
              of: find.byType(SfGrowDown),
              matching: find.byType(Transform),
            ),
          )
          .transform
          .entry(1, 1);
      expect(yScale(), lessThan(0.2));
      await tester.pump(const Duration(milliseconds: 500));
      expect(yScale(), 1);
    });
  });

  group('count up', () {
    testWidgets(
      'a loaded number counts up once and a reopened page shows it straight away',
      (tester) async {
        Widget cell() => _app(
          const Row(
            children: [
              SfDashboardStatCell(
                value: '12',
                label: 'Received',
                sublabel: 'today',
                color: Colors.black,
              ),
            ],
          ),
        );
        await tester.pumpWidget(cell());
        expect(
          find.text('12'),
          findsNothing,
          reason: 'it starts below the total',
        );
        await tester.pump(const Duration(milliseconds: 300));
        final partway = int.parse(
          (tester.widget<Text>(find.byType(Text).first).data)!,
        );
        expect(partway, inInclusiveRange(1, 11));
        await tester.pump(const Duration(milliseconds: 800));
        expect(find.text('12'), findsOneWidget);

        // Leave the page and come back: no second count from zero.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(cell());
        expect(find.text('12'), findsOneWidget);
        expect(tester.hasRunningAnimations, isFalse);
      },
    );

    testWidgets('a changed number counts from what was shown', (tester) async {
      Widget cell(String value) => _app(
        Row(
          children: [
            SfDashboardStatCell(
              value: value,
              label: 'On desk',
              sublabel: 'now',
              color: Colors.black,
            ),
          ],
        ),
      );
      await tester.pumpWidget(cell('5'));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('5'), findsOneWidget);
      await tester.pumpWidget(cell('9'));
      await tester.pump(const Duration(milliseconds: 100));
      final shown = int.parse(
        (tester.widget<Text>(find.byType(Text).first).data)!,
      );
      expect(shown, inInclusiveRange(5, 8), reason: 'never restarts at zero');
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('9'), findsOneWidget);
    });

    testWidgets(
      'an unavailable value stays a dash and never counts from zero',
      (tester) async {
        await tester.pumpWidget(
          _app(
            const Row(
              children: [
                SfDashboardStatCell(
                  value: '—',
                  label: 'Received',
                  sublabel: 'today',
                  color: Colors.black,
                ),
              ],
            ),
          ),
        );
        expect(find.text('—'), findsOneWidget);
        expect(find.text('0'), findsNothing);
        expect(tester.hasRunningAnimations, isFalse);
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('0'), findsNothing);
      },
    );

    testWidgets('screen readers get the final number, not each step', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(const SfCountUp(id: 'semantics', value: 30, style: TextStyle())),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.bySemanticsLabel('30'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      handle.dispose();
    });
  });

  group('saved handoff cue', () {
    late MobileScannerPlatform previousPlatform;
    late _CameraPlatform camera;

    setUp(() {
      previousPlatform = MobileScannerPlatform.instance;
      camera = _CameraPlatform();
      MobileScannerPlatform.instance = camera;
      MobileScannerController.resetPlatformSessionOwner();
    });

    tearDown(() async {
      MobileScannerController.resetPlatformSessionOwner();
      MobileScannerPlatform.instance = previousPlatform;
      await camera.frames.close();
    });

    Future<void> receive(WidgetTester tester, {required bool saved}) async {
      tester.view.physicalSize = const Size(900, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = SmartflowApi(
        ApiClient(
          token: 'synthetic-session',
          client: MockClient((request) async {
            final endpoint = request.url.pathSegments.last;
            if (endpoint == 'documents-show.php') {
              return http.Response(
                jsonEncode({
                  'success': true,
                  'document': {
                    'id': _id,
                    'title': 'Synthetic motion folder',
                    'type': 'Others: Controlled folder',
                    'origin_office_name': 'Budget Office',
                    'current_status': 'OUT',
                    'current_office_id': 2,
                    'current_office_name': 'Budget Office',
                    'destination_office_id': 1,
                    'destination_office_name': 'Engineering Office',
                    'last_movement_id': 741,
                    'tray': 'incoming',
                    'folder_inventory': null,
                  },
                }),
                200,
              );
            }
            if (endpoint == 'movement-requests.php') {
              return http.Response(
                '{"success":false,"message":"Synthetic outcome unavailable"}',
                503,
              );
            }
            if (endpoint == 'movements-create.php') {
              return saved
                  ? http.Response(
                      jsonEncode({
                        'success': true,
                        'message': 'Movement recorded',
                        'movement_id': 742,
                      }),
                      201,
                    )
                  : http.Response(
                      jsonEncode({
                        'success': false,
                        'message': 'The document moved since you opened it',
                        'scan_error': 'document_changed',
                      }),
                      409,
                    );
            }
            throw StateError('Unexpected mock request $endpoint');
          }),
        ),
        movementScope: '741_1',
      );
      final auth = _Auth(api);
      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>.value(
          value: auth,
          child: const MaterialApp(home: Scaffold(body: ScannerScreen())),
        ),
      );
      await _frames(tester);
      await tester.enterText(find.byType(TextField), _id);
      await tester.tap(find.text('Look up document'));
      await _frames(tester);
      await tester.ensureVisible(find.text('Receive (IN)'));
      await tester.tap(find.text('Receive (IN)'));
      await _frames(tester);
      await tester.tap(find.byType(CheckboxListTile));
      await _frames(tester);
      await tester.tap(find.text('Confirm receipt'));
      await _frames(tester, 12);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        auth.dispose();
      });
    }

    testWidgets('a check pops in only after the server confirmed the save', (
      tester,
    ) async {
      await receive(tester, saved: true);
      expect(find.text('Saved'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a rejected save shows no check', (tester) async {
      await receive(tester, saved: false);
      expect(find.text('Saved'), findsNothing);
      expect(find.byIcon(Icons.check_circle_rounded), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a folder that was only looked up shows no saved cue', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(900, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = SmartflowApi(
        ApiClient(
          token: 'synthetic-session',
          client: MockClient((request) async {
            if (request.url.pathSegments.last == 'documents-show.php') {
              return http.Response(
                jsonEncode({
                  'success': true,
                  'document': {
                    'id': _id,
                    'title': 'Synthetic motion folder',
                    'type': 'Others: Controlled folder',
                    'current_status': 'IN',
                    'current_office_id': 1,
                    'current_office_name': 'Engineering Office',
                    'last_movement_id': 741,
                  },
                }),
                200,
              );
            }
            throw StateError('Unexpected mock request');
          }),
        ),
        movementScope: '741_1',
      );
      final auth = _Auth(api);
      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>.value(
          value: auth,
          child: const MaterialApp(home: Scaffold(body: ScannerScreen())),
        ),
      );
      await _frames(tester);
      await tester.enterText(find.byType(TextField), _id);
      await tester.tap(find.text('Look up document'));
      await _frames(tester);
      expect(find.text('Look up another'), findsOneWidget);
      expect(find.text('Saved'), findsNothing);
      expect(find.byIcon(Icons.check_circle_rounded), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      auth.dispose();
    });
  });
}
