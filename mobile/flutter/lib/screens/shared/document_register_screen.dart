import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../widgets/creation_recovery.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/office_document_types.dart';
import '../../utils/printable_label.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_client.dart';
import '../../services/smartflow_api.dart';
import '../../utils/api_error.dart';
import '../../theme/smartflow_theme.dart';
import '../../widgets/sf_pdf_chrome.dart';
import '../../widgets/document_qr_card.dart';
import '../../widgets/document_summary.dart';
import '../../widgets/folder_contents.dart';
import '../../widgets/folder_checklists.dart';
import '../../widgets/sf_widgets.dart';
import '../admin/admin_widgets.dart';
import '../head/head_widgets.dart';
import '../staff/clerk_widgets.dart';

/// Register an unlabelled physical folder held by the staff member's office.
class DocumentRegisterScreen extends StatefulWidget {
  const DocumentRegisterScreen({
    super.key,
    required this.homeRoute,
    this.request,
  });

  /// Where to go after success (e.g. `/staff` or `/head`).
  final String homeRoute;
  final Map<String, dynamic>? request;

  @override
  State<DocumentRegisterScreen> createState() => _DocumentRegisterScreenState();
}

class _DocumentRegisterScreenState extends State<DocumentRegisterScreen>
    with WidgetsBindingObserver {
  late final AuthProvider _auth;
  late final Object _identity;
  late final SmartflowApi _api;
  late final AppUser _user;
  bool get _current => mounted && _auth.sessionIdentity == _identity;
  late final String _draftKey;
  bool _draftReady = false;
  bool _applyingDraft = false;
  Timer? _draftTimer;
  Future<void> _draftWrites = Future.value();
  String? _draftNote;
  Map<String, dynamic>? _inventoryDraft;
  final _titleCtrl = TextEditingController();
  final _otherCtrl = TextEditingController();
  final _commentCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  final _payeeCtrl = TextEditingController();
  final _fundCtrl = TextEditingController();
  final _inventoryKey = GlobalKey<FolderInventoryEditorState>();
  final _fieldFocus = {
    for (final field in [
      'title',
      'other',
      'sender',
      'reference',
      'payee',
      'fund',
    ])
      field: FocusNode(),
  };
  Map<String, String> _fieldErrors = {};
  bool _validated = false;
  late String _type;
  late String _officeCode;
  DateTime? _dueDate;
  int? _receivedFromOfficeId;
  List<Map<String, dynamic>> _offices = const [];
  String? _officeError;
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _created;

  bool get _isDv => _type == 'Disbursement Voucher';
  bool get _needsReference => _isDv || _type == 'Approved Budget';

  /// Accounting does not originate project DVs — it only registers DVs that arrived without a QR.
  bool get _needsReceivedFrom => _isDv && _officeCode == 'ACC';

  bool get _canSubmit => !_loading;

  Map<String, String> _validationErrors() => {
    if (_titleCtrl.text.trim().runes.length < 3 ||
        _titleCtrl.text.trim().runes.length > 200)
      'title': 'Enter a title between 3 and 200 characters.',
    if (_type == kOtherDocumentType && _otherCtrl.text.trim().length < 3)
      'other': 'Name the folder with at least 3 characters.',
    if (_needsReceivedFrom && _receivedFromOfficeId == null)
      'sender': 'Choose the office that sent this folder.',
    if (_needsReference && _refCtrl.text.trim().isEmpty)
      'reference': 'Enter the reference number from the logbook.',
    if (_isDv && _payeeCtrl.text.trim().isEmpty) 'payee': 'Enter the payee.',
    if (_isDv && _fundCtrl.text.trim().isEmpty)
      'fund': 'Enter the fund source.',
  };

  bool get _formDirty =>
      _titleCtrl.text.trim().isNotEmpty ||
      _otherCtrl.text.trim().isNotEmpty ||
      _commentCtrl.text.trim().isNotEmpty ||
      _refCtrl.text.trim().isNotEmpty ||
      _payeeCtrl.text.trim().isNotEmpty ||
      _fundCtrl.text.trim().isNotEmpty ||
      _dueDate != null ||
      _receivedFromOfficeId != null ||
      _type != documentTypesForOffice(_officeCode).first ||
      (folderItems(_inventoryDraft).length > 1 ||
          '${folderItems(_inventoryDraft).firstOrNull?['pages'] ?? ''}'
              .isNotEmpty) ||
      (_inventoryKey.currentState?.dirty ?? false);

  @override
  void initState() {
    super.initState();
    _auth = context.read<AuthProvider>();
    _identity = _auth.sessionIdentity;
    _api = _auth.api;
    final user = _user = _auth.user!;
    _draftKey =
        'sf_registration_draft_v1_${user.id}_${user.officeId}${widget.request == null ? '' : '_request_${widget.request!['id']}'}';
    WidgetsBinding.instance.addObserver(this);
    _officeCode = user.officeCode.toUpperCase();
    final types = documentTypesForOffice(user.officeCode);
    _type = types.isNotEmpty ? types.first : 'Disbursement Voucher';
    if (widget.request case final request?) {
      final requestedType = switch (request['document_category']) {
        'budget' => 'Approved Budget',
        'disbursement' => 'Disbursement Voucher',
        _ => kOtherDocumentType,
      };
      if (types.contains(requestedType)) _type = requestedType;
      final purpose = '${request['purpose'] ?? ''}';
      _titleCtrl.text = String.fromCharCodes(purpose.runes.take(200));
      _commentCtrl.text =
          'For request ${request['request_code'] ?? request['id']}\n\n$purpose';
      _dueDate = DateTime.tryParse('${request['required_by'] ?? ''}');
    }
    _titleCtrl.addListener(_onFormChanged);
    _otherCtrl.addListener(_onFormChanged);
    _commentCtrl.addListener(_onFormChanged);
    _refCtrl.addListener(_onFormChanged);
    _payeeCtrl.addListener(_onFormChanged);
    _fundCtrl.addListener(_onFormChanged);
    if (_officeCode == 'ACC') {
      _loadOffices(user.officeId);
    }
    _restoreDraft();
  }

  Future<void> _restoreDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_draftKey);
      if (!mounted) return;
      if (raw != null && (!_formDirty || widget.request != null)) {
        final value = jsonDecode(raw) as Map<String, dynamic>;
        final contents = value['inventory'] as Map<String, dynamic>?;
        // Validate the stored row shape before scheduling a restore on the next frame.
        if (contents != null) folderItems(contents);
        _applyingDraft = true;
        final types = documentTypesForOffice(_officeCode);
        if (types.contains(value['type'])) _type = value['type'] as String;
        for (final entry in {
          'title': _titleCtrl,
          'other': _otherCtrl,
          'comment': _commentCtrl,
          'reference': _refCtrl,
          'payee': _payeeCtrl,
          'fund': _fundCtrl,
        }.entries) {
          entry.value.text = '${value[entry.key] ?? ''}';
        }
        _dueDate = DateTime.tryParse('${value['due'] ?? ''}');
        _receivedFromOfficeId = (value['sender'] as num?)?.toInt();
        _inventoryDraft = contents;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && contents != null) {
            _inventoryKey.currentState?.restore(contents);
          }
        });
        _draftNote =
            'Draft restored. Recheck the actual contents and physical confirmation.';
      }
    } catch (_) {
      _draftNote =
          'Draft could not be restored. Registration is still available.';
    } finally {
      _applyingDraft = false;
      _draftReady = true;
      if (mounted) {
        setState(() {});
        if (_formDirty && _draftNote == null) _saveDraft();
      }
    }
  }

  void _saveDraft({bool remove = false}) {
    _draftTimer?.cancel();
    if (!_draftReady || _applyingDraft || _created != null) return;
    final payload = remove || !_formDirty
        ? null
        : jsonEncode({
            'title': _titleCtrl.text,
            'other': _otherCtrl.text,
            'comment': _commentCtrl.text,
            'reference': _refCtrl.text,
            'payee': _payeeCtrl.text,
            'fund': _fundCtrl.text,
            'type': _type,
            'due': _dueDate?.toIso8601String(),
            'sender': _receivedFromOfficeId,
            'inventory': _inventoryKey.currentState?.draft ?? _inventoryDraft,
          });
    _draftWrites = _draftWrites.then((_) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final saved = payload == null
            ? await prefs.remove(_draftKey)
            : await prefs.setString(_draftKey, payload);
        if (mounted) {
          setState(
            () => _draftNote = saved && payload != null
                ? 'Draft saved on this phone.'
                : saved
                ? null
                : 'Draft saving unavailable. Keep this form open.',
          );
        }
      } catch (_) {
        if (mounted) {
          setState(
            () => _draftNote = 'Draft saving unavailable. Keep this form open.',
          );
        }
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _saveDraft();
  }

  Future<void> _loadOffices(int myOfficeId) async {
    try {
      final list = await _api.offices();
      if (!_current) return;
      setState(() {
        _officeError = null;
        _offices = list
            .where((o) => (o['id'] as num?)?.toInt() != myOfficeId)
            .toList(growable: false);
      });
    } catch (error) {
      if (_current) setState(() => _officeError = apiErrorMessage(error));
    }
  }

  void _onFormChanged() {
    if (_applyingDraft) return;
    _inventoryDraft = _inventoryKey.currentState?.draft ?? _inventoryDraft;
    if (mounted) {
      setState(() {
        if (_validated) _fieldErrors = _validationErrors();
      });
    }
    if (_draftReady) {
      _draftTimer?.cancel();
      _draftTimer = Timer(const Duration(milliseconds: 500), _saveDraft);
    }
  }

  @override
  void dispose() {
    _saveDraft();
    _draftTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _titleCtrl
      ..removeListener(_onFormChanged)
      ..dispose();
    _otherCtrl
      ..removeListener(_onFormChanged)
      ..dispose();
    _commentCtrl
      ..removeListener(_onFormChanged)
      ..dispose();
    _refCtrl
      ..removeListener(_onFormChanged)
      ..dispose();
    _payeeCtrl
      ..removeListener(_onFormChanged)
      ..dispose();
    _fundCtrl
      ..removeListener(_onFormChanged)
      ..dispose();
    for (final focus in _fieldFocus.values) {
      focus.dispose();
    }
    super.dispose();
  }

  String? _dueAtPayload() {
    if (_dueDate == null) return null;
    final d = _dueDate!;
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final today = DateUtils.dateOnly(now);
    final last = DateUtils.dateOnly(now.add(const Duration(days: 365 * 2)));
    final desired = DateUtils.dateOnly(
      _dueDate ?? now.add(const Duration(days: 7)),
    );
    final picked = await showDatePicker(
      context: context,
      initialDate: desired.isBefore(today)
          ? today
          : desired.isAfter(last)
          ? last
          : desired,
      firstDate: today,
      lastDate: last,
      helpText: 'Target completion date',
    );
    if (picked != null && mounted) {
      setState(() => _dueDate = picked);
      _onFormChanged();
    }
  }

  void _clearForm() {
    _applyingDraft = true;
    final types = documentTypesForOffice(
      context.read<AuthProvider>().user!.officeCode,
    );
    _titleCtrl.clear();
    _otherCtrl.clear();
    _commentCtrl.clear();
    _refCtrl.clear();
    _payeeCtrl.clear();
    _fundCtrl.clear();
    _inventoryKey.currentState?.clear();
    _inventoryDraft = null;
    setState(() {
      _type = types.isNotEmpty ? types.first : _type;
      _dueDate = null;
      _receivedFromOfficeId = null;
      _error = null;
      _fieldErrors = {};
      _validated = false;
    });
    _applyingDraft = false;
    _saveDraft(remove: true);
    _fieldFocus['title']!.requestFocus();
  }

  void _registerAnother() {
    setState(() => _created = null);
    _clearForm();
  }

  Future<List<Map<String, dynamic>>> _checkDuplicates(String reference) async {
    if (reference.isEmpty) return const [];
    try {
      final res = await _api.findByReference(reference);
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
    if (!_current || _auth.loggingOut || _loading) return;
    final user = _user;
    final errors = _validationErrors();
    setState(() {
      _validated = true;
      _fieldErrors = errors;
      _error = null;
    });
    if (errors.isNotEmpty) {
      final focus = _fieldFocus[errors.keys.first]!;
      focus.requestFocus();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final fieldContext = focus.context;
        if (mounted && fieldContext != null) {
          Scrollable.ensureVisible(
            fieldContext,
            duration: const Duration(milliseconds: 200),
            alignment: 0.2,
          );
        }
      });
      return;
    }
    FocusScope.of(context).unfocus();
    final inventory = _inventoryKey.currentState?.validateAndRead();
    if (inventory == null) return;
    final title = _titleCtrl.text.trim();
    final otherName = _otherCtrl.text.trim();
    final savedType = _type == kOtherDocumentType
        ? 'Others: $otherName'
        : _type;

    final ref = _refCtrl.text.trim();

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (ref.isNotEmpty) {
        final matches = await _checkDuplicates(ref);
        if (matches.isNotEmpty) {
          if (!_current || _auth.loggingOut) return;
          final proceed = await _confirmDuplicate(ref, matches);
          if (!_current || _auth.loggingOut || !proceed) return;
        }
      }

      if (!_current || _auth.loggingOut) return;
      final data = await _api.createDocument(
        title: title,
        type: savedType,
        originOfficeId: user.officeId,
        description: _commentCtrl.text.trim().isEmpty
            ? null
            : _commentCtrl.text.trim(),
        dueAt: _dueAtPayload(),
        referenceNo: ref.isEmpty ? null : ref,
        payee: _payeeCtrl.text.trim().isEmpty ? null : _payeeCtrl.text.trim(),
        fundSource: _fundCtrl.text.trim().isEmpty
            ? null
            : _fundCtrl.text.trim(),
        receivedFromOfficeId: _needsReceivedFrom ? _receivedFromOfficeId : null,
        folderInventory: inventory,
        requestId: (widget.request?['id'] as num?)?.toInt(),
      );
      if (!mounted || !_current) return;
      HapticFeedback.mediumImpact();
      _saveDraft(remove: true);
      setState(() {
        _created = data['document'] as Map<String, dynamic>?;
        _loading = false;
      });
      final id = _created?['id']?.toString();
      if (mounted) {
        sfShowSuccessSnack(
          context,
          message: id != null && id.isNotEmpty
              ? 'Folder $id registered'
              : 'Folder registered',
        );
      }
    } on ApiException catch (e) {
      if (_current) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    } catch (e) {
      if (_current) {
        setState(() {
          _error = apiErrorMessage(e);
          _loading = false;
        });
      }
    } finally {
      if (_current) setState(() => _loading = false);
    }
  }

  void _copyId(String id) {
    Clipboard.setData(ClipboardData(text: id));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Tracking ID copied')));
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user!;
    final types = documentTypesForOffice(user.officeCode);
    final created = _created;
    final isHead = widget.homeRoute == '/head';
    final isAdmin = widget.homeRoute == '/admin';

    if (user.role != 'staff') {
      return ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
        children: [
          const SfPageTitle(
            title: 'Register folder',
            subtitle:
                'Office staff register physical folders held by their office.',
          ),
          const SizedBox(height: 16),
          const SfInfoBanner(
            text:
                'Heads and administrators monitor custody. Use Documents to review folders and their history.',
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => context.go('/${user.role}/documents'),
            child: const Text('Open Documents'),
          ),
        ],
      );
    }

    if (types.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
        children: [
          const SfClerkTabTitle(screen: SfClerkScreen.register),
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
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isAdmin) ...[
              const SfAuthenticatedPageHeader(),
              const SizedBox(height: 12),
              const SfAdminPageOverviewCard(screen: SfAdminScreen.register),
              const SizedBox(height: 14),
            ] else if (isHead) ...[
              const SfAuthenticatedPageHeader(),
              const SizedBox(height: 12),
              const SfHeadPageOverviewCard(screen: SfHeadScreen.register),
              const SizedBox(height: 14),
            ] else ...[
              const SfPageTitle(
                title: 'Register folder',
                subtitle:
                    'Register an unlabelled folder already held by your office. Registration records its initial IN.',
              ),
              const SizedBox(height: 10),
              _RegisterGuidance(officeCode: user.officeCode),
              const SizedBox(height: 8),
            ],
            SfFormCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CreationRecoveryPanel(
                    kind: 'document',
                    onRecovered: (data) {
                      if (!_current) return;
                      _saveDraft(remove: true);
                      setState(() {
                        _created = Map<String, dynamic>.from(
                          data['document'] as Map,
                        );
                        _error = null;
                      });
                    },
                  ),
                  if (_needsReceivedFrom && _officeError != null) ...[
                    Text(
                      _officeError!,
                      style: const TextStyle(color: SfColors.red),
                    ),
                    OutlinedButton(
                      onPressed: () {
                        setState(() => _officeError = null);
                        _loadOffices(user.officeId);
                      },
                      child: const Text('Retry sender offices'),
                    ),
                  ],
                  if (widget.request case final request?) ...[
                    SfInfoBanner(
                      text:
                          'Registering for ${request['request_code'] ?? request['id']}. Use an existing tracking ID if this folder already has a QR. Registration links this request and records receipt at your office.',
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_draftNote != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        _draftNote!,
                        style: const TextStyle(color: SfColors.muted),
                      ),
                    ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 3),
                        child: Icon(
                          Icons.lock_outline_rounded,
                          size: 18,
                          color: SfColors.muted,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Registering office',
                              style: TextStyle(
                                fontSize: 13,
                                color: SfColors.muted,
                              ),
                            ),
                            Text(
                              '${user.officeName} · ${user.officeCode}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: SfColors.ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Document title (required)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: SfColors.muted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _titleCtrl,
                    focusNode: _fieldFocus['title'],
                    minLines: 1,
                    maxLines: 2,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      errorText: _fieldErrors['title'],
                      hintText: 'e.g. Road repair — Phase 1',
                      hintMaxLines: 1,
                      border: OutlineInputBorder(),
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Document type (required)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: SfColors.muted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (types.length == 1)
                    InputDecorator(
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
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
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: types.contains(_type) ? _type : types.first,
                          isExpanded: true,
                          isDense: false,
                          itemHeight: null,
                          // The open menu keeps its roomy rows; the closed field stays as tall as the other inputs.
                          selectedItemBuilder: (context) => types
                              .map(
                                (t) => Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(t),
                                ),
                              )
                              .toList(),
                          items: types
                              .map(
                                (t) => DropdownMenuItem(
                                  value: t,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    child: Text(t),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: _loading
                              ? null
                              : (v) {
                                  if (v != null) {
                                    _type = v;
                                    _onFormChanged();
                                  }
                                },
                        ),
                      ),
                    ),
                  if (_type == kOtherDocumentType) ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: _otherCtrl,
                      focusNode: _fieldFocus['other'],
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        errorText: _fieldErrors['other'],
                        labelText: 'Others (required)',
                        hintText: 'What is this folder?',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  TextField(
                    controller: _commentCtrl,
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Comment (optional)',
                      hintText: 'Notes for the next office or for your logbook',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SfFormCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _RegisterSectionHeading(
                    title: 'Logbook & deadline',
                    description: _isDv
                        ? 'Reference number, payee and fund source are required for a DV.'
                        : _needsReference
                        ? 'Reference number is required. Payee and fund source are optional.'
                        : 'Add logbook details when available. These fields are optional.',
                  ),
                  const SizedBox(height: 16),
                  if (_needsReceivedFrom) ...[
                    InputDecorator(
                      decoration: InputDecoration(
                        errorText: _fieldErrors['sender'],
                        labelText: 'Received from office (required)',
                        border: OutlineInputBorder(),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          focusNode: _fieldFocus['sender'],
                          value: _receivedFromOfficeId,
                          isExpanded: true,
                          isDense: false,
                          itemHeight: null,
                          hint: const Text('Select office'),
                          items: _offices
                              .map(
                                (o) => DropdownMenuItem<int>(
                                  value: (o['id'] as num).toInt(),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    child: Text('${o['name']} (${o['code']})'),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: _loading
                              ? null
                              : (v) {
                                  _receivedFromOfficeId = v;
                                  _onFormChanged();
                                },
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Accounting does not originate project DVs. Register only a DV folder that arrived without a QR label.',
                      style: TextStyle(
                        fontSize: 14,
                        color: SfColors.muted,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  TextField(
                    controller: _refCtrl,
                    focusNode: _fieldFocus['reference'],
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      errorText: _fieldErrors['reference'],
                      labelText: _needsReference
                          ? 'Reference / DV no. (required)'
                          : 'Reference / DV no.',
                      hintText: 'LGU reference number',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _payeeCtrl,
                    focusNode: _fieldFocus['payee'],
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      errorText: _fieldErrors['payee'],
                      labelText: _isDv ? 'Payee (required)' : 'Payee',
                      border: const OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _fundCtrl,
                    focusNode: _fieldFocus['fund'],
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _canSubmit ? _submit() : null,
                    decoration: InputDecoration(
                      errorText: _fieldErrors['fund'],
                      labelText: _isDv
                          ? 'Fund source (required)'
                          : 'Fund source',
                      hintText: 'e.g. MOOE, PS',
                      border: const OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.characters,
                  ),
                  const SizedBox(height: 14),
                  _DueDateField(
                    dueDate: _dueDate,
                    onPick: _pickDueDate,
                    onClear: () {
                      setState(() => _dueDate = null);
                      _onFormChanged();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SfFormCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _RegisterSectionHeading(
                    title: 'Contents & page counts',
                    description:
                        'Count all physical pages, including attachments. List missing required attachments with 0 pages. Your office decides which items are required.',
                  ),
                  const SizedBox(height: 12),
                  if (_error != null) ...[
                    SfErrorBanner(message: _error!),
                    const SizedBox(height: 12),
                  ],
                  FolderChecklists(
                    editor: _inventoryKey,
                    type: _type,
                    enabled: !_loading,
                    onChanged: _onFormChanged,
                  ),
                  FolderInventoryEditor(
                    key: _inventoryKey,
                    showIntroduction: false,
                    enabled: !_loading,
                    onChanged: _onFormChanged,
                  ),
                  const SizedBox(height: 16),
                  SfPrimaryButton(
                    label: _loading ? 'Registering…' : 'Register folder',
                    loading: _loading,
                    onPressed: _canSubmit ? _submit : null,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Registration records this folder at your office and creates its tracking ID.',
                    style: TextStyle(
                      fontSize: 14,
                      color: SfColors.muted,
                      height: 1.4,
                    ),
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
        ),
      ],
    );
  }
}

class _RegisterSectionHeading extends StatelessWidget {
  const _RegisterSectionHeading({
    required this.title,
    required this.description,
  });

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 5),
      Text(
        description,
        style: const TextStyle(
          fontSize: 14,
          color: SfColors.muted,
          height: 1.4,
        ),
      ),
    ],
  );
}

/// Collapsible office tips (Register vs Request).
class _RegisterGuidance extends StatelessWidget {
  const _RegisterGuidance({required this.officeCode});

  final String officeCode;

  @override
  Widget build(BuildContext context) {
    final code = officeCode.toUpperCase();
    final String body;

    switch (code) {
      case 'ENG':
        body =
            'Register your DV packet here. If you asked Budget for a file, use New request in Requests — then Receive (IN) when it arrives (do not register as DV).';
        break;
      case 'BUD':
        body =
            'After approving a budget request, register Approved Budget, then Send (OUT) → ACC.';
        break;
      case 'HR':
        body =
            'Physical payroll folders are not registered in Phase 1. Accounting prepares payroll; HR supports plantilla.';
        break;
      case 'ACC':
        body =
            'Accounting does not originate project DVs — register a DV only if it arrived without a QR label. After supporting-doc check, Send (OUT) → Treasury.';
        break;
      case 'TRE':
        body =
            'Receive (IN) from Accounting, then Send (OUT) → Mayor. After Mayor returns the folder, Receive (IN) and release the check.';
        break;
      case 'MAY':
        body =
            'Receive (IN) when Treasury delivers the DV. After signature, Send (OUT) back to Treasury.';
        break;
      default:
        body =
            'Folder must be on your desk. To ask another office for files, send a request in Requests first.';
    }

    return Material(
      color: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: SfColors.strapBg,
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Text(
              'Already has a tracking ID? Open it in Scan or Documents.\n'
              'Held by another office? Create a request.',
              style: TextStyle(
                fontSize: 13,
                color: SfColors.muted,
                height: 1.3,
              ),
            ),
          ),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 4),
              minTileHeight: 48,
              dense: true,
              title: const Text(
                'Tips for your office',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              children: [
                Text(
                  body,
                  style: const TextStyle(
                    fontSize: 14,
                    color: SfColors.muted,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
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
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Target due date (optional)',
          style: TextStyle(
            fontSize: 14,
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
                  dueDate == null ? 'Choose date' : _format(dueDate!),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: dueDate == null
                        ? FontWeight.w500
                        : FontWeight.w700,
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
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
            ],
          ),
        ),
        if (dueDate == null) ...[
          const SizedBox(height: 6),
          const Text(
            'Leave blank to use office alert time limits.',
            style: TextStyle(fontSize: 13, color: SfColors.muted, height: 1.35),
          ),
        ],
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

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
      children: [
        SfAuthenticatedPageHeader(
          fallbackRoute: homeRoute,
          hideBackOnRoleHome: false,
        ),
        const SizedBox(height: 12),
        SfFormCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    color: SfColors.green,
                    size: 28,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Document registered',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                initialIn
                    ? 'Initial IN recorded at ${user.officeName}. No extra scan is needed for registration.'
                    : 'Folder saved. Open the folder in Documents to verify its current custody before the next handoff.',
                style: const TextStyle(
                  fontSize: 14,
                  color: SfColors.muted,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                created['title']?.toString() ?? 'Registered folder',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontSize: 22, height: 1.3),
              ),
              const SizedBox(height: 14),
              const Text(
                'Tracking ID',
                style: TextStyle(fontSize: 14, color: SfColors.muted),
              ),
              const SizedBox(height: 4),
              SelectableText(
                id,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: SfColors.navy,
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => onCopyId(id),
                  icon: const Icon(Icons.content_copy_rounded, size: 18),
                  label: const Text('Copy ID'),
                ),
              ),
              Theme(
                data: Theme.of(
                  context,
                ).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text(
                    'Registration details',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  children: [
                    DocumentSummary(
                      showCustody: false,
                      document: {
                        ...created,
                        'origin_office_name': user.officeName,
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SfPrimaryButton(
                label: 'Open folder',
                onPressed: () => context.go(
                  '$homeRoute/documents?id=${Uri.encodeComponent(id)}',
                ),
              ),
              const SizedBox(height: 10),
              SfSecondaryOutlineButton(
                label: created['request_id'] == null
                    ? 'Register another folder'
                    : 'Back to document requests',
                onPressed: created['request_id'] == null
                    ? onRegisterAnother
                    : () => context.go('$homeRoute/requests'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const _RegisterSectionHeading(
          title: 'Folder label',
          description:
              'Keep the tracking ID with the folder. Save a QR image or print its label when needed.',
        ),
        const SizedBox(height: 14),
        DocumentQrCard(id: id, payload: qrPayload, showId: false),
        if (qrExpires != null && qrExpires.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Signed label · valid until ${_shortQrExpiry(qrExpires)}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: SfColors.muted),
          ),
        ],
        const SizedBox(height: 12),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text(
            'How to hand over this folder',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: SfColors.blue,
            ),
          ),
          children: [_RegisterNextStepsCard(isHead: isHead)],
        ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 4,
          children: [
            SfGhostTextButton(
              label: 'Print / Save label',
              onPressed: () async {
                try {
                  final html = await preparePrintableLabel(
                    await context.read<AuthProvider>().api.printableLabel(id),
                  );
                  await const MethodChannel(
                    'smartflow/report_export',
                  ).invokeMethod<bool>('printReport', {'html': html});
                } catch (error) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(apiErrorMessage(error))),
                    );
                  }
                }
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
            'Use Documents to forward and receive. No printed QR is required.',
            style: TextStyle(
              fontSize: 11.5,
              color: SfColors.muted,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          _step('1', 'Open the document in SmartFlow'),
          const SizedBox(height: 8),
          _step('2', 'Forward (OUT) and choose the receiving office'),
          const SizedBox(height: 8),
          _step(
            '3',
            'Receiving office opens Incoming and confirms receipt (IN)',
          ),
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
        child: Text(text, style: const TextStyle(fontSize: 12, height: 1.4)),
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
