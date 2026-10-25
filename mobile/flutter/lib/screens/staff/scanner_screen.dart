import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../providers/auth_provider.dart';
import '../../services/api_client.dart';
import '../../theme/sf_icons.dart';
import '../../theme/smartflow_theme.dart';
import '../../utils/recent_docs.dart';
import '../../utils/scan_errors.dart';
import '../../utils/tracking_id.dart';
import '../../widgets/mark_out_destination_dialog.dart';
import '../../widgets/folder_contents.dart';
import '../../widgets/document_summary.dart';
import '../../widgets/document_filing.dart';
import '../../widgets/destination_correction.dart';
import '../../widgets/sf_pdf_chrome.dart';
import '../../widgets/sf_widgets.dart';
import 'clerk_widgets.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final _manualCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final MobileScannerController _cameraCtrl = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );

  Map<String, dynamic>? _doc;
  String? _error;
  bool _loading = false;
  bool _scanPaused = false;
  bool _cameraRetired = false;
  bool _readingImage = false;
  int _cameraGeneration = 0;
  int _imageRequest = 0;
  StreamSubscription<BarcodeCapture>? _cameraSubscription;
  bool _cameraUnavailable = _platformLikelyHasNoCamera;
  String? _lastScanned;
  DateTime? _lastScanAt;
  DateTime? _scanStartedAt;
  String? _activeQrPayload;
  bool _legacyPlainQr = false;
  List<RecentDocRef> _recentIds = const [];
  int _lookupRequest = 0;

  static String _formatScanError(ApiException e) {
    final hint = scanErrorHint(scanError: e.scanError, qrError: e.qrError);
    if (hint == null || hint.isEmpty) return e.message;
    return '${e.message}\n\n$hint';
  }

  static bool get _platformLikelyHasNoCamera {
    if (kIsWeb) return true;
    switch (defaultTargetPlatform) {
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
        return true;
      default:
        return false;
    }
  }

  @override
  void initState() {
    super.initState();
    _cameraCtrl.addListener(_keepRetiredCameraStopped);
    if (!_cameraUnavailable) _listenToCamera();
    _loadRecents();
  }

  Future<void> _loadRecents() async {
    final ids = await RecentDocsStore.load();
    if (mounted) setState(() => _recentIds = ids);
  }

  Future<void> _pasteFromClipboard() async {
    final auth = context.read<AuthProvider>();
    final identity = auth.sessionIdentity;
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted ||
        auth.sessionIdentity != identity ||
        auth.loggingOut ||
        _loading ||
        _readingImage) {
      return;
    }
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Clipboard is empty')));
      }
      return;
    }
    _manualCtrl.text = text;
    if (parseTrackingId(text) != null) {
      _lookup(text, fromCamera: false);
      return;
    }
    if (mounted) {
      setState(() {
        _error = 'That is not a tracking ID.';
      });
    }
  }

  @override
  void dispose() {
    _imageRequest++;
    _cameraGeneration++;
    _manualCtrl.dispose();
    _scrollCtrl.dispose();
    _cameraCtrl.removeListener(_keepRetiredCameraStopped);
    _cameraSubscription?.cancel();
    _cameraCtrl.dispose();
    super.dispose();
  }

  void _markCameraUnavailable() {
    if (_cameraUnavailable) return;
    _cameraUnavailable = true;
    _cameraCtrl.stop();
  }

  void _keepRetiredCameraStopped() {
    // Camera permission/start can finish after the image picker takes ownership.
    if (_cameraRetired && _cameraCtrl.value.isRunning) {
      _cameraCtrl.stop().catchError((Object _) {});
    }
  }

  Future<void> _retireCamera() async {
    _cameraGeneration++;
    _cameraRetired = true;
    final subscription = _cameraSubscription;
    _cameraSubscription = null;
    if (subscription != null) await subscription.cancel();
    if (_cameraUnavailable) return;
    try {
      await _cameraCtrl.stop();
    } catch (_) {
      // Retired callbacks remain blocked even when native camera cleanup fails.
    }
  }

  Future<void> _startCamera() async {
    final auth = context.read<AuthProvider>();
    if (auth.loggingOut) return;
    final identity = auth.sessionIdentity;
    final generation = _cameraGeneration;
    try {
      _listenToCamera();
      await _cameraCtrl.start();
      if (mounted &&
          auth.sessionIdentity == identity &&
          generation == _cameraGeneration &&
          auth.loggingOut) {
        await _retireCamera();
        if (mounted && auth.sessionIdentity == identity) setState(() {});
      }
    } catch (_) {
      if (mounted &&
          auth.sessionIdentity == identity &&
          generation == _cameraGeneration) {
        setState(_markCameraUnavailable);
      }
    }
  }

  void _listenToCamera() {
    final generation = _cameraGeneration;
    _cameraSubscription?.cancel();
    _cameraSubscription = _cameraCtrl.barcodes.listen(
      (capture) =>
          _onQrDetected(capture.barcodes.firstOrNull?.rawValue, generation),
      onError: (Object error, StackTrace stack) {},
    );
  }

  Future<void> _lookup(
    String raw, {
    bool fromCamera = false,
    int? imageRequest,
    bool afterSavedAction = false,
  }) async {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    if ((auth.loggingOut && !afterSavedAction) ||
        (_readingImage && imageRequest != _imageRequest)) {
      return;
    }
    final identity = auth.sessionIdentity;
    final api = auth.api;
    final request = ++_lookupRequest;
    bool current() =>
        mounted &&
        request == _lookupRequest &&
        auth.sessionIdentity == identity;
    final trimmed = raw.trim();
    // A new lookup invalidates the previous success state, including its actions.
    setState(() {
      _doc = null;
      _scanPaused = false;
      _loading = true;
      _scanStartedAt = null;
      _activeQrPayload = null;
      _legacyPlainQr = false;
      _error = null;
    });
    await _retireCamera();
    if (!current()) return;
    if (auth.loggingOut && !afterSavedAction) {
      setState(() => _loading = false);
      return;
    }
    String? id;
    String? qrPayload;
    var legacyPlain = false;

    if (isSignedQrPayload(trimmed)) {
      setState(() {
        _loading = true;
        _error = null;
        _doc = null;
      });
      try {
        final verified = await api.verifyQr(trimmed);
        if (!mounted || !current()) return;
        id = verified['document_id']?.toString();
        qrPayload = trimmed;
      } on ApiException catch (e) {
        if (!mounted || !current()) return;
        setState(() {
          _doc = null;
          _error = _formatScanError(e);
          _loading = false;
          _activeQrPayload = null;
          _legacyPlainQr = false;
        });
        return;
      }
    } else {
      id = parseTrackingId(trimmed);
      if (id == null) {
        setState(() {
          _doc = null;
          _error =
              'Invalid tracking ID. Enter a valid ID or scan the secured QR label.';
          _loading = false;
          _activeQrPayload = null;
          _legacyPlainQr = false;
        });
        return;
      }
      legacyPlain = fromCamera;
      qrPayload = null;
    }

    if (id == null || id.isEmpty) {
      setState(() {
        _doc = null;
        _error = 'Could not read document from QR.';
        _loading = false;
      });
      return;
    }

    _manualCtrl.text = id;
    setState(() {
      _loading = true;
      _error = null;
      _activeQrPayload = qrPayload;
      _legacyPlainQr = legacyPlain && qrPayload == null;
    });

    try {
      final data = await api.documentShow(id);
      if (!mounted || !current()) return;
      final doc = data['document'] as Map<String, dynamic>;
      setState(() {
        _doc = doc;
        _scanPaused = true;
        _scanStartedAt = DateTime.now();
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (current() && _scrollCtrl.hasClients) _scrollCtrl.jumpTo(0);
      });
      final updated = await RecentDocsStore.add(
        id,
        title: doc['title']?.toString(),
      );
      if (current()) setState(() => _recentIds = updated);
    } on ApiException catch (e) {
      if (!mounted || !current()) return;
      setState(() {
        _doc = null;
        _error = _formatScanError(e);
      });
    } finally {
      if (current()) setState(() => _loading = false);
    }
  }

  void _onQrDetected(String? raw, int generation) {
    if (raw == null ||
        raw.isEmpty ||
        _loading ||
        _scanPaused ||
        _readingImage ||
        _cameraRetired ||
        generation != _cameraGeneration) {
      return;
    }

    final now = DateTime.now();
    if (_lastScanned == raw &&
        _lastScanAt != null &&
        now.difference(_lastScanAt!) < const Duration(seconds: 2)) {
      return;
    }

    _lastScanned = raw;
    _lastScanAt = now;
    HapticFeedback.mediumImpact();
    _lookup(raw, fromCamera: true);
  }

  Future<void> _pickQrImage() async {
    if (!mounted || _loading || _readingImage || _doc != null) return;
    final auth = context.read<AuthProvider>();
    if (auth.loggingOut) return;
    final identity = auth.sessionIdentity;
    final request = ++_imageRequest;
    bool current() =>
        mounted && request == _imageRequest && auth.sessionIdentity == identity;
    // Reserve the whole picker/decode/read interval before any native await.
    setState(() {
      _readingImage = true;
      _loading = true;
      _error = null;
    });
    try {
      await _retireCamera();
      if (!current() || auth.loggingOut) return;
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 95,
      );
      if (picked == null || !current() || auth.loggingOut) return;

      final capture = await _cameraCtrl.analyzeImage(picked.path);
      if (!current() || auth.loggingOut) return;

      final raw = capture?.barcodes
          .map((b) => b.rawValue)
          .whereType<String>()
          .firstWhere((v) => v.trim().isNotEmpty, orElse: () => '');

      if (raw == null || raw.isEmpty) {
        setState(() {
          _error =
              'No QR code found in that image. Use a clear photo of the folder label.';
        });
        return;
      }

      HapticFeedback.mediumImpact();
      await _lookup(raw, fromCamera: true, imageRequest: request);
    } catch (_) {
      if (!current()) return;
      setState(() {
        _error =
            'Could not read that image. Try another photo or enter the tracking ID.';
      });
    } finally {
      if (current()) {
        setState(() {
          _readingImage = false;
          _loading = false;
        });
      }
    }
  }

  Future<void> _clearDocument() async {
    if (!mounted || _loading || _readingImage) return;
    final auth = context.read<AuthProvider>();
    if (auth.loggingOut) return;
    _cameraGeneration++;
    _lookupRequest++;
    setState(() {
      _doc = null;
      _error = null;
      _scanPaused = false;
      _cameraRetired = false;
      _scanStartedAt = null;
      _activeQrPayload = null;
      _legacyPlainQr = false;
      _manualCtrl.clear();
    });
    if (!_cameraUnavailable) {
      await _startCamera();
    }
  }

  Future<void> _movement(String status) async {
    final doc = _doc;
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (doc == null ||
        user == null ||
        user.role != 'staff' ||
        auth.loggingOut ||
        _loading ||
        (doc['trail_complete'] == true &&
            doc['can_return_to_accounting'] != true)) {
      return;
    }
    final api = auth.api;
    final identity = auth.sessionIdentity;
    final scanStartedAt = _scanStartedAt;
    final qrPayload = _activeQrPayload;
    bool current() => mounted && auth.sessionIdentity == identity;
    final displayedMovementId = (doc['last_movement_id'] as num?)?.toInt();
    if (displayedMovementId == null &&
        (doc['current_status'] != null || doc['current_office_id'] != null)) {
      setState(
        () => _error =
            'Current movement unavailable. Look up the folder again before recording a handoff.',
      );
      return;
    }

    final actions = clerkScanActions(
      currentStatus: doc['current_status']?.toString(),
      currentOfficeId: doc['current_office_id'] as int?,
      currentOfficeName: doc['current_office_name']?.toString(),
      destinationOfficeId: (doc['destination_office_id'] as num?)?.toInt(),
      destinationOfficeName: doc['destination_office_name']?.toString(),
      myOfficeId: user.officeId,
      lastMovement: null,
    );

    if (status == 'IN' && !actions.canIn) {
      setState(
        () => _error = actions.blockReason ?? 'Cannot mark IN right now',
      );
      return;
    }

    if (status == 'OUT' && !actions.canOut) {
      setState(
        () => _error = actions.blockReason ?? 'Cannot mark OUT right now',
      );
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      MarkOutDestination? destination;
      Map<String, dynamic>? contentsReceipt;
      if (status == 'IN') {
        contentsReceipt = await showFolderReceiptDialog(context, doc);
        if (contentsReceipt?['confirmed'] != true || !mounted || !current()) {
          return;
        }
      }
      if (status == 'OUT') {
        final sf = doc['suggested_forward'] as Map<String, dynamic>?;
        destination = await showMarkOutDestinationDialog(
          context,
          documentId: doc['id'] as String,
          myOfficeId: user.officeId,
          myOfficeName: user.officeName,
          myOfficeCode: user.officeCode,
          documentType: doc['type']?.toString(),
          suggestedOfficeId: sf?['office_id'] as int?,
          suggestedOfficeCode: sf?['office_code']?.toString(),
          suggestedReason: sf?['reason']?.toString(),
          onlyDestinationCode: doc['can_return_to_accounting'] == true
              ? 'ACC'
              : null,
        );
        if (destination == null || !mounted || !current()) return;
      }
      if (!mounted || !current() || auth.loggingOut) return;
      final result = await api.recordMovement(
        documentId: doc['id'] as String,
        officeId: user.officeId,
        status: status,
        movementSource: 'scan',
        expectedMovementId: displayedMovementId ?? 0,
        receiptConfirmed:
            status == 'IN' && contentsReceipt?['confirmed'] == true,
        destinationOfficeId: destination?.officeId,
        scanStartedAt: scanStartedAt,
        qrPayload: qrPayload,
        contentsReceipt: contentsReceipt,
        isReturn: destination?.isReturn ?? false,
        remarks: status == 'IN'
            ? 'Received at ${user.officeName}'
            : destination!.isReturn
            ? destination.returnReason
            : 'Forwarded from ${user.officeName} → ${destination.code}',
      );
      if (!mounted || !current()) return;
      await _lookup(doc['id'] as String, afterSavedAction: true);
      if (!mounted || !current()) return;

      final msg =
          result['message']?.toString() ??
          (status == 'IN'
              ? 'Marked IN · ${doc['id']}'
              : 'Marked OUT · ${doc['id']}');

      HapticFeedback.lightImpact();
      sfShowSuccessSnack(
        context,
        message: msg,
        backgroundColor: status == 'IN' ? SfColors.green : SfColors.blue,
        actionLabel: 'Scan another',
        onAction: () {
          if (current()) _clearDocument();
        },
      );
    } on ApiException catch (e) {
      if (current()) setState(() => _error = _formatScanError(e));
    } finally {
      if (current()) setState(() => _loading = false);
    }
  }

  Future<void> _fileFolder() async {
    final doc = _doc;
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (doc == null ||
        user == null ||
        user.role != 'staff' ||
        auth.loggingOut ||
        _loading ||
        doc['can_file'] != true) {
      return;
    }
    final api = auth.api;
    final identity = auth.sessionIdentity;
    bool current() => mounted && auth.sessionIdentity == identity;
    final expectedMovementId = (doc['last_movement_id'] as num?)?.toInt();
    if (expectedMovementId == null || expectedMovementId <= 0) {
      setState(
        () => _error =
            'Current movement unavailable. Look up the folder again before filing.',
      );
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (!await showDocumentFilingConfirmation(context, doc) ||
          !mounted ||
          !current() ||
          auth.loggingOut) {
        return;
      }
      final result = await api.fileDocument(
        doc['id'].toString(),
        expectedMovementId: expectedMovementId,
      );
      if (!mounted || !current()) return;
      await _lookup(doc['id'] as String, afterSavedAction: true);
      if (!mounted || !current()) return;
      sfShowSuccessSnack(
        context,
        message: result['message']?.toString() ?? 'Filed. This folder is done.',
        backgroundColor: SfColors.green,
      );
    } on ApiException catch (e) {
      if (!mounted || !current()) return;
      if (e.statusCode == 409) {
        await _lookup(doc['id'].toString(), afterSavedAction: true);
      }
      if (current()) setState(() => _error = e.message);
    } finally {
      if (current()) setState(() => _loading = false);
    }
  }

  Widget _buildManualLookup({required bool primary}) {
    return SfFormCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 4,
            children: [
              const Text(
                'Tracking ID',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: SfColors.ink,
                ),
              ),
              TextButton.icon(
                onPressed: _loading ? null : _pasteFromClipboard,
                icon: const Icon(Icons.content_paste_rounded, size: 16),
                label: const Text('Paste'),
                style: TextButton.styleFrom(
                  foregroundColor: SfColors.blue,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(48, 48),
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (primary && _cameraUnavailable) ...[
            const SizedBox(height: 4),
            const Text(
              'Camera is not available on this device. Type the ID from the folder label.',
              style: TextStyle(
                fontSize: 14,
                color: SfColors.muted,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 10),
          TextField(
            controller: _manualCtrl,
            textCapitalization: TextCapitalization.characters,
            autocorrect: false,
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(
              hintText: 'Enter tracking ID',
              border: OutlineInputBorder(),
            ),
            onSubmitted: _loading ? null : _lookup,
          ),
          const SizedBox(height: 12),
          SfPrimaryButton(
            label: _loading ? 'Looking up…' : 'Look up document',
            loading: _loading,
            onPressed: _loading
                ? null
                : () => _lookup(_manualCtrl.text, fromCamera: false),
          ),
          if (_recentIds.isNotEmpty) ...[
            const SizedBox(height: 14),
            SfQuickOpenChips(
              docs: _recentIds,
              enabled: !_loading,
              onOpen: (id) => _lookup(id, fromCamera: false),
              onClear: () async {
                await RecentDocsStore.clear();
                if (mounted) setState(() => _recentIds = const []);
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCameraSection(Map<String, dynamic>? doc) {
    final paused = _scanPaused || _cameraRetired;
    final loaded = doc != null;
    return SfScannerPreviewCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Scan folder QR',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: SfColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: paused
                      ? SfColors.green.withValues(alpha: 0.12)
                      : SfColors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  loaded
                      ? 'Folder loaded'
                      : paused
                      ? 'Camera paused'
                      : 'Camera ready',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: paused ? SfColors.green : SfColors.blue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  height: 240,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      MobileScanner(
                        controller: _cameraCtrl,
                        errorBuilder: (context, error) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) {
                              setState(_markCameraUnavailable);
                            }
                          });
                          return const _CameraUnavailablePanel(compact: true);
                        },
                      ),
                      if (paused)
                        Container(
                          color: const Color(0xFF0A1A33),
                          alignment: Alignment.center,
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.qr_code_scanner_rounded,
                                  color: SfColors.green,
                                  size: 44,
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  doc?['id']?.toString() ??
                                      (_readingImage
                                          ? 'Reading QR image…'
                                          : 'Camera paused'),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  doc?['title']?.toString() ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.7),
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                TextButton(
                                  onPressed: _loading ? null : _clearDocument,
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFFE8D9B5),
                                  ),
                                  child: Text(
                                    loaded ? 'Scan another QR' : 'Use camera',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (!paused) ...[
                  const IgnorePointer(child: _ScanViewfinderFrame()),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: ValueListenableBuilder<MobileScannerState>(
                      valueListenable: _cameraCtrl,
                      builder: (context, state, _) {
                        if (state.torchState == TorchState.unavailable) {
                          return const SizedBox.shrink();
                        }
                        final on = state.torchState == TorchState.on;
                        return Material(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(10),
                          child: IconButton(
                            tooltip: on ? 'Turn off flashlight' : 'Flashlight',
                            icon: Icon(
                              on ? Icons.flash_on : Icons.flash_off_outlined,
                              color: Colors.white,
                              size: 22,
                            ),
                            onPressed: _cameraCtrl.toggleTorch,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            paused
                ? loaded
                      ? 'Review the folder details below.'
                      : 'Use camera when you are ready to scan another label.'
                : 'Align the folder QR inside the corners.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: paused ? SfColors.ink : SfColors.blue,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final doc = _doc;
    final routeFinished =
        doc?['trail_complete'] == true &&
        doc?['can_return_to_accounting'] != true;
    final user = context.read<AuthProvider>().user!;
    final actions = doc == null
        ? null
        : clerkScanActions(
            currentStatus: doc['current_status']?.toString(),
            currentOfficeId: doc['current_office_id'] as int?,
            currentOfficeName: doc['current_office_name']?.toString(),
            destinationOfficeId: (doc['destination_office_id'] as num?)
                ?.toInt(),
            destinationOfficeName: doc['destination_office_name']?.toString(),
            myOfficeId: user.officeId,
            lastMovement: null,
            role: user.role,
          );

    final manualFirst = _cameraUnavailable && !_scanPaused;

    return ListView(
      controller: _scrollCtrl,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
      children: [
        const SfPageTitle(
          title: 'Scan',
          subtitle:
              'Find a folder, review its location, then record the next handoff.',
        ),
        const SizedBox(height: 14),
        if (doc != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _loading ? null : _clearDocument,
              icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
              label: const Text('Look up another'),
            ),
          )
        else
          const SizedBox.shrink(),
        if (manualFirst) ...[
          _buildManualLookup(primary: true),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _loading ? null : _pickQrImage,
              icon: const Icon(Icons.photo_library_outlined, size: 18),
              label: Text(_readingImage ? 'Reading image…' : 'Upload QR image'),
            ),
          ),
        ] else ...[
          if (!_cameraUnavailable)
            Offstage(offstage: doc != null, child: _buildCameraSection(doc)),
          if (doc == null) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _loading ? null : _pickQrImage,
                icon: const Icon(Icons.photo_library_outlined, size: 18),
                label: Text(
                  _readingImage ? 'Reading image…' : 'Upload QR image',
                ),
              ),
            ),
            _buildManualLookup(primary: false),
          ],
        ],
        if (_error != null) ...[
          const SizedBox(height: 12),
          SfErrorBanner(message: _error!),
        ],
        if (doc == null) ...[
          const SizedBox(height: 12),
          const Text(
            'Looking up a folder does not record receipt or forwarding.',
            style: TextStyle(fontSize: 14, color: SfColors.muted, height: 1.4),
          ),
        ],
        if (doc != null && actions != null) ...[
          const SizedBox(height: 8),
          _DocumentCard(
            doc: doc,
            actions: actions,
            routeFinished: routeFinished,
          ),
        ],
        if (_activeQrPayload != null && doc != null) ...[
          const SizedBox(height: 10),
          SfInfoBanner(
            text: user.role == 'staff'
                ? 'QR verified. Review the folder details before recording receipt or forwarding.'
                : 'QR verified. View custody below; office staff record physical handoffs.',
          ),
        ],
        if (_legacyPlainQr && doc != null) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: SfColors.gold.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: SfColors.gold.withValues(alpha: 0.35)),
            ),
            child: const Text(
              'Legacy QR (plain ID). Reprint the secured label from Register or Print QR.',
              style: TextStyle(
                fontSize: 12.5,
                color: SfColors.ink,
                height: 1.45,
              ),
            ),
          ),
        ],
        if (doc != null && actions != null) ...[
          const SizedBox(height: 16),
          if (actions.blockReason != null &&
              !routeFinished &&
              !actions.canIn &&
              !actions.canOut) ...[
            const SizedBox(height: 10),
            if (user.role == 'staff')
              _ScanBlockedCard(reason: actions.blockReason!)
            else
              SfInfoBanner(text: actions.blockReason!),
          ],
          const SizedBox(height: 14),
          DestinationCorrectionAction(
            document: doc,
            disabled: _loading,
            onChanged: () =>
                _lookup(doc['id'].toString(), afterSavedAction: true),
          ),
          DestinationCorrectionHistory(
            corrections: doc['destination_corrections'] as List? ?? [],
          ),
          if (user.role == 'staff' &&
              !routeFinished &&
              (actions.canIn || actions.canOut))
            SfFormCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Next action',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    actions.canIn
                        ? 'Confirm the folder and its actual contents when it arrives.'
                        : doc['can_file'] == true
                        ? 'File completed work, or send this folder to the next office.'
                        : doc['can_return_to_accounting'] == true
                        ? 'The route is complete. An optional return to Accounting is available.'
                        : 'Choose the receiving office before recording the handoff.',
                    style: const TextStyle(
                      fontSize: 14,
                      color: SfColors.muted,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _ActionButtons(
                    loading: _loading,
                    canIn: actions.canIn,
                    canOut: actions.canOut && !routeFinished,
                    outLabel: doc['can_return_to_accounting'] == true
                        ? 'Return to Accounting (OUT)'
                        : 'Send (OUT)',
                    onIn: () => _movement('IN'),
                    onFile: doc['can_file'] == true ? _fileFolder : null,
                    onOut: () => _movement('OUT'),
                  ),
                ],
              ),
            ),
          TextButton.icon(
            onPressed: () => context.push(
              '/${user.role}/history',
              extra: {'documentId': doc['id']},
            ),
            icon: const Icon(Icons.history),
            label: const Text('View custody history'),
          ),
        ],
      ],
    );
  }
}

