import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/api_client.dart';
import '../../theme/sf_icons.dart';
import '../../theme/smartflow_theme.dart';
import '../../utils/recent_docs.dart';
import '../../utils/scan_errors.dart';
import '../../utils/tracking_id.dart';
import '../../widgets/mark_out_destination_dialog.dart';
import '../../widgets/sf_pdf_chrome.dart';
import '../../widgets/sf_widgets.dart';
import '../admin/admin_widgets.dart';
import '../head/head_widgets.dart';
import 'clerk_widgets.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final _manualCtrl = TextEditingController();
  final MobileScannerController _cameraCtrl = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );

  Map<String, dynamic>? _doc;
  String? _error;
  bool _loading = false;
  bool _scanPaused = false;
  bool _cameraUnavailable = _platformLikelyHasNoCamera;
  String? _lastScanned;
  DateTime? _lastScanAt;
  DateTime? _scanStartedAt;
  String? _activeQrPayload;
  bool _legacyPlainQr = false;
  List<String> _recentIds = const [];

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
    _loadRecents();
  }

  Future<void> _loadRecents() async {
    final ids = await RecentDocsStore.load();
    if (mounted) setState(() => _recentIds = ids);
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Clipboard is empty')),
        );
      }
      return;
    }
    _manualCtrl.text = text;
    if (parseTrackingId(text) != null) {
      _lookup(text, fromCamera: false);
    }
  }

  @override
  void dispose() {
    _manualCtrl.dispose();
    _cameraCtrl.dispose();
    super.dispose();
  }

  void _markCameraUnavailable() {
    if (_cameraUnavailable) return;
    _cameraUnavailable = true;
    _cameraCtrl.stop();
  }

  Future<void> _lookup(String raw, {bool fromCamera = false}) async {
    final trimmed = raw.trim();
    final api = context.read<AuthProvider>().api;
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
        id = verified['document_id']?.toString();
        qrPayload = trimmed;
      } on ApiException catch (e) {
        if (!mounted) return;
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
      if (!mounted) return;
      setState(() {
        _doc = data['document'] as Map<String, dynamic>;
        _scanPaused = true;
        _scanStartedAt = DateTime.now();
      });
      if (!_cameraUnavailable) {
        await _cameraCtrl.stop();
      }
      final updated = await RecentDocsStore.add(id);
      if (mounted) setState(() => _recentIds = updated);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _doc = null;
        _error = _formatScanError(e);
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onQrDetected(String? raw) {
    if (raw == null || raw.isEmpty || _loading) return;

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
    if (_loading || _scanPaused) return;
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 95,
      );
      if (picked == null || !mounted) return;

      setState(() {
        _loading = true;
        _error = null;
      });

      final capture = await _cameraCtrl.analyzeImage(picked.path);
      if (!mounted) return;

      final raw = capture?.barcodes
          .map((b) => b.rawValue)
          .whereType<String>()
          .firstWhere((v) => v.trim().isNotEmpty, orElse: () => '');

      if (raw == null || raw.isEmpty) {
        setState(() {
          _loading = false;
          _error =
              'No QR code found in that image. Use a clear photo of the folder label.';
        });
        return;
      }

      setState(() => _loading = false);
      HapticFeedback.mediumImpact();
      await _lookup(raw, fromCamera: true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error =
            'Could not read that image. Try another photo or enter the tracking ID.';
      });
    }
  }

  void _clearDocument() {
    setState(() {
      _doc = null;
      _error = null;
      _scanPaused = false;
      _scanStartedAt = null;
      _activeQrPayload = null;
      _legacyPlainQr = false;
      _manualCtrl.clear();
    });
    if (!_cameraUnavailable) {
      _cameraCtrl.start();
    }
  }

  Future<void> _movement(String status) async {
    final doc = _doc;
    final user = context.read<AuthProvider>().user;
    if (doc == null || user == null) return;

    final actions = clerkScanActions(
      currentStatus: doc['current_status']?.toString(),
      currentOfficeId: doc['current_office_id'] as int?,
      currentOfficeName: doc['current_office_name']?.toString(),
      myOfficeId: user.officeId,
      lastMovement: null,
    );

    if (status == 'IN' && !actions.canIn) {
      setState(
          () => _error = actions.blockReason ?? 'Cannot mark IN right now');
      return;
    }

    if (status == 'OUT' && !actions.canOut) {
      setState(
          () => _error = actions.blockReason ?? 'Cannot mark OUT right now');
      return;
    }

    MarkOutDestination? destination;
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
      );
      if (destination == null || !mounted) return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await context.read<AuthProvider>().api.recordMovement(
            documentId: doc['id'] as String,
            officeId: user.officeId,
            status: status,
            destinationOfficeId: destination?.officeId,
            scanStartedAt: _scanStartedAt,
            qrPayload: _activeQrPayload,
            remarks: status == 'IN'
                ? 'Received at ${user.officeName}'
                : 'Forwarded from ${user.officeName} → ${destination!.code}',
          );

      await _lookup(doc['id'] as String, fromCamera: false);
      if (!mounted) return;

      final msg = result['message']?.toString() ??
          (status == 'IN'
              ? 'Marked IN · ${doc['id']}'
              : 'Marked OUT · ${doc['id']}');

      HapticFeedback.lightImpact();
      sfShowSuccessSnack(
        context,
        message: msg,
        backgroundColor: status == 'IN' ? SfColors.green : SfColors.blue,
        actionLabel: 'Scan another',
        onAction: _clearDocument,
      );
    } on ApiException catch (e) {
      setState(() => _error = _formatScanError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildManualLookup({required bool primary}) {
    return SfFormCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  primary
                      ? 'Enter document ID'
                      : 'Or enter document ID manually',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: primary ? SfColors.ink : SfColors.muted,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _loading ? null : _pasteFromClipboard,
                icon: const Icon(Icons.content_paste_rounded, size: 16),
                label: const Text('Paste'),
                style: TextButton.styleFrom(
                  foregroundColor: SfColors.blue,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 32),
                  textStyle: const TextStyle(
                    fontSize: 11,
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
              style: TextStyle(fontSize: 11.5, color: SfColors.muted, height: 1.4),
            ),
          ],
          const SizedBox(height: 10),
          TextField(
            controller: _manualCtrl,
            textCapitalization: TextCapitalization.characters,
            autocorrect: false,
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
            onPressed:
                _loading ? null : () => _lookup(_manualCtrl.text, fromCamera: false),
          ),
          if (_recentIds.isNotEmpty) ...[
            const SizedBox(height: 14),
            _RecentIdChips(
              ids: _recentIds,
              loading: _loading,
              onTap: _lookup,
              onClearAll: () async {
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
    final paused = _scanPaused;
    return SfScannerPreviewCard(
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: paused
                      ? SfColors.green.withValues(alpha: 0.12)
                      : SfColors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  paused ? 'DOCUMENT LOADED' : 'LIVE SCAN',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: paused ? SfColors.green : SfColors.blue,
                  ),
                ),
              ),
              const Spacer(),
              if (!paused)
                TextButton.icon(
                  onPressed: _loading ? null : _pickQrImage,
                  icon: const Icon(Icons.photo_library_outlined, size: 18),
                  label: const Text('Upload QR'),
                  style: TextButton.styleFrom(
                    foregroundColor: SfColors.blue,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    visualDensity: VisualDensity.compact,
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              else
                Text(
                  'Ready to mark custody',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: SfColors.muted,
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
                  child: paused
                      ? Container(
                          color: const Color(0xFF0A1A33),
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.check_circle_rounded,
                                color: SfColors.green,
                                size: 44,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                doc?['id']?.toString() ?? 'Document loaded',
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
                                onPressed: _clearDocument,
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFFE8D9B5),
                                ),
                                child: const Text('Scan another QR'),
                              ),
                            ],
                          ),
                        )
                      : MobileScanner(
                          controller: _cameraCtrl,
                          errorBuilder: (context, error, child) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) {
                                setState(_markCameraUnavailable);
                              }
                            });
                            return const _CameraUnavailablePanel(compact: true);
                          },
                          onDetect: (capture) {
                            _onQrDetected(
                              capture.barcodes.firstOrNull?.rawValue,
                            );
                          },
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
                ? 'Review details below, then Mark IN or Mark OUT.'
                : 'Align the folder QR inside the corners.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
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
    final user = context.read<AuthProvider>().user!;
    final actions = doc == null
        ? null
        : clerkScanActions(
            currentStatus: doc['current_status']?.toString(),
            currentOfficeId: doc['current_office_id'] as int?,
            currentOfficeName: doc['current_office_name']?.toString(),
            myOfficeId: user.officeId,
            lastMovement: null,
          );

    final manualFirst = _cameraUnavailable && !_scanPaused;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        if (user.role == 'admin')
          const SfAdminPageOverviewCard(
            screen: SfAdminScreen.scan,
            compact: true,
          )
        else if (user.role == 'head')
          const SfHeadPageOverviewCard(
            screen: SfHeadScreen.scan,
            compact: true,
          )
        else
          const SfClerkTabTitle(
            screen: SfClerkScreen.scan,
          ),
        const SizedBox(height: 14),
        if (manualFirst) ...[
          _buildManualLookup(primary: true),
          const SizedBox(height: 14),
          const _CameraUnavailablePanel(compact: false),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _loading ? null : _pickQrImage,
            icon: const Icon(Icons.photo_library_outlined, size: 18),
            label: const Text('Upload QR image'),
          ),
        ] else ...[
          _buildCameraSection(doc),
          const SizedBox(height: 14),
          _buildManualLookup(primary: false),
        ],
        if (_error != null) ...[
          const SizedBox(height: 12),
          SfErrorBanner(message: _error!),
        ],
        if (_activeQrPayload != null && doc != null) ...[
          const SizedBox(height: 10),
          const SfInfoBanner(
            text:
                'Secured QR verified — signature and expiry checked by server.',
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
              style: TextStyle(fontSize: 12.5, color: SfColors.ink, height: 1.45),
            ),
          ),
        ],
        if (doc != null && actions != null) ...[
          const SizedBox(height: 16),
          _DocumentCard(doc: doc, actions: actions),
          if (actions.blockReason != null &&
              !actions.canIn &&
              !actions.canOut) ...[
            const SizedBox(height: 10),
            _ScanBlockedCard(reason: actions.blockReason!),
          ],
          const SizedBox(height: 14),
          _ActionButtons(
            loading: _loading,
            canIn: actions.canIn,
            canOut: actions.canOut,
            onIn: () => _movement('IN'),
            onOut: () => _movement('OUT'),
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
                  'Mark IN / OUT disabled',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            reason,
            style: const TextStyle(fontSize: 12, height: 1.45, color: SfColors.ink),
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
          color: compact ? Colors.white54 : SfColors.blue.withValues(alpha: 0.7),
        ),
        SizedBox(height: compact ? 8 : 12),
        Text(
          compact
              ? 'Camera unavailable'
              : 'QR scanner needs a phone camera',
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
            style: TextStyle(fontSize: 11.5, color: SfColors.muted, height: 1.4),
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
  });

  final Map<String, dynamic> doc;
  final ({
    bool canIn,
    bool canOut,
    String statusLine,
    String? blockReason
  }) actions;

  @override
  Widget build(BuildContext context) {
    final isOverdue = doc['is_overdue'] == true;
    final dueDisplay = doc['due_at_display']?.toString();

    return SfFormCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Document details',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
              if (isOverdue)
                const SfStatusPill(label: 'Overdue', tone: SfPillTone.danger),
            ],
          ),
          const SizedBox(height: 12),
          _row('Document ID', doc['id']),
          _row('Title', doc['title']),
          _row('Type', doc['type']),
          _row('Origin', doc['origin_office_name']),
          _row('Current', actions.statusLine),
          if (dueDisplay != null && dueDisplay != '—') _row('Due', dueDisplay),
          if ((doc['pilot_end_note']?.toString() ?? '').trim().isNotEmpty) ...[
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
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 100,
              child: Text(
                k,
                style: const TextStyle(color: SfColors.muted, fontSize: 12),
              ),
            ),
            Expanded(
              child: Text(
                '$v',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
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
  });

  final bool loading;
  final bool canIn;
  final bool canOut;
  final VoidCallback onIn;
  final VoidCallback onOut;

  @override
  Widget build(BuildContext context) {
    // One primary action: whichever custody step is available.
    if (canIn && !canOut) {
      return SfPrimaryButton(
        label: loading ? 'Recording…' : 'Mark IN',
        loading: loading,
        onPressed: loading ? null : onIn,
      );
    }
    if (canOut && !canIn) {
      return SfPrimaryButton(
        label: loading ? 'Recording…' : 'Mark OUT',
        loading: loading,
        onPressed: loading ? null : onOut,
      );
    }
    if (canIn && canOut) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SfPrimaryButton(
            label: loading ? 'Recording…' : 'Mark IN',
            loading: loading,
            onPressed: loading ? null : onIn,
          ),
          const SizedBox(height: 10),
          SfSecondaryOutlineButton(
            label: loading ? 'Recording…' : 'Mark OUT',
            onPressed: loading ? null : onOut,
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }
}

class _RecentIdChips extends StatelessWidget {
  const _RecentIdChips({
    required this.ids,
    required this.loading,
    required this.onTap,
    required this.onClearAll,
  });

  final List<String> ids;
  final bool loading;
  final ValueChanged<String> onTap;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Quick open',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: SfColors.ink,
                ),
              ),
            ),
            TextButton(
              onPressed: loading ? null : onClearAll,
              style: TextButton.styleFrom(
                foregroundColor: SfColors.muted,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                minimumSize: const Size(0, 28),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Clear',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: ids.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final id = ids[i];
              return Material(
                color: SfColors.paper,
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  onTap: loading ? null : () => onTap(id),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: SfColors.blue.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Text(
                      id,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: SfColors.blue,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Corner-bracket viewfinder � clearer than a full rectangle border.
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
