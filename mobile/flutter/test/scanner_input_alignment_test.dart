import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
// The plugin's public platform seam keeps these widget tests off native devices.
// ignore: depend_on_referenced_packages
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartflow/models/user.dart';
import 'package:smartflow/providers/auth_provider.dart';
import 'package:smartflow/screens/staff/scanner_screen.dart';
import 'package:smartflow/services/api_client.dart';
import 'package:smartflow/services/smartflow_api.dart';

const _cameraId = 'DOC-2026-000731';
const _imageId = 'DOC-2026-000732';

BarcodeCapture _capture(String id) => BarcodeCapture(
  barcodes: [Barcode(rawValue: id, format: BarcodeFormat.qrCode)],
);

class _CameraPlatform extends MobileScannerPlatform {
  final frames = StreamController<BarcodeCapture?>.broadcast();
  final events = <String>[];
  Completer<BarcodeCapture?>? decoding;
  Completer<MobileScannerViewAttributes>? starting;
  Completer<void>? stopping;

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
  Future<MobileScannerViewAttributes> start(StartOptions options) async {
    events.add('start');
    if (starting != null) return starting!.future;
    return const MobileScannerViewAttributes(
      cameraDirection: CameraFacing.back,
      currentTorchMode: TorchState.unavailable,
      size: Size(640, 480),
    );
  }

  @override
  Future<void> stop() async {
    events.add('stop');
    await stopping?.future;
  }

  @override
  Future<void> dispose() async {}
  @override
  Future<BarcodeCapture?> analyzeImage(
    String path, {
    List<BarcodeFormat> formats = const [],
  }) async {
    events.add('decode');
    return decoding?.future ?? _capture(_imageId);
  }
}

class _PickerPlatform extends ImagePickerPlatform {
  _PickerPlatform(this.pick);
  final Future<XFile?> Function() pick;
  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) => pick();
}

class _InputApi extends SmartflowApi {
  _InputApi() : super(ApiClient());
  final reads = <String>[];
  final writes = <String>[];
  Map<String, dynamic> fields = {};
  Completer<Map<String, dynamic>>? detail;

  @override
  Future<Map<String, dynamic>> documentShow(String id) async {
    reads.add(id);
    if (detail != null) return detail!.future;
    return document(id);
  }

  Map<String, dynamic> document(String id) => {
    'document': {
      'id': id,
      'title': id == _imageId ? 'Selected image folder' : 'Camera folder',
      'type': 'Others: Controlled folder',
      'current_status': 'IN',
      'current_office_id': 1,
      'current_office_name': 'Engineering Office',
      'last_movement_id': 731,
      ...fields,
    },
  };

  @override
  Future<Map<String, dynamic>> fileDocument(
    String id, {
    int? expectedMovementId,
  }) async {
    writes.add('file');
    throw StateError('Lookup must never file a folder');
  }

  @override
  Future<Map<String, dynamic>> recordMovement({
    required String documentId,
    required int officeId,
    required String status,
    String? remarks,
    int? destinationOfficeId,
    DateTime? scanStartedAt,
    String? qrPayload,
    bool isReturn = false,
    String? movementSource,
    required int expectedMovementId,
    bool receiptConfirmed = false,
    Map<String, dynamic>? contentsReceipt,
  }) async {
    writes.add(status);
    throw StateError('Lookup must never record a handoff');
  }
}

class _InputAuth extends AuthProvider {
  _InputAuth(this.inputApi, {this.role = 'staff'});
  final _InputApi inputApi;
  final String role;
  String loginKey = 'synthetic-first-login';
  bool pendingLogout = false;
  @override
  SmartflowApi get api => inputApi;
  @override
  bool get isAuthenticated => true;
  @override
  bool get loading => false;
  @override
  bool get loggingOut => pendingLogout;
  @override
  Object get sessionIdentity => (loginKey, user.id, user.officeId, user.role);
  @override
  AppUser get user => AppUser(
    id: 731,
    username: 'synthetic.scan',
    name: 'Synthetic scanner staff',
    role: role,
    officeId: 1,
    officeCode: 'ENG',
    officeName: 'Engineering Office',
  );
}

Future<void> _frames(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.runAsync(() async {});
  await tester.pump();
}