class _ScanBlockedCard extends StatelessWidget {
  const _ScanBlockedCard({required this.reason});

  final String reason;

  @override
  Widget build(BuildContext context) {
    final forwarded = reason.toLowerCase().contains('forwarded');
    return SfFormCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                forwarded ? Icons.send_rounded : SfIcons.info,
                size: 20,
                color: SfColors.gold,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Receive (IN) / Send (OUT) disabled',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            reason,
            style: const TextStyle(
              fontSize: 12,
              height: 1.45,
              color: SfColors.ink,
            ),
          ),
          if (forwarded) ...[
            const SizedBox(height: 10),
            Text(
              'Next: the receiving office clerk signs in and Marks IN when the folder arrives.',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: SfColors.blue.withValues(alpha: 0.95),
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CameraUnavailablePanel extends StatelessWidget {
  const _CameraUnavailablePanel({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          SfIcons.clerkScan,
          size: compact ? 32 : 40,
          color: compact
              ? Colors.white54
              : SfColors.blue.withValues(alpha: 0.7),
        ),
        SizedBox(height: compact ? 8 : 12),
        Text(
          compact ? 'Camera unavailable' : 'QR scanner needs a phone camera',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: compact ? 12 : 14,
            fontWeight: FontWeight.w700,
            color: compact ? Colors.white70 : SfColors.ink,
          ),
        ),
        if (!compact) ...[
          const SizedBox(height: 6),
          const Text(
            'Use the document ID field above on emulators, desktops, or devices without a camera.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.5,
              color: SfColors.muted,
              height: 1.4,
            ),
          ),
        ],
      ],
    );

