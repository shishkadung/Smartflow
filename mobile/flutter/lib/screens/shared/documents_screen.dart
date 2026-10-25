import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_client.dart';
import '../../theme/smartflow_theme.dart';
import '../../widgets/document_qr_card.dart';
import '../../widgets/document_summary.dart';
import '../../widgets/document_filing.dart';
import '../../widgets/folder_contents.dart';
import '../../widgets/mark_out_destination_dialog.dart';
import '../../widgets/sf_widgets.dart';
import '../../utils/live_refresh.dart';
import '../../utils/document_queue.dart';
import '../../utils/api_error.dart';
import '../../utils/tracking_id.dart';
import '../../widgets/document_journey.dart';
import '../../widgets/destination_correction.dart';
import '../../widgets/sf_pdf_chrome.dart';
import 'package:intl/intl.dart';

bool _hasFilingEvidence(Map<String, dynamic> row) {
  final filing = row['filed_by'];
  final at = row['filed_at'] ?? (filing is Map ? filing['filed_at'] : null);
  return at?.toString().trim().isNotEmpty ?? false;
}

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({
    super.key,
    this.initialDocumentId,
    this.municipal = false,
    this.initialOfficeId,
    this.initialOverdue = false,
    this.initialTray,
    this.fromRequest = false,
  });
  final String? initialDocumentId;
  final bool municipal;
  final int? initialOfficeId;
  final bool initialOverdue;
  final String? initialTray;
  final bool fromRequest;
  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen>
    with LiveRefresh<DocumentsScreen> {
  List<Map<String, dynamic>> _documents = [];
  Map<String, dynamic>? _doc;
  String? _selected;
  String _tray = 'incoming';
  String _query = '';
  String? _error;
  bool _loading = true;
  bool _busy = false;
  int _request = 0;
  bool _docFresh = false;
  bool _overdueOnly = false;
  String _sort = 'urgency';
  Timer? _searchTimer;
  int _offset = 0;
  int _total = 0;
  bool _hasMore = false;
  Map<String, dynamic> _trayCounts = {};
  int _overdueCount = 0;
  DateTime? _updated;
  Object? _loadedQuery;
  late Object _accountKey;
  final _searchController = TextEditingController();

  Object get _identity {
    final auth = context.read<AuthProvider>();
    return (
      auth,
      auth.token,
      auth.user?.id,
      auth.user?.officeId,
      auth.user?.role,
    );
  }

  Object get _queryKey => (
    _identity,
    widget.municipal,
    widget.initialOfficeId,
    _selected,
    _tray,
    _overdueOnly,
    _query.trim(),
    _sort,
    _offset,
  );
  static const _trays = {
    'incoming': 'Incoming',
    'in_office': 'At your office',
    'forwarded': 'Forwarded',
    'completed': 'Completed',
  };

  @override
  void initState() {
    super.initState();
    _accountKey = _identity;
    _selected = widget.initialDocumentId == null
        ? null
        : parseTrackingId(widget.initialDocumentId!) ??
              widget.initialDocumentId!.trim();
    _tray = widget.initialTray ?? (widget.municipal ? 'in_office' : 'incoming');
    _overdueOnly = widget.initialOverdue;
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = Provider.of<AuthProvider>(context);
    final identity = (
      auth,
      auth.token,
      auth.user?.id,
      auth.user?.officeId,
      auth.user?.role,
    );
    if (_accountKey != identity) {
      _accountKey = identity;
      _load();
    }
  }

  @override
  void didUpdateWidget(covariant DocumentsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialDocumentId != widget.initialDocumentId ||
        oldWidget.initialTray != widget.initialTray ||
        oldWidget.initialOverdue != widget.initialOverdue ||
        oldWidget.initialOfficeId != widget.initialOfficeId ||
        oldWidget.municipal != widget.municipal) {
      _searchTimer?.cancel();
      _selected = widget.initialDocumentId == null
          ? null
          : parseTrackingId(widget.initialDocumentId!) ??
                widget.initialDocumentId!.trim();
      _tray =
          widget.initialTray ?? (widget.municipal ? 'in_office' : 'incoming');
      _overdueOnly = widget.initialOverdue;
      _offset = 0;
      _load();
    }
  }

  @override
  Future<void> refreshLiveData() async {
    if (!_busy && !_loading) await _load(background: true);
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _filterChanged() {
    _searchTimer?.cancel();
    _query = _searchController.text;
    _offset = 0;
    _load(background: true);
  }

  Future<void> _load({bool background = false}) async {
    final request = ++_request;
    final selected = _selected;
    final query = _queryKey;
    final sameQuery = _loadedQuery == query;
    setState(() {
      if (!background || !sameQuery) {
        _loading = true;
      }
      if (!sameQuery) {
        _documents = [];
        _doc = null;
        _trayCounts = {};
        _total = 0;
        _hasMore = false;
        _overdueCount = 0;
        _updated = null;
        _loadedQuery = null;
        _error = null;
      }
      _docFresh = false;
      if (_doc?['id'] != selected) {
        _doc = null;
      }
    });
    try {
      final api = context.read<AuthProvider>().api;
      Future<Map<String, dynamic>> selectedDetail() async {
        try {
          return await api.officeDocuments(id: selected);
        } catch (error) {
          if (error is! ApiException || error.statusCode != 404) rethrow;
          final shown = await api.documentShow(selected!);
          final activity = await api.documentMovements(selected);
          return {
            'read_only': true,
            'document': {
              ...shown['document'] as Map,
              'tray': (shown['document'] as Map)['trail_complete'] == true
                  ? 'completed'
                  : 'elsewhere',
              'can_file': false,
              'can_correct_destination': false,
              'journey': activity['movements'] ?? [],
            },
          };
        }
      }

      final result = widget.municipal
          ? await api.municipalDocuments(
              id: selected,
              tray: _tray,
              search: _query,
              sort: _sort,
              overdue: _overdueOnly,
              currentOfficeId: widget.initialOfficeId,
              limit: selected == null ? 50 : null,
              offset: _offset,
            )
          : selected == null
          ? await api.officeDocumentPage(
              tray: _tray,
              search: _query,
              sort: _sort,
              overdue: _overdueOnly,
              offset: _offset,
            )
          : await selectedDetail();
      if (!mounted || request != _request || query != _queryKey) return;
      setState(() {
        if (selected == null) {
          _documents = List<Map<String, dynamic>>.from(
            result['documents'] as List,
          );
          _total = (result['total'] as num).toInt();
          _hasMore = result['has_more'] == true;
          _trayCounts = Map<String, dynamic>.from(result['tray_counts'] as Map);
          _overdueCount = (result['overdue_count'] as num).toInt();
          if (_documents.isEmpty && _offset > 0 && _total <= _offset) {
            _offset = 0;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _load(background: true);
            });
          }
        } else {
          final next = Map<String, dynamic>.from(result['document'] as Map);
          next['read_only'] = result['read_only'] == true;
          _doc = next;
          _docFresh = true;
        }
        _updated = DateTime.now();
        _loadedQuery = query;
        _error = null;
      });
    } catch (e) {
      if (mounted && request == _request && query == _queryKey) {
        setState(() => _error = apiErrorMessage(e));
      }
    } finally {
      if (mounted && request == _request && query == _queryKey) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _file() async {
    final doc = _doc;
    final auth = context.read<AuthProvider>();
    final identity = auth.sessionIdentity;
    final api = auth.api;
    bool current() => mounted && auth.sessionIdentity == identity;
    if (doc == null ||
        auth.loggingOut ||
        context.read<AuthProvider>().user?.role != 'staff' ||
        widget.municipal ||
        doc['read_only'] == true ||
        !_docFresh ||
        _busy ||
        doc['can_file'] != true) {
      return;
    }
    final expectedMovementId = (doc['last_movement_id'] as num?)?.toInt();
    if (expectedMovementId == null || expectedMovementId <= 0) {
      setState(
        () => _error =
            'Current movement unavailable. Refresh and review this folder before filing.',
      );
      return;
    }
    setState(() => _busy = true);
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
      setState(() => _error = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message']?.toString() ?? 'Filed.')),
      );
      await _load();
    } catch (e) {
      if (!mounted || !current()) return;
      if (e is ApiException && e.statusCode == 409) await _load();
      if (current()) setState(() => _error = apiErrorMessage(e));
    } finally {
      if (current()) setState(() => _busy = false);
    }
  }

  Future<void> _move(String status) async {
    final doc = _doc;
    final auth = context.read<AuthProvider>();
    if (doc == null ||
        auth.loggingOut ||
        auth.user?.role != 'staff' ||
        widget.municipal ||
        doc['read_only'] == true ||
        !_docFresh ||
        _busy) {
      return;
    }
    setState(() => _busy = true);
    final user = auth.user!;
    final identity = auth.sessionIdentity;
    final api = auth.api;
    bool current() => mounted && auth.sessionIdentity == identity;
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
        final suggested = doc['suggested_forward'] as Map?;
        destination = await showMarkOutDestinationDialog(
          context,
          documentId: doc['id'].toString(),
          myOfficeId: user.officeId,
          myOfficeName: user.officeName,
          myOfficeCode: user.officeCode,
          documentType: doc['type'].toString(),
          suggestedOfficeId: (suggested?['office_id'] as num?)?.toInt(),
          suggestedOfficeCode: suggested?['office_code']?.toString(),
          suggestedReason: suggested?['reason']?.toString(),
          onlyDestinationCode: doc['can_return_to_accounting'] == true
              ? 'ACC'
              : null,
        );
        if (destination == null || !mounted || !current()) return;
      }
      if (!mounted || !current() || auth.loggingOut) return;
      final result = await api.recordMovement(
        documentId: doc['id'].toString(),
        officeId: user.officeId,
        status: status,
        destinationOfficeId: destination?.officeId,
        isReturn: destination?.isReturn ?? false,
        remarks: destination?.returnReason,
        movementSource: 'system',
        expectedMovementId: (doc['last_movement_id'] as num).toInt(),
        receiptConfirmed:
            status == 'IN' && contentsReceipt?['confirmed'] == true,
        contentsReceipt: contentsReceipt,
      );
      if (!mounted || !current()) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result['message'].toString())));
      await _load();
    } catch (e) {
      if (!mounted || !current()) return;
      await _load();
      if (current()) setState(() => _error = apiErrorMessage(e));
    } finally {
      if (current()) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final doc = _doc;
    final rows = _documents;
    final readOnly =
        context.watch<AuthProvider>().user?.role != 'staff' ||
        widget.municipal ||
        doc?['read_only'] == true;
    final views = {
      for (final entry in _trays.entries)
        if (!widget.municipal || entry.key != 'incoming')
          entry.key: widget.municipal && entry.key == 'in_office'
              ? 'At offices'
              : entry.value,
      'overdue': 'Overdue',
    };
    String viewLabel(String value) {
      final label = views[value]!;
      if (_trayCounts.isEmpty) return '$label (—)';
      final count = value == 'overdue'
          ? _overdueCount
          : (_trayCounts[value] as num?)?.toInt() ?? 0;
      return count > 0 ? '$label ($count)' : label;
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SfPageTitle(
                  title: _selected == null ? 'Documents' : 'Document details',
                  subtitle: _selected != null
                      ? 'Custody, contents and movement history.'
                      : widget.municipal
                      ? 'Browse folders and custody across offices.'
                      : 'Find and follow your office’s folders.',
                ),
              ),
              IconButton(
                tooltip: 'Refresh',
                onPressed: _busy ? null : _load,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          if (_updated != null)
            Text(
              '${_error == null ? 'Updated' : 'Last successful update'} ${DateFormat.Hms().format(_updated!)}',
              style: const TextStyle(fontSize: 11, color: SfColors.muted),
            ),
          if (widget.municipal)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Municipal oversight · office staff record physical handoffs.',
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _updated == null
                        ? 'Documents unavailable. $_error'
                        : 'Refresh failed. Previously loaded data may be stale. $_error',
                    style: const TextStyle(color: SfColors.red),
                  ),
                  TextButton(
                    onPressed: _busy ? null : _load,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          if (_selected != null)
            TextButton.icon(
              onPressed: _busy
                  ? null
                  : () {
                      if (widget.fromRequest && context.canPop()) {
                        context.pop();
                        return;
                      }
                      _selected = null;
                      _load();
                    },
              icon: const Icon(Icons.arrow_back),
              label: Text(
                widget.fromRequest ? 'Back to request' : 'Back to documents',
              ),
            ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(28),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_selected == null) ...[
            const SizedBox(height: 14),
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'View',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 4,
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  key: const ValueKey('documents-view'),
                  value: _overdueOnly
                      ? 'overdue'
                      : views.containsKey(_tray)
                      ? _tray
                      : null,
                  hint: const Text('Choose view'),
                  isExpanded: true,
                  itemHeight: null,
                  borderRadius: BorderRadius.circular(10),
                  menuMaxHeight: MediaQuery.sizeOf(context).height * .6,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: SfColors.ink,
                    fontSize: 14,
                    height: 1.25,
                  ),
                  items: [
                    for (final value in views.keys)
                      DropdownMenuItem(
                        value: value,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(viewLabel(value)),
                        ),
                      ),
                  ],
                  onChanged: _busy
                      ? null
                      : (value) {
                          if (value == null) return;
                          setState(() {
                            _overdueOnly = value == 'overdue';
                            if (!_overdueOnly) _tray = value;
                          });
                          _filterChanged();
                        },
                ),
              ),
            ),
            if (_overdueOnly) ...[
              const SizedBox(height: 8),
              Text(
                widget.municipal && widget.initialOfficeId == null
                    ? 'Overdue folders across municipal offices'
                    : 'Overdue folders across active trays',
                style: const TextStyle(fontSize: 13, color: SfColors.muted),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search ID, title or reference',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) {
                _searchTimer?.cancel();
                _searchTimer = Timer(const Duration(milliseconds: 400), () {
                  setState(() => _query = v);
                  _filterChanged();
                });
              },
            ),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              dense: true,
              title: Text(
                'Sort folders · ${switch (_sort) {
                  'waiting' => 'Longest wait',
                  'recent' => 'Latest movement',
                  _ => 'Urgency',
                }}',
                style: const TextStyle(fontSize: 13),
              ),
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _sort,
                  decoration: const InputDecoration(labelText: 'Sort by'),
                  isExpanded: true,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.2,
                    color: SfColors.ink,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'urgency', child: Text('Urgency')),
                    DropdownMenuItem(
                      value: 'waiting',
                      child: Text('Longest wait'),
                    ),
                    DropdownMenuItem(
                      value: 'recent',
                      child: Text('Latest movement'),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() => _sort = value!);
                    _filterChanged();
                  },
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                _trayCounts.isEmpty
                    ? 'Document count unavailable'
                    : _total == 0
                    ? '0 documents'
                    : '${_offset + 1}–${_offset + rows.length} of $_total documents',
                style: const TextStyle(fontSize: 12, color: SfColors.muted),
              ),
            ),
            if (rows.isEmpty && _error == null)
              SfEmptyState(
                icon: Icons.folder_open_outlined,
                title: _query.trim().isNotEmpty
                    ? 'No matching documents'
                    : _overdueOnly
                    ? 'No overdue folders'
                    : 'No documents in this tray.',
                subtitle: _query.trim().isNotEmpty
                    ? 'Try another search or choose another tray.'
                    : _overdueOnly
                    ? 'No overdue folders were found in this view. Choose a tray to browse other folders.'
                    : widget.municipal
                    ? 'Folders registered by municipal offices will appear here.'
                    : _tray == 'incoming'
                    ? 'Folders sent to your office will appear here when they are ready to receive.'
                    : _tray == 'completed'
                    ? 'Completed folders remain here with their QR and movement history.'
                    : readOnly
                    ? 'Office staff register folders and record physical handoffs. Use Scan to look up a labelled folder.'
                    : 'Scan a folder to check its status, or register a new document.',
                actionLabel: widget.municipal ? null : 'Scan a folder',
                onAction: widget.municipal
                    ? null
                    : () {
                        final role = context.read<AuthProvider>().user!.role;
                        context.go('/$role/scan');
                      },
              ),
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SfFormCard(
                  flat: true,
                  padding: const EdgeInsets.all(14),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      row['title'].toString(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        height: 1.35,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${row['id']}\nReference: ${row['reference_no'] ?? '—'}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: SfColors.muted,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          DocumentStatus(document: row),
                          Text(
                            '${row['is_overdue'] == true ? 'Overdue · ' : ''}${row['tray'] == 'completed' ? (_hasFilingEvidence(row) ? 'Filed' : 'Route complete') : 'Waiting ${elapsedLabel(row['hours_waiting'])}'}',
                            style: TextStyle(
                              fontSize: 13,
                              color: row['is_overdue'] == true
                                  ? SfColors.red
                                  : SfColors.muted,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${row['tray'] == 'incoming'
                                ? 'From ${row['current_office_name']}'
                                : row['tray'] == 'forwarded'
                                ? 'To ${row['destination_office_name'] ?? 'Unspecified office'}'
                                : row['current_office_name']}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: SfColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      _selected = row['id'].toString();
                      _load();
                    },
                  ),
                ),
              ),
            if (_total > 50)
              Wrap(
                spacing: 12,
                children: [
                  OutlinedButton(
                    onPressed: _offset == 0
                        ? null
                        : () {
                            _offset = (_offset - 50).clamp(0, 1000000);
                            _load();
                          },
                    child: const Text('Previous page'),
                  ),
                  OutlinedButton(
                    onPressed: !_hasMore
                        ? null
                        : () {
                            _offset += 50;
                            _load();
                          },
                    child: const Text('Next page'),
                  ),
                ],
              ),
          ] else if (doc != null) ...[
            const SizedBox(height: 12),
            SfFormCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DocumentSummary(document: doc),
                  const SizedBox(height: 8),
                  Text(
                    readOnly
                        ? doc['tray'] == 'completed'
                              ? 'Completed at ${doc['current_office_name']}.'
                              : doc['current_status'] == 'OUT'
                              ? 'Awaiting receipt at ${doc['destination_office_name'] ?? 'the receiving office'}.'
                              : 'Currently held by ${doc['current_office_name']}.'
                        : doc['tray'] == 'completed' &&
                              doc['can_return_to_accounting'] != true
                        ? 'Route complete.'
                        : doc['can_return_to_accounting'] == true
                        ? 'Route complete at Treasury. Return to Accounting only if it goes back.'
                        : doc['tray'] == 'incoming'
                        ? 'Next: receive this folder'
                        : doc['can_file'] == true
                        ? 'No fixed route. File it here when the work is done.'
                        : doc['suggested_forward'] is Map
                        ? 'Send to ${(doc['suggested_forward'] as Map)['office_name']}'
                        : doc['tray'] == 'in_office'
                        ? 'Next: send this folder'
                        : 'Waiting on the next office',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: SfColors.ink,
                    ),
                  ),
                  if (!_docFresh)
                    Text(
                      readOnly
                          ? 'Current custody is unverified. Refresh to confirm this record.'
                          : 'Current custody is unverified. Actions stay disabled until the server confirms this record.',
                      style: TextStyle(color: SfColors.red),
                    ),
                  const SizedBox(height: 14),
                  if (readOnly)
                    Text(
                      doc['tray'] == 'elsewhere'
                          ? 'Tracking view · this folder is outside your office tray. Its current holding or receiving office records the handoff.'
                          : 'View custody history below. Office staff record physical handoffs at the holding or receiving office.',
                    )
                  else if (doc['tray'] == 'completed' &&
                      doc['can_return_to_accounting'] != true) ...[
                    const Text(
                      'Route complete. The QR and custody history remain available.',
                    ),
                  ] else if (doc['tray'] == 'incoming') ...[
                    SfPrimaryButton(
                      loading: _busy,
                      onPressed: _busy || !_docFresh ? null : () => _move('IN'),
                      label: _busy ? 'Receiving…' : 'Receive (IN)',
                    ),
                  ] else if (doc['tray'] == 'in_office' ||
                      doc['can_return_to_accounting'] == true) ...[
                    if (doc['can_file'] == true) ...[
                      SfPrimaryButton(
                        loading: _busy,
                        onPressed: _busy || !_docFresh ? null : _file,
                        label: _busy ? 'Filing…' : 'File this folder',
                      ),
                      const SizedBox(height: 10),
                    ],
                    Text(
                      doc['can_file'] == true
                          ? 'Send it only if another office still needs the folder.'
                          : 'Hand over the actual folder. It appears in that office’s Incoming tray.',
                    ),
                    const SizedBox(height: 10),
                    if (doc['can_file'] == true)
                      SfSecondaryOutlineButton(
                        onPressed: _busy || !_docFresh
                            ? null
                            : () => _move('OUT'),
                        label: 'Send (OUT)',
                      )
                    else
                      SfPrimaryButton(
                        loading: _busy,
                        onPressed: _busy || !_docFresh
                            ? null
                            : () => _move('OUT'),
                        label: doc['can_return_to_accounting'] == true
                            ? 'Return to Accounting (OUT)'
                            : 'Send (OUT)',
                      ),
                  ] else
                    const Text(
                      'Awaiting the receiving office’s confirmation. Opening the QR does not mark it IN.',
                    ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            DestinationCorrectionAction(
              document: doc,
              disabled: _busy || !_docFresh,
              onChanged: () => _load(),
            ),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Folder journey'),
              subtitle: const Text('Where this folder has been'),
              children: [DocumentJourney(document: doc)],
            ),
            TextButton(
              onPressed: () {
                final role = context.read<AuthProvider>().user!.role;
                context.go('/$role/history', extra: {'documentId': doc['id']});
              },
              child: const Text('Open full activity history'),
            ),
            const SizedBox(height: 18),
            if (doc['qr_payload'] != null)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('QR label'),
                subtitle: const Text('View the folder’s tracking label'),
                children: [
                  DocumentQrCard(
                    id: doc['id'].toString(),
                    payload: doc['qr_payload'].toString(),
                    showId: false,
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }
}