Future<void> _mount(WidgetTester tester, _InputAuth auth) async {
  tester.view.physicalSize = const Size(900, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ChangeNotifierProvider<AuthProvider>.value(
      value: auth,
      child: const MaterialApp(home: Scaffold(body: ScannerScreen())),
    ),
  );
  await _frames(tester);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MobileScannerPlatform previousPlatform;
  late ImagePickerPlatform previousPicker;
  late _CameraPlatform camera;
  late Completer<String?> selected;
  late int pickerCalls;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
    previousPlatform = MobileScannerPlatform.instance;
    previousPicker = ImagePickerPlatform.instance;
    camera = _CameraPlatform();
    MobileScannerPlatform.instance = camera;
    MobileScannerController.resetPlatformSessionOwner();
    selected = Completer<String?>();
    pickerCalls = 0;
    ImagePickerPlatform.instance = _PickerPlatform(() async {
      pickerCalls++;
      camera.events.add('picker');
      final path = await selected.future;
      return path == null ? null : XFile(path);
    });
  });
  tearDown(() async {
    ImagePickerPlatform.instance = previousPicker;
    MobileScannerController.resetPlatformSessionOwner();
    MobileScannerPlatform.instance = previousPlatform;
    await camera.frames.close();
  });

  testWidgets(
    'gallery owns picker, decoding and detail lookup against retired camera and input callbacks',
    (tester) async {
      final api = _InputApi()..detail = Completer<Map<String, dynamic>>();
      final auth = _InputAuth(api);
      await _mount(tester, auth);
      void detect(BarcodeCapture capture) => camera.frames.add(capture);
      final upload = tester
          .widget<TextButton>(
            find.widgetWithText(TextButton, 'Upload QR image'),
          )
          .onPressed!;
      final submit = tester
          .widget<TextField>(find.byType(TextField))
          .onSubmitted!;
      camera.decoding = Completer<BarcodeCapture?>();

      upload();
      await _frames(tester);
      expect(camera.events, ['start', 'stop', 'picker']);
      detect(_capture(_cameraId));
      submit(_cameraId);
      upload();
      await _frames(tester);
      expect(pickerCalls, 1);
      expect(api.reads, isEmpty);

      selected.complete('synthetic-qr.png');
      await _frames(tester);
      expect(camera.events.last, 'decode');
      detect(_capture(_cameraId));
      submit(_cameraId);
      await _frames(tester);
      expect(api.reads, isEmpty);
      camera.decoding!.complete(_capture(_imageId));
      await _frames(tester);
      expect(api.reads, [_imageId]);
      detect(_capture(_cameraId));
      submit(_cameraId);
      await _frames(tester);
      expect(api.reads, [_imageId]);
      api.detail!.complete(api.document(_imageId));
      await _frames(tester);
      expect(find.text('Selected image folder'), findsWidgets);
      expect(find.text('Camera folder'), findsNothing);
      expect(api.writes, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      auth.dispose();
    },
    variant: TargetPlatformVariant({TargetPlatform.android}),
  );

  for (final outcome in ['cancel', 'empty', 'decode error']) {
    testWidgets(
      '$outcome leaves camera stopped until explicit restart and retires the old callback',
      (tester) async {
        final api = _InputApi();
        final auth = _InputAuth(api);
        await _mount(tester, auth);
        void detect(BarcodeCapture capture) => camera.frames.add(capture);
        camera.decoding = Completer<BarcodeCapture?>();
        await tester.tap(find.text('Upload QR image'));
        await _frames(tester);
        selected.complete(outcome == 'cancel' ? null : 'synthetic-empty.png');
        await _frames(tester);
        if (outcome == 'empty') {
          camera.decoding!.complete(const BarcodeCapture());
        }
        if (outcome == 'decode error') {
          camera.decoding!.completeError(StateError('Synthetic decode error'));
        }
        await _frames(tester);
        detect(_capture(_cameraId));
        await _frames(tester);
        expect(api.reads, isEmpty);
        expect(camera.events.where((e) => e == 'start').length, 1);
        expect(find.text('Use camera'), findsOneWidget);
        await tester.tap(find.text('Use camera'));
        await _frames(tester);
        expect(camera.events.where((e) => e == 'start').length, 2);
        camera.frames.add(_capture(_cameraId));
        await _frames(tester);
        expect(api.reads, [_cameraId]);
        expect(find.text('Camera folder'), findsWidgets);
        expect(api.writes, isEmpty);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        auth.dispose();
      },
      variant: TargetPlatformVariant({TargetPlatform.android}),
    );
  }

  for (final stage in ['picker', 'decode', 'detail']) {
    testWidgets(
      'a replaced login cannot publish or dispatch an old gallery $stage result',
      (tester) async {
        final api = _InputApi()..detail = Completer<Map<String, dynamic>>();
        final auth = _InputAuth(api);
        await _mount(tester, auth);
        camera.decoding = Completer<BarcodeCapture?>();
        await tester.tap(find.text('Upload QR image'));
        await _frames(tester);
        if (stage != 'picker') {
          selected.complete('synthetic-qr.png');
          await _frames(tester);
        }
        if (stage == 'detail') {
          camera.decoding!.complete(_capture(_imageId));
          await _frames(tester);
          expect(api.reads, [_imageId]);
        }
        auth.loginKey = 'synthetic-replacement-login';
        if (stage == 'picker') selected.complete('synthetic-qr.png');
        if (stage == 'decode') camera.decoding!.complete(_capture(_imageId));
        if (stage == 'detail') api.detail!.complete(api.document(_imageId));
        await _frames(tester);
        expect(find.text('Selected image folder'), findsNothing);
        expect(api.reads, stage == 'detail' ? [_imageId] : isEmpty);
        if (stage == 'picker') {
          expect(camera.events.contains('decode'), isFalse);
        }
        expect(api.writes, isEmpty);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        auth.dispose();
      },
      variant: TargetPlatformVariant({TargetPlatform.android}),
    );
  }

  testWidgets(
    'retiring a still-starting camera stops its late permission result before gallery lookup',
    (tester) async {
      camera.starting = Completer<MobileScannerViewAttributes>();
      final api = _InputApi();
      final auth = _InputAuth(api);
      await _mount(tester, auth);
      await tester.tap(find.text('Upload QR image'));
      await _frames(tester);
      camera.starting!.complete(
        const MobileScannerViewAttributes(
          cameraDirection: CameraFacing.back,
          currentTorchMode: TorchState.unavailable,
          size: Size(640, 480),
        ),
      );
      await _frames(tester);
      expect(camera.events, ['start', 'picker', 'stop']);
      camera.frames.add(_capture(_cameraId));
      selected.complete('synthetic-qr.png');
      await _frames(tester);
      expect(api.reads, [_imageId]);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      auth.dispose();
    },
    variant: TargetPlatformVariant({TargetPlatform.android}),
  );

  testWidgets(
    'logout starting during camera retirement cancels a new lookup and clears its busy state',
    (tester) async {
      final api = _InputApi();
      final auth = _InputAuth(api);
      await _mount(tester, auth);
      camera.stopping = Completer<void>();
      await tester.enterText(find.byType(TextField), _imageId);
      await tester.tap(find.text('Look up document'));
      await _frames(tester);
      auth.pendingLogout = true;
      camera.stopping!.complete();
      await _frames(tester);
      expect(api.reads, isEmpty);
      expect(find.text('Looking up…'), findsNothing);
      auth.pendingLogout = false;
      await tester.tap(find.text('Look up document'));
      await _frames(tester);
      expect(api.reads, [_imageId]);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      auth.dispose();
    },
    variant: TargetPlatformVariant({TargetPlatform.android}),
  );

  testWidgets(
    'native debug initialization finishes its forced stop before initial start and camera restart keeps the same widget',
    (tester) async {
      // Exercise the installed plugin's MethodChannel implementation, including
      // its debug-only forced stop that public platform fakes do not execute.
      MobileScannerPlatform.instance = previousPlatform;
      const methods = MethodChannel(
        'dev.steenbakker.mobile_scanner/scanner/method',
      );
      const events = MethodChannel(
        'dev.steenbakker.mobile_scanner/scanner/event',
      );
      const orientation = MethodChannel(
        'dev.steenbakker.mobile_scanner/scanner/deviceOrientation',
      );
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final initialStop = Completer<void>();
      final calls = <String>[];
      var nativeRunning = false;
      messenger.setMockMethodCallHandler(methods, (call) async {
        if (call.method == 'state') return 1;
        if (call.method == 'updateScanWindow') return null;
        if (call.method == 'stop') {
          final force = (call.arguments as Map?)?['force'] == true;
          calls.add(force ? 'force-stop' : 'stop');
          if (force) await initialStop.future;
          nativeRunning = false;
          return null;
        }
        if (call.method == 'start') {
          calls.add('start');
          nativeRunning = true;
          return {
            'textureId': 7,
            'cameraDirection': CameraFacing.back.rawValue,
            'currentTorchState': -1,
            'handlesCropAndRotation': true,
            'naturalDeviceOrientation': 'PORTRAIT_UP',
            'sensorOrientation': 90,
            'size': {'width': 640.0, 'height': 480.0},
          };
        }
        throw StateError('Unexpected scanner method ${call.method}');
      });
      messenger.setMockMethodCallHandler(events, (_) async => null);
      messenger.setMockMethodCallHandler(orientation, (_) async => null);
      addTearDown(() {
        messenger.setMockMethodCallHandler(methods, null);
        messenger.setMockMethodCallHandler(events, null);
        messenger.setMockMethodCallHandler(orientation, null);
      });
      final api = _InputApi();
      final auth = _InputAuth(api);
      await _mount(tester, auth);
      expect(calls, ['force-stop']);
      expect(nativeRunning, isFalse);
      initialStop.complete();
      await _frames(tester);
      expect(calls, ['force-stop', 'start']);
      expect(nativeRunning, isTrue);
      final captureElement = tester.element(find.byType(MobileScanner));
      await tester.tap(find.text('Upload QR image'));
      await _frames(tester);
      selected.complete(null);
      await _frames(tester);
      expect(calls, ['force-stop', 'start', 'stop']);
      await tester.tap(find.text('Use camera'));
      await _frames(tester);
      expect(tester.element(find.byType(MobileScanner)), same(captureElement));
      expect(calls, ['force-stop', 'start', 'stop', 'start']);
      expect(nativeRunning, isTrue);
      expect(
        tester
            .widget<MobileScanner>(find.byType(MobileScanner))
            .controller!
            .value
            .isRunning,
        isTrue,
      );
      await tester.enterText(find.byType(TextField), _imageId);
      await tester.tap(find.text('Look up document'));
      await _frames(tester);
      expect(api.reads, [_imageId]);
      expect(
        tester.element(find.byType(MobileScanner, skipOffstage: false)),
        same(captureElement),
      );
      expect(calls, ['force-stop', 'start', 'stop', 'start', 'stop']);
      expect(nativeRunning, isFalse);
      await tester.tap(find.text('Look up another'));
      await _frames(tester);
      expect(tester.element(find.byType(MobileScanner)), same(captureElement));
      expect(calls, ['force-stop', 'start', 'stop', 'start', 'stop', 'start']);
      expect(nativeRunning, isTrue);
      expect(api.writes, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await _frames(tester);
      auth.dispose();
    },
    variant: TargetPlatformVariant({TargetPlatform.android}),
  );

  for (final stage in ['picker', 'decode']) {
    for (final leave in [false, true]) {
      testWidgets(
        '${leave ? 'disposing' : 'pending logout during'} gallery $stage prevents dispatch and remains lifecycle safe',
        (tester) async {
          final api = _InputApi();
          final auth = _InputAuth(api);
          await _mount(tester, auth);
          camera.decoding = Completer<BarcodeCapture?>();
          await tester.tap(find.text('Upload QR image'));
          await _frames(tester);
          if (stage == 'decode') {
            selected.complete('synthetic-qr.png');
            await _frames(tester);
            expect(camera.events.last, 'decode');
          }
          if (leave) {
            await tester.pumpWidget(const SizedBox.shrink());
          } else {
            auth.pendingLogout = true;
          }
          if (stage == 'picker') selected.complete('synthetic-qr.png');
          if (stage == 'decode') camera.decoding!.complete(_capture(_imageId));
          await _frames(tester);
          expect(api.reads, isEmpty);
          expect(api.writes, isEmpty);
          if (!leave) {
            expect(find.text('Looking up…'), findsNothing);
            auth.pendingLogout = false;
            await tester.enterText(find.byType(TextField), _imageId);
            await tester.tap(find.text('Look up document'));
            await _frames(tester);
            expect(api.reads, [_imageId]);
            await tester.pumpWidget(const SizedBox.shrink());
          }
          expect(tester.takeException(), isNull);
          auth.dispose();
        },
        variant: TargetPlatformVariant({TargetPlatform.android}),
      );
    }
  }

  for (final role in ['staff', 'head', 'admin']) {
    for (final returnAllowed in [false, true]) {
      for (final heldHere in [false, true]) {
        testWidgets(
          '$role completed Scan return=$returnAllowed heldHere=$heldHere keeps completion and custody authority distinct',
          (tester) async {
            final api = _InputApi()
              ..fields = {
                'trail_complete': true,
                'can_return_to_accounting': returnAllowed,
                'current_office_id': heldHere ? 1 : 2,
                'current_office_name': heldHere
                    ? 'Engineering Office'
                    : 'Treasury Office',
                'type': returnAllowed
                    ? 'Disbursement Voucher'
                    : 'Others: Filed folder',
              };
            final auth = _InputAuth(api, role: role);
            await _mount(tester, auth);
            await tester.enterText(find.byType(TextField), _imageId);
            await tester.tap(find.text('Look up document'));
            await _frames(tester);
            expect(
              find.text('Filed. The route is finished.'),
              returnAllowed ? findsNothing : findsOneWidget,
            );
            if (!returnAllowed) {
              expect(find.textContaining('They must mark OUT'), findsNothing);
              expect(find.text('Receive (IN)'), findsNothing);
              expect(find.text('Send (OUT)'), findsNothing);
            }
            expect(
              find.text('Return to Accounting (OUT)'),
              role == 'staff' && returnAllowed && heldHere
                  ? findsOneWidget
                  : findsNothing,
            );
            expect(api.writes, isEmpty);
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox.shrink());
            auth.dispose();
          },
          variant: TargetPlatformVariant({TargetPlatform.windows}),
        );
      }
    }
  }
}