    if (compact) {
      return Container(
        color: const Color(0xFF0F172A),
        alignment: Alignment.center,
        child: content,
      );
    }

    return SfScannerPreviewCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: content,
      ),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  const _DocumentCard({
    required this.doc,
    required this.actions,
    required this.routeFinished,
  });

  final Map<String, dynamic> doc;
  final bool routeFinished;
  final ({bool canIn, bool canOut, String statusLine, String? blockReason})
  actions;

  @override
  Widget build(BuildContext context) {
    final isOverdue = doc['is_overdue'] == true;
    final dueDisplay = doc['due_at_display']?.toString();

    return SfFormCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Document details',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: SfColors.muted,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            doc['title']?.toString() ?? 'Untitled folder',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontSize: 22, height: 1.3),
          ),
          const SizedBox(height: 6),
          SelectableText(
            doc['id']?.toString() ?? '',
            style: const TextStyle(fontSize: 14, color: SfColors.muted),
          ),
          const SizedBox(height: 12),
          Text(
            actions.statusLine,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              DocumentStatus(document: doc),
              if (doc['trail_complete'] == true && !routeFinished)
                const SfStatusPill(
                  label: 'Route complete',
                  tone: SfPillTone.success,
                ),
              if (isOverdue)
                const SfStatusPill(label: 'Overdue', tone: SfPillTone.danger),
            ],
          ),
          if (routeFinished) ...[
            const SizedBox(height: 10),
            const SfInfoBanner(text: 'Route complete.'),
          ],
          const SizedBox(height: 8),
          if (doc['current_status'] == 'OUT')
            _row(
              'Destination',
              doc['destination_office_name'] ?? 'Unspecified office',
            ),
          if (dueDisplay != null && dueDisplay != '—')
            _row('Deadline', dueDisplay),
          const Divider(height: 24, color: SfColors.border),
          _row('Type', doc['type']),
          _row('Origin', doc['origin_office_name']),
          FolderContentsSummary(document: doc),
          if (context.read<AuthProvider>().user?.role == 'staff' &&
              !(doc['trail_complete'] == true &&
                  doc['can_return_to_accounting'] != true) &&
              (doc['pilot_end_note']?.toString() ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            SfInfoBanner(text: doc['pilot_end_note'].toString().trim()),
          ],
          if (doc['suggested_forward'] is Map) ...[
            Builder(
              builder: (context) {
                final sf = doc['suggested_forward'] as Map;
                final reason = sf['reason']?.toString();
                final code = sf['office_code']?.toString();
                if (reason == null || reason.isEmpty) {
                  return const SizedBox.shrink();
                }
                final label = code != null && code.isNotEmpty
                    ? 'Next: $code — $reason'
                    : reason;
                return Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                      color: SfColors.blue.withValues(alpha: 0.95),
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(String k, dynamic v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final label = Text(
          k,
          style: const TextStyle(color: SfColors.muted, fontSize: 14),
        );
        final value = Text(
          '${v ?? '—'}',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            height: 1.4,
          ),
        );
        if (constraints.maxWidth < 300 ||
            MediaQuery.textScalerOf(context).scale(14) > 20) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [label, const SizedBox(height: 2), value],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 100, child: label),
            const SizedBox(width: 10),
            Expanded(child: value),
          ],
        );
      },
    ),
  );
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({
    required this.loading,
    required this.canIn,
    required this.canOut,
    required this.onIn,
    required this.onOut,
    this.outLabel = 'Send (OUT)',
    this.onFile,
  });

  final bool loading;
  final bool canIn;
  final bool canOut;
  final String outLabel;
  final VoidCallback? onFile;
  final VoidCallback onIn;
  final VoidCallback onOut;

  @override
  Widget build(BuildContext context) {
    // One primary action: whichever custody step is available.
    if (canIn && !canOut) {
      return SfPrimaryButton(
        label: loading ? 'Recording…' : 'Receive (IN)',
        loading: loading,
        onPressed: loading ? null : onIn,
      );
    }
    if (canOut && !canIn) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (onFile != null) ...[
            SfPrimaryButton(
              label: loading ? 'Filing…' : 'File this folder',
              loading: loading,
              onPressed: loading ? null : onFile,
            ),
            const SizedBox(height: 10),
          ],
          onFile != null
              ? SfSecondaryOutlineButton(
                  label: loading ? 'Sending…' : outLabel,
                  onPressed: loading ? null : onOut,
                )
              : SfPrimaryButton(
                  label: loading ? 'Sending…' : outLabel,
                  loading: loading,
                  onPressed: loading ? null : onOut,
                ),
        ],
      );
    }
    if (canIn && canOut) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SfPrimaryButton(
            label: loading ? 'Recording…' : 'Receive (IN)',
            loading: loading,
            onPressed: loading ? null : onIn,
          ),
          const SizedBox(height: 10),
          SfSecondaryOutlineButton(
            label: loading ? 'Sending…' : outLabel,
            onPressed: loading ? null : onOut,
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }
}

