import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/office_document_types.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_client.dart';
import '../../utils/api_error.dart';
import '../../theme/smartflow_theme.dart';
import '../../widgets/sf_pdf_chrome.dart';
import '../../widgets/sf_qr_display.dart';
import '../../widgets/sf_widgets.dart';
import '../head/head_widgets.dart';
import '../staff/clerk_widgets.dart';

/// Register a new financial document at the user's office (staff, head, admin).
class DocumentRegisterScreen extends StatefulWidget {
  const DocumentRegisterScreen({super.key, required this.homeRoute});

  /// Where to go after success (e.g. `/staff` or `/head`).
  final String homeRoute;

  @override
  State<DocumentRegisterScreen> createState() => _DocumentRegisterScreenState();
}

class _DocumentRegisterScreenState extends State<DocumentRegisterScreen> {
  final _titleCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  final _payeeCtrl = TextEditingController();
  final _fundCtrl = TextEditingController();
  final _titleFocus = FocusNode();
  late String _type;
  DateTime? _dueDate;
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _created;

  bool get _canSubmit =>
      !_loading && _titleCtrl.text.trim().length >= 3;

  bool get _formDirty =>
      _titleCtrl.text.trim().isNotEmpty ||
      _refCtrl.text.trim().isNotEmpty ||
      _payeeCtrl.text.trim().isNotEmpty ||
      _fundCtrl.text.trim().isNotEmpty ||
      _dueDate != null;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user!;
    final types = documentTypesForOffice(user.officeCode);
    _type = types.isNotEmpty ? types.first : 'Disbursement Voucher';
    _titleCtrl.addListener(_onFormChanged);
    _refCtrl.addListener(_onFormChanged);
  }

  void _onFormChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _titleCtrl
      ..removeListener(_onFormChanged)
      ..dispose();
    _refCtrl
      ..removeListener(_onFormChanged)
      ..dispose();
    _payeeCtrl.dispose();
    _fundCtrl.dispose();
    _titleFocus.dispose();
    super.dispose();
  }

  String? _dueAtPayload() {
    if (_dueDate == null) return null;
    final d = _dueDate!;
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 2)),
      helpText: 'Target completion date',
    );
    if (picked != null && mounted) {
      setState(() => _dueDate = picked);
    }
  }

  void _clearForm() {
    final types =
        documentTypesForOffice(context.read<AuthProvider>().user!.officeCode);
    _titleCtrl.clear();
    _refCtrl.clear();
    _payeeCtrl.clear();
    _fundCtrl.clear();
    setState(() {
      _type = types.isNotEmpty ? types.first : _type;
      _dueDate = null;
      _error = null;
    });
    _titleFocus.requestFocus();
  }

  void _registerAnother() {
    setState(() => _created = null);
    _clearForm();
  }

  Future<List<Map<String, dynamic>>> _checkDuplicates(String reference) async {
    if (reference.isEmpty) return const [];
    try {
      final res =
          await context.read<AuthProvider>().api.findByReference(reference);
      final list = res['matches'] as List<dynamic>? ?? const [];
      return list
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<bool> _confirmDuplicate(
    String reference,
    List<Map<String, dynamic>> matches,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Reference already used'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '“$reference” was used by ${matches.length == 1 ? 'this document' : 'these documents'}:',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 10),
            ...matches.map(
              (m) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '• ${m['id']} · ${m['type']} · ${m['origin_office_code']}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Register a new tracking ID anyway, or cancel and verify first.',
              style: TextStyle(
                fontSize: 12,
                color: SfColors.muted,
                height: 1.4,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Register anyway'),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _submit() async {
    final user = context.read<AuthProvider>().user!;
    final title = _titleCtrl.text.trim();
    if (title.length < 3) {
      setState(() => _error = 'Enter at least 3 characters for the document title.');
      _titleFocus.requestFocus();
      return;
    }

    final ref = _refCtrl.text.trim();

    setState(() {
      _loading = true;
      _error = null;
    });

    if (ref.isNotEmpty) {
      final matches = await _checkDuplicates(ref);
      if (matches.isNotEmpty) {
        if (!mounted) return;
        final proceed = await _confirmDuplicate(ref, matches);
        if (!proceed) {
          if (mounted) setState(() => _loading = false);
          return;
        }
      }
    }

    if (!mounted) return;
    try {
      final data = await context.read<AuthProvider>().api.createDocument(
            title: title,
            type: _type,
            originOfficeId: user.officeId,
            dueAt: _dueAtPayload(),
            referenceNo: ref.isEmpty ? null : ref,
            payee: _payeeCtrl.text.trim().isEmpty
                ? null
                : _payeeCtrl.text.trim(),
            fundSource: _fundCtrl.text.trim().isEmpty
                ? null
                : _fundCtrl.text.trim(),
          );
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() {
        _created = data['document'] as Map<String, dynamic>?;
        _loading = false;
      });
      final id = _created?['id']?.toString();
      if (mounted) {
        sfShowSuccessSnack(
          context,
          message: id != null && id.isNotEmpty
              ? 'Registered $id — print the QR label'
              : 'Document registered — print the QR label',
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = apiErrorMessage(e);
          _loading = false;
        });
      }
    }
  }

  void _copyId(String id) {
    Clipboard.setData(ClipboardData(text: id));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tracking ID copied')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user!;
    final types = documentTypesForOffice(user.officeCode);
    final created = _created;
    final isHead = widget.homeRoute == '/head';

    if (types.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          const SfClerkTabTitle(
            title: 'Register',
            subtitle: 'Physical folder registration',
            screen: SfClerkScreen.register,
          ),
          const SizedBox(height: 24),
          const SfEmptyState(
            icon: Icons.folder_off_outlined,
            title: 'No document types for your office',
            subtitle: 'Pilot offices only — ENG, BUD, ACC, TRE, and MAY.',
          ),
        ],
      );
    }

    if (created != null) {
      return _SuccessView(
        created: created,
        user: user,
        homeRoute: widget.homeRoute,
        isHead: isHead,
        onCopyId: _copyId,
        onRegisterAnother: _registerAnother,
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        if (isHead) ...[
          const SfAuthenticatedPageHeader(),
          const SizedBox(height: 12),
          const SfHeadPageOverviewCard(screen: SfHeadScreen.register),
          const SizedBox(height: 14),
        ] else ...[
          const SfClerkTabTitle(
            title: 'Register',
            screen: SfClerkScreen.register,
          ),
          const SizedBox(height: 10),
          _RegisterGuidanceCard(officeCode: user.officeCode),
          const SizedBox(height: 12),
        ],
        SfFormCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Text(
                    'Origin office',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: SfColors.muted,
                    ),
                  ),
                  const Spacer(),
                  SfDeptBadge(
                    label: user.officeName,
                    officeCode: user.officeCode,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Document title',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: SfColors.muted,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _titleCtrl,
                focusNode: _titleFocus,
                autofocus: true,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'e.g. Disbursement Voucher - Road Repair Phase 1',
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => _canSubmit ? _submit() : null,
              ),
              const SizedBox(height: 14),
              const Text(
                'Document type',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: SfColors.muted,
                ),
              ),
              const SizedBox(height: 8),
              if (types.length == 1)
                InputDecorator(
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                  child: Text(
                    types.first,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: SfColors.ink,
                    ),
                  ),
                )
              else
                InputDecorator(
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: types.contains(_type) ? _type : types.first,
                      isExpanded: true,
                      isDense: true,
                      items: types
                          .map(
                            (t) => DropdownMenuItem(
                              value: t,
                              child: Text(t),
                            ),
                          )
                          .toList(),
                      onChanged: _loading
                          ? null
                          : (v) {
                              if (v != null) setState(() => _type = v);
                            },
                    ),
                  ),
                ),
              const SizedBox(height: 14),
              const Text(
                'Logbook fields (optional)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: SfColors.muted,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Mirror municipal logbook — reference, payee, fund source.',
                style: TextStyle(fontSize: 11, color: SfColors.muted, height: 1.35),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _refCtrl,
                decoration: const InputDecoration(
                  labelText: 'Reference / DV no.',
                  hintText: 'LGU reference number',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _payeeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Payee',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _fundCtrl,
                decoration: const InputDecoration(
                  labelText: 'Fund source',
                  hintText: 'e.g. MOOE, PS',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 14),
              _DueDateField(
                dueDate: _dueDate,
                onPick: _pickDueDate,
                onClear: () => setState(() => _dueDate = null),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                SfErrorBanner(message: _error!),
              ],
              const SizedBox(height: 16),
              SfPrimaryButton(
                label: _loading ? 'Registering…' : 'Register & get QR ID',
                loading: _loading,
                onPressed: _canSubmit ? _submit : null,
              ),
              if (_formDirty && !_loading) ...[
                const SizedBox(height: 4),
                Center(
                  child: SfGhostTextButton(
                    label: 'Clear form',
                    onPressed: _clearForm,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Collapsible office tips (Register vs Request).
class _RegisterGuidanceCard extends StatelessWidget {
  const _RegisterGuidanceCard({required this.officeCode});

  final String officeCode;

  @override
  Widget build(BuildContext context) {
    final code = officeCode.toUpperCase();
    final String body;

    switch (code) {
      case 'ENG':
        body =
            'Register your DV packet here. If you asked Budget for a file, use Document request — then Scan IN when it arrives (do not register as DV).';
        break;
      case 'BUD':
        body =
            'After approving a budget request, register Approved Budget, then OUT → ACC.';
        break;
      case 'HR':
        body =
            'Physical payroll folders are not registered in Phase 1. Accounting prepares payroll; HR supports plantilla.';
        break;
      case 'ACC':
        body =
            'After supporting-doc check, Mark OUT → Treasury. Do not treat Scan IN as payment approval.';
        break;
      case 'TRE':
        body =
            'Scan IN from Accounting, then OUT → Mayor. After Mayor returns the folder, Scan IN and release the check.';
        break;
      case 'MAY':
        body =
            'Scan IN when Treasury delivers the DV. After signature, Mark OUT back to Treasury.';
        break;
      default:
        body =
            'Folder must be on your desk. To ask another office for files, use Document requests first.';
    }

    return Material(
      color: SfColors.paper,
      borderRadius: BorderRadius.circular(12),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          title: const Text(
            'Tips for your office',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          subtitle: const Text(
            'Tap if unsure when to register',
            style: TextStyle(fontSize: 11, color: SfColors.muted),
          ),
          children: [
            Text(
              body,
              style: const TextStyle(
                fontSize: 12,
                color: SfColors.muted,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DueDateField extends StatelessWidget {
  const _DueDateField({
    required this.dueDate,
    required this.onPick,
    required this.onClear,
  });

  final DateTime? dueDate;
  final VoidCallback onPick;
  final VoidCallback onClear;

  static String _format(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Target due date (optional)',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: SfColors.muted,
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: onPick,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            alignment: Alignment.centerLeft,
          ),
          child: Row(
            children: [
              const Icon(Icons.event_outlined, size: 20, color: SfColors.blue),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  dueDate == null
                      ? 'Pick a date — or leave blank for pilot thresholds'
                      : _format(dueDate!),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        dueDate == null ? FontWeight.w500 : FontWeight.w700,
                    color: dueDate == null ? SfColors.muted : SfColors.ink,
                  ),
                ),
              ),
              if (dueDate != null)
                IconButton(
                  tooltip: 'Clear due date',
                  onPressed: onClear,
                  icon: const Icon(Icons.close, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SuccessView extends StatelessWidget {
  const _SuccessView({
    required this.created,
    required this.user,
    required this.homeRoute,
    required this.isHead,
    required this.onCopyId,
    required this.onRegisterAnother,
  });

  final Map<String, dynamic> created;
  final AppUser user;
  final String homeRoute;
  final bool isHead;
  final void Function(String id) onCopyId;
  final VoidCallback onRegisterAnother;

  @override
  Widget build(BuildContext context) {
    final id = created['id']?.toString() ?? '';
    final qrPayload =
        created['qr_payload']?.toString().trim().isNotEmpty == true
            ? created['qr_payload']!.toString().trim()
            : id;
    final qrExpires = created['qr_expires_at']?.toString();
    final initialIn = created['initial_in_recorded'] == true;
    final dueDisplay = created['due_at_display']?.toString();
    final token = context.read<AuthProvider>().token;
    final labelUrl = context.read<AuthProvider>().api.qrLabelUrl(
          id,
          token: token,
        );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        SfAuthenticatedPageHeader(
          fallbackRoute: homeRoute,
          hideBackOnRoleHome: false,
        ),
        const SizedBox(height: 12),
        isHead
            ? SfHeadPageOverviewCard(
                screen: SfHeadScreen.registerSuccess,
                documentId: id,
              )
            : SfClerkPageOverviewCard(
                screen: SfClerkScreen.registerSuccess,
                documentId: id,
              ),
        const SizedBox(height: 14),
        SfFormCard(
          child: Column(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: SfColors.green.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: SfColors.green,
                  size: 30,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                id,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                initialIn
                    ? 'Registered at ${user.officeName} and marked IN at your desk.'
                    : isHead
                        ? 'Registered at ${user.officeName}. Assign a clerk to attach the QR and scan handoffs.'
                        : 'Registered at ${user.officeName}. Scan IN on the Scanner tab when the folder is ready.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: SfColors.muted,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Print this secured QR on the folder label',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: SfColors.muted,
          ),
        ),
        if (qrExpires != null && qrExpires.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            'Signed label · valid until ${_shortQrExpiry(qrExpires)}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: SfColors.muted),
          ),
        ],
        const SizedBox(height: 12),
        SfQrDisplay(payload: qrPayload),
        const SizedBox(height: 14),
        SfFormCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _successRow('Title', created['title']),
              _successRow('Type', created['type']),
              _successRow('Origin', user.officeName),
              if (dueDisplay != null && dueDisplay.isNotEmpty)
                _successRow('Due', dueDisplay),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _RegisterNextStepsCard(isHead: isHead),
        const SizedBox(height: 14),
        if (!isHead) ...[
          SfPrimaryButton(
            label: 'Open Scanner',
            onPressed: () => context.go('/staff/scan'),
          ),
          const SizedBox(height: 10),
          SfSecondaryOutlineButton(
            label: 'Register another document',
            onPressed: onRegisterAnother,
          ),
        ] else ...[
          SfPrimaryButton(
            label: 'Register another document',
            onPressed: onRegisterAnother,
          ),
        ],
        const SizedBox(height: 6),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 4,
          children: [
            SfGhostTextButton(
              label: 'Copy ID',
              onPressed: () => onCopyId(id),
            ),
            SfGhostTextButton(
              label: 'Copy print link',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: labelUrl));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Print link copied — open in Chrome on a PC to print the label.',
                    ),
                    duration: Duration(seconds: 4),
                  ),
                );
              },
            ),
            SfGhostTextButton(
              label: 'Back to Home',
              onPressed: () => context.go(homeRoute),
            ),
          ],
        ),
      ],
    );
  }

  Widget _successRow(String k, dynamic v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 88,
              child: Text(
                k,
                style: const TextStyle(fontSize: 12, color: SfColors.muted),
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

class _RegisterNextStepsCard extends StatelessWidget {
  const _RegisterNextStepsCard({this.isHead = false});

  final bool isHead;

  @override
  Widget build(BuildContext context) {
    return SfFormCard(
      flat: true,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Do these next',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
          ),
          const SizedBox(height: 4),
          const Text(
            'Print → attach → Scan OUT when the folder leaves your desk.',
            style: TextStyle(fontSize: 11.5, color: SfColors.muted, height: 1.35),
          ),
          const SizedBox(height: 12),
          _step('1', 'Print & attach the QR label'),
          const SizedBox(height: 8),
          _step(
            '2',
            isHead
                ? 'Staff: Mark OUT on Scanner when forwarding'
                : 'Mark OUT on Scanner when you forward',
          ),
          const SizedBox(height: 8),
          _step('3', 'Next office Marks IN on arrival'),
        ],
      ),
    );
  }

  Widget _step(String n, String text) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: SfColors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              n,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: SfColors.blue,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, height: 1.4),
            ),
          ),
        ],
      );
}

String _shortQrExpiry(String iso) {
  try {
    final d = DateTime.parse(iso).toLocal();
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  } catch (_) {
    return iso.length > 10 ? iso.substring(0, 10) : iso;
  }
}
