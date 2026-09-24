import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../data/office_document_types.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_client.dart';
import '../../utils/api_error.dart';
import '../../theme/smartflow_theme.dart';
import '../../widgets/sf_pdf_chrome.dart';
import '../../widgets/sf_widgets.dart';
import '../staff/clerk_widgets.dart';
import '../head/head_widgets.dart';
import '../admin/admin_widgets.dart';

enum _InboxFilter { all, pending, overdue }

/// Inter-office document requests (access by category or pull from target office).
class DocumentRequestsScreen extends StatefulWidget {
  const DocumentRequestsScreen({super.key, required this.homeRoute});

  final String homeRoute;

  @override
  State<DocumentRequestsScreen> createState() => _DocumentRequestsScreenState();
}

class _DocumentRequestsScreenState extends State<DocumentRequestsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<Map<String, dynamic>> _inbox = [];
  List<Map<String, dynamic>> _outbox = [];
  int _pendingInbox = 0;
  bool _loading = true;
  String? _error;
  _InboxFilter _inboxFilter = _InboxFilter.all;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(() {
      if (mounted) setState(() {});
    });
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<AuthProvider>().api;
      final inbox = await api.documentRequestsList(view: 'inbox');
      final outbox = await api.documentRequestsList(view: 'outbox');
      if (!mounted) return;
      setState(() {
        _inbox = _parseList(inbox);
        _outbox = _parseList(outbox);
        _pendingInbox = (inbox['pending_inbox_count'] as int?) ?? 0;
        _loading = false;
      });
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

  List<Map<String, dynamic>> _parseList(Map<String, dynamic> data) {
    return (data['requests'] as List<dynamic>? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  int get _inboxPendingCount =>
      _inbox.where((r) => r['status']?.toString() == 'pending').length;

  int get _inboxOverdueCount =>
      _inbox.where((r) => r['is_overdue'] == true).length;

  List<Map<String, dynamic>> get _filteredInbox {
    switch (_inboxFilter) {
      case _InboxFilter.pending:
        return _inbox
            .where((r) => r['status']?.toString() == 'pending')
            .toList();
      case _InboxFilter.overdue:
        return _inbox.where((r) => r['is_overdue'] == true).toList();
      case _InboxFilter.all:
        return _inbox;
    }
  }

  Future<void> _openCreate() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CreateRequestSheet(homeRoute: widget.homeRoute),
    );
    if (created == true && mounted) {
      HapticFeedback.lightImpact();
      sfShowSuccessSnack(
        context,
        message: 'Request sent — track it under My requests',
        actionLabel: 'View',
        onAction: () {
          if (_tabs.index != 1) _tabs.animateTo(1);
        },
      );
      _tabs.animateTo(1);
      await _load();
    }
  }

  Future<void> _act(Map<String, dynamic> req, String action) async {
    String? notes;
    String? docId;
    if (action == 'reject' || action == 'fulfill') {
      notes = await _promptNotes(action);
      if (!mounted) return;
      if (action == 'fulfill') {
        docId = await _promptDocId();
        if (!mounted) return;
      }
    }
    try {
      final api = context.read<AuthProvider>().api;
      await api.documentRequestUpdate(
        requestId: req['id'] as int,
        action: action,
        reviewNotes: notes,
        relatedDocumentId: docId,
      );
      if (mounted) {
        final msg = switch (action) {
          'approve' =>
            'Accepted — register the folder if needed, then Scan IN/OUT',
          'reject' =>
            'Declined — also notify the requester by phone or memo',
          'fulfill' => _fulfillSuccessMessage(req),
          'cancel' => 'Request cancelled',
          _ => 'Request updated',
        };
        HapticFeedback.lightImpact();
        sfShowSuccessSnack(
          context,
          message: msg,
          backgroundColor:
              action == 'reject' ? SfColors.gold : SfColors.green,
        );
        if (action == 'reject') {
          await showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Separate notice required'),
              content: const Text(
                'Per Municipal Accountant practice, also inform the requester '
                'outside the app (phone call or memo). In-app status alone is not enough.',
              ),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
        await _load();
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: SfColors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<String?> _promptNotes(String action) async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          action == 'reject'
              ? 'Decline request'
              : action == 'fulfill'
                  ? 'Mark complete'
                  : 'Update request',
        ),
        content: TextField(
          controller: c,
          decoration: const InputDecoration(labelText: 'Notes (optional)'),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (ok != true) return null;
    return c.text.trim().isEmpty ? null : c.text.trim();
  }

  Future<String?> _promptDocId() async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Link document (optional)'),
        content: TextField(
          controller: c,
          decoration: const InputDecoration(hintText: 'Tracking ID'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Skip'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ok != true) return null;
    return c.text.trim().isEmpty ? null : c.text.trim();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AuthProvider>();
    final onInbox = _tabs.index == 0;

    return Scaffold(
      backgroundColor: SfColors.bg,
      body: Container(
        decoration: const BoxDecoration(gradient: SfGradients.pageSky),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SfAuthenticatedPageHeader(
                      fallbackRoute: widget.homeRoute,
                      hideBackOnRoleHome: false,
                    ),
                    const SizedBox(height: 10),
                    _RequestsOverviewCard(
                      homeRoute: widget.homeRoute,
                      pendingInbox: _pendingInbox,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Ticket to another office — use Scan when the physical folder moves.',
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.35,
                        color: SfColors.muted.withValues(alpha: 0.95),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SfPrimaryButton(
                      label: 'New request',
                      onPressed: _openCreate,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              TabBar(
                controller: _tabs,
                labelColor: SfColors.navy,
                unselectedLabelColor: SfColors.muted,
                indicatorColor: SfColors.navy,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
                tabs: [
                  Tab(
                    text: _pendingInbox > 0
                        ? 'Inbox ($_pendingInbox)'
                        : 'Inbox',
                  ),
                  const Tab(text: 'My requests'),
                ],
              ),
              if (onInbox && !_loading && _error == null) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: _InboxFilterChips(
                    pending: _inboxPendingCount,
                    overdue: _inboxOverdueCount,
                    total: _inbox.length,
                    selected: _inboxFilter,
                    onSelected: (f) => setState(() => _inboxFilter = f),
                  ),
                ),
              ],
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _load,
                  color: SfColors.blue,
                  child: _loading
                      ? ListView(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                          children: const [
                            SfLoadingCard(),
                          ],
                        )
                      : _error != null
                          ? ListView(
                              padding: const EdgeInsets.all(16),
                              children: [
                                SfErrorBanner(message: _error!),
                                const SizedBox(height: 12),
                                SfSecondaryOutlineButton(
                                  label: 'Try again',
                                  onPressed: _load,
                                ),
                              ],
                            )
                          : TabBarView(
                              controller: _tabs,
                              children: [
                                _listView(
                                  _filteredInbox,
                                  inbox: true,
                                  filterEmpty: _inbox.isNotEmpty &&
                                      _filteredInbox.isEmpty,
                                ),
                                _listView(_outbox, inbox: false),
                              ],
                            ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _listView(
    List<Map<String, dynamic>> items, {
    required bool inbox,
    bool filterEmpty = false,
  }) {
    if (filterEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
        children: [
          SfEmptyState(
            icon: Icons.filter_list_off_outlined,
            title: 'No requests in this filter',
            subtitle: 'Try All to see every ticket in your inbox.',
            actionLabel: 'Show all',
            onAction: () => setState(() => _inboxFilter = _InboxFilter.all),
          ),
        ],
      );
    }
    if (items.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
        children: [
          SfEmptyState(
            icon: inbox ? Icons.inbox_outlined : Icons.send_outlined,
            title: inbox ? 'No open requests for this office' : 'No requests yet',
          ),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        ...items.map(
          (r) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _RequestCard(
              request: r,
              inbox: inbox,
              myOfficeCode: context.read<AuthProvider>().user!.officeCode,
              onApprove: () => _act(r, 'approve'),
              onReject: () => _act(r, 'reject'),
              onFulfill: () => _act(r, 'fulfill'),
              onCancel: () => _act(r, 'cancel'),
            ),
          ),
        ),
      ],
    );
  }
}

String _fulfillSuccessMessage(Map<String, dynamic> req) {
  final cat = req['document_category']?.toString().toLowerCase() ?? '';
  if (cat == 'disbursement') {
    return 'Payment release recorded — request closed';
  }
  return 'Request closed (custody complete)';
}

bool _isDisbursement(Map<String, dynamic> request) =>
    (request['document_category']?.toString().toLowerCase() ?? '') ==
    'disbursement';

String _requestStatusLabel(String status) {
  switch (status) {
    case 'pending':
      return 'Pending';
    case 'approved':
      return 'Accepted';
    case 'rejected':
      return 'Declined';
    case 'fulfilled':
      return 'Closed';
    case 'cancelled':
      return 'Cancelled';
    default:
      return status.isEmpty
          ? '—'
          : status[0].toUpperCase() + status.substring(1);
  }
}

String _categoryLabel(String cat) {
  if (cat.isEmpty) return 'Document';
  return cat
      .split(RegExp(r'[_\s]+'))
      .where((p) => p.isNotEmpty)
      .map((p) => '${p[0].toUpperCase()}${p.substring(1)}')
      .join(' ');
}

class _InboxFilterChips extends StatelessWidget {
  const _InboxFilterChips({
    required this.pending,
    required this.overdue,
    required this.total,
    required this.selected,
    required this.onSelected,
  });

  final int pending;
  final int overdue;
  final int total;
  final _InboxFilter selected;
  final ValueChanged<_InboxFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _chip('All', _InboxFilter.all, total),
          _chip('Pending', _InboxFilter.pending, pending),
          _chip('Overdue', _InboxFilter.overdue, overdue),
        ],
      ),
    );
  }

  Widget _chip(String label, _InboxFilter value, int count) {
    final isSelected = selected == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text('$label${count > 0 ? ' ($count)' : ''}'),
        selected: isSelected,
        onSelected: (_) => onSelected(value),
        selectedColor: SfColors.navy.withValues(alpha: 0.12),
        checkmarkColor: SfColors.navy,
        labelStyle: TextStyle(
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          color: isSelected ? SfColors.navy : SfColors.ink,
        ),
      ),
    );
  }
}