/// Corner-bracket viewfinder — clearer than a full rectangle border.
class _ScanViewfinderFrame extends StatelessWidget {
  const _ScanViewfinderFrame();

  @override
  Widget build(BuildContext context) {
    const size = 188.0;
    const len = 28.0;
    const thick = 3.0;
    const color = Color(0xFFE8D9B5);

    Widget corner(Alignment align) {
      final top = align.y < 0;
      final left = align.x < 0;
      return Align(
        alignment: align,
        child: SizedBox(
          width: len,
          height: len,
          child: CustomPaint(
            painter: _CornerPainter(
              color: color,
              thickness: thick,
              top: top,
              left: left,
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          corner(Alignment.topLeft),
          corner(Alignment.topRight),
          corner(Alignment.bottomLeft),
          corner(Alignment.bottomRight),
        ],
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  _CornerPainter({
    required this.color,
    required this.thickness,
    required this.top,
    required this.left,
  });

  final Color color;
  final double thickness;
  final bool top;
  final bool left;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;
    final path = Path();
    if (top && left) {
      path.moveTo(0, size.height);
      path.lineTo(0, 0);
      path.lineTo(size.width, 0);
    } else if (top && !left) {
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width, size.height);
    } else if (!top && left) {
      path.moveTo(0, 0);
      path.lineTo(0, size.height);
      path.lineTo(size.width, size.height);
    } else {
      path.moveTo(size.width, 0);
      path.lineTo(size.width, size.height);
      path.lineTo(0, size.height);
    }
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant _CornerPainter oldDelegate) =>
      color != oldDelegate.color ||
      thickness != oldDelegate.thickness ||
      top != oldDelegate.top ||
      left != oldDelegate.left;
}