class _RequestsOverviewCard extends StatelessWidget {
  const _RequestsOverviewCard({
    required this.homeRoute,
    required this.pendingInbox,
  });

  final String homeRoute;
  final int pendingInbox;

  @override
  Widget build(BuildContext context) {
    switch (homeRoute) {
      case '/admin':
        return SfAdminPageOverviewCard(
          screen: SfAdminScreen.requests,
          pendingInbox: pendingInbox,
          compact: true,
        );
      case '/head':
        return SfHeadPageOverviewCard(
          screen: SfHeadScreen.requests,
          pendingInbox: pendingInbox,
          compact: true,
        );
      default:
        return SfClerkPageOverviewCard(
          screen: SfClerkScreen.requests,
          pendingInbox: pendingInbox,
          compact: true,
        );
    }
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.request,
    required this.inbox,
    required this.myOfficeCode,
    required this.onApprove,
    required this.onReject,
    required this.onFulfill,
    required this.onCancel,
  });

  final Map<String, dynamic> request;
  final bool inbox;
  final String myOfficeCode;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onFulfill;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final status = request['status']?.toString() ?? '';
    final requester = request['requester'] as Map<String, dynamic>? ?? {};
    final handler = request['handler_office'] as Map<String, dynamic>? ?? {};
    final cat = request['document_category']?.toString() ?? '';
    final purpose = request['purpose']?.toString().trim() ?? '';
    final code = request['request_code']?.toString() ?? '';
    final fromCode = requester['office_code']?.toString() ?? '—';
    final toCode = handler['office_code']?.toString() ?? '—';

    SfPillTone tone = SfPillTone.neutral;
    if (status == 'pending') tone = SfPillTone.warning;
    if (status == 'approved') tone = SfPillTone.success;
    if (status == 'rejected') tone = SfPillTone.danger;
    if (status == 'fulfilled') tone = SfPillTone.success;

    final statusLabel = _requestStatusLabel(status);
    final requiredBy = request['required_by_display']?.toString();
    final isOverdue = request['is_overdue'] == true;
    final title = purpose.isNotEmpty ? purpose : _categoryLabel(cat);
    final routeLine = inbox
        ? '$fromCode → your desk · $code'
        : 'To $toCode · $code';
    final catLine = _categoryLabel(cat);

    return SfFormCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    height: 1.3,
                    color: SfColors.ink,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SfStatusPill(label: statusLabel, tone: tone),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            routeLine,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: SfColors.muted,
            ),
          ),
          if (cat.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              catLine,
              style: TextStyle(
                fontSize: 11,
                color: SfColors.muted.withValues(alpha: 0.9),
              ),
            ),
          ],
          if (requiredBy != null && requiredBy.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isOverdue
                    ? SfColors.red.withValues(alpha: 0.08)
                    : SfColors.navy.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isOverdue
                      ? SfColors.red.withValues(alpha: 0.25)
                      : SfColors.navy.withValues(alpha: 0.12),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isOverdue
                        ? Icons.warning_amber_rounded
                        : Icons.event_rounded,
                    size: 16,
                    color: isOverdue ? SfColors.red : SfColors.navy,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isOverdue
                          ? 'Overdue — required by $requiredBy'
                          : 'Required by $requiredBy',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isOverdue ? SfColors.red : SfColors.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (request['related_document_id'] != null) ...[
            const SizedBox(height: 8),
            Text(
              'Linked: ${request['related_document_id']}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: SfColors.blue,
              ),
            ),
          ],
          if (inbox && status == 'pending') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: SfSecondaryOutlineButton(
                    label: 'Decline',
                    onPressed: onReject,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SfPrimaryButton(
                    label: 'Accept',
                    onPressed: onApprove,
                  ),
                ),
              ],
            ),
          ],
          if (inbox && status == 'approved') ...[
            const SizedBox(height: 12),
            if (_isDisbursement(request) &&
                myOfficeCode.toUpperCase() != 'TRE') ...[
              const SfInfoBanner(
                text:
                    'Accepted — Treasury closes this after payment release.',
              ),
            ] else
              SfPrimaryButton(
                label: _isDisbursement(request)
                    ? 'Mark payment released'
                    : 'Close request',
                onPressed: onFulfill,
              ),
          ],
          if (!inbox && (status == 'pending' || status == 'approved')) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: onCancel,
                child: const Text('Cancel request'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CreateRequestSheet extends StatefulWidget {
  const _CreateRequestSheet({required this.homeRoute});

  final String homeRoute;

  @override
  State<_CreateRequestSheet> createState() => _CreateRequestSheetState();
}

class _CreateRequestSheetState extends State<_CreateRequestSheet> {
  String _kind = 'access';
  String _category = 'budget';
  int? _targetOfficeId;
  DateTime? _requiredBy;
  final _purpose = TextEditingController();
  List<Map<String, dynamic>> _offices = [];
  bool _loading = false;
  String? _error;

  List<MapEntry<String, String>> get _categories {
    final user = context.read<AuthProvider>().user!;
    return documentRequestCategoriesForOffice(user.officeCode);
  }

  @override
  void initState() {
    super.initState();
    _requiredBy = DateTime.now().add(const Duration(days: 7));
    _loadOffices();
  }

  @override
  void dispose() {
    _purpose.dispose();
    super.dispose();
  }

  Future<void> _loadOffices() async {
    final list = await context.read<AuthProvider>().api.offices();
    if (!mounted) return;
    final cats = _categories;
    setState(() {
      _offices = list;
      if (cats.isNotEmpty) {
        _category = cats.first.key;
      }
    });
  }

  Future<void> _pickRequiredBy() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _requiredBy ?? now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 2)),
      helpText: 'Required-by date',
    );
    if (picked != null && mounted) {
      setState(() => _requiredBy = picked);
    }
  }

  String? _requiredByPayload() {
    if (_requiredBy == null) return null;
    final d = _requiredBy!;
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _submit() async {
    if (_purpose.text.trim().isEmpty) {
      setState(() => _error = 'Enter a purpose');
      return;
    }
    if (_requiredBy == null) {
      setState(() => _error = 'Select a required-by date');
      return;
    }
    if (_kind == 'access' && _categories.isEmpty) {
      setState(() => _error = 'No request types available for your office');
      return;
    }
    if (_kind == 'pull' && _targetOfficeId == null) {
      setState(() => _error = 'Choose an office');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<AuthProvider>().api.documentRequestCreate(
            requestKind: _kind,
            documentCategory: _category,
            targetOfficeId: _kind == 'pull' ? _targetOfficeId : null,
            purpose: _purpose.text.trim(),
            requiredBy: _requiredByPayload()!,
          );
      if (mounted) Navigator.pop(context, true);
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

  Widget _stepLabel(String step, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: SfColors.navy.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              step,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: SfColors.navy,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: SfColors.navy,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = _categories;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        decoration: BoxDecoration(
          color: SfColors.paper,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: SfColors.navy.withValues(alpha: 0.08)),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: SfColors.muted.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text(
                'New document request',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                  color: SfColors.navy,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Formal ticket — not a QR scan.',
                style: TextStyle(fontSize: 12, color: SfColors.muted),
              ),
              const SizedBox(height: 16),
              _stepLabel('1', 'What do you need?'),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'access', label: Text('By type')),
                  ButtonSegment(value: 'pull', label: Text('From office')),
                ],
                selected: {_kind},
                onSelectionChanged: (s) => setState(() => _kind = s.first),
              ),
              const SizedBox(height: 12),
              if (_kind == 'access')
                categories.isEmpty
                    ? const Text(
                        'Your office cannot submit access requests by type. '
                        'Use “From office” to pull a folder from ENG or BUD.',
                        style: TextStyle(fontSize: 12, color: SfColors.muted),
                      )
                    : DropdownButtonFormField<String>(
                        value: categories.any((e) => e.key == _category)
                            ? _category
                            : categories.first.key,
                        decoration: const InputDecoration(
                          labelText: 'Document type',
                        ),
                        items: categories
                            .map(
                              (e) => DropdownMenuItem(
                                value: e.key,
                                child: Text(e.value),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(
                          () => _category = v ?? categories.first.key,
                        ),
                      )
              else
                DropdownButtonFormField<int>(
                  value: _targetOfficeId,
                  decoration: const InputDecoration(
                    labelText: 'Send request to office',
                  ),
                  items: _offices.map((o) {
                    final id = o['id'] as int;
                    return DropdownMenuItem(
                      value: id,
                      child: Text('${o['name']} (${o['code']})'),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => _targetOfficeId = v),
                ),
              const SizedBox(height: 16),
              _stepLabel('2', 'When is it needed?'),
              InkWell(
                onTap: _pickRequiredBy,
                borderRadius: BorderRadius.circular(8),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Required-by date *',
                    border: OutlineInputBorder(),
                  ),
                  child: Text(
                    _requiredBy == null
                        ? 'Select date'
                        : '${_requiredBy!.year}-${_requiredBy!.month.toString().padLeft(2, '0')}-${_requiredBy!.day.toString().padLeft(2, '0')}',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Requester follows up if overdue (office practice).',
                style: TextStyle(fontSize: 10, color: SfColors.muted),
              ),
              const SizedBox(height: 16),
              _stepLabel('3', 'Why?'),
              TextField(
                controller: _purpose,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Purpose',
                  hintText: 'e.g. Check budget for road repair DV',
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: const TextStyle(color: SfColors.red, fontSize: 12),
                ),
              ],
              const SizedBox(height: 18),
              SfPrimaryButton(
                label: _loading ? 'Submitting…' : 'Submit request',
                loading: _loading,
                onPressed: _loading ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
