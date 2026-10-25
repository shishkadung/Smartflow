import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../data/office_document_types.dart';
import '../../providers/auth_provider.dart';
import '../../models/user.dart';
import '../../services/smartflow_api.dart';
import '../../services/api_client.dart';
import '../../utils/api_error.dart';
import '../../utils/document_types.dart';
import '../../utils/live_refresh.dart';
import '../../theme/smartflow_theme.dart';
import '../../widgets/sf_pdf_chrome.dart';
import '../../widgets/sf_widgets.dart';
import '../../widgets/creation_recovery.dart';
import '../staff/clerk_widgets.dart';

enum _InboxFilter { active, overdue, past, all }

/// Inter-office document requests (access by category or pull from target office).
class DocumentRequestsScreen extends StatefulWidget {
  const DocumentRequestsScreen({
    super.key,
    required this.homeRoute,
    this.initialRequestId,
  });

  final String homeRoute;
  final int? initialRequestId;

  @override
  State<DocumentRequestsScreen> createState() => _DocumentRequestsScreenState();
}

class _DocumentRequestsScreenState extends State<DocumentRequestsScreen>
    with
        SingleTickerProviderStateMixin,
        LiveRefresh<DocumentRequestsScreen>,
        WidgetsBindingObserver {
  late TabController _tabs;
  List<Map<String, dynamic>> _inbox = [];
  List<Map<String, dynamic>> _outbox = [];
  int _pendingInbox = 0;
  bool _loading = true;
  String? _error;
  _InboxFilter _inboxFilter = _InboxFilter.active;
  bool _busy = false;
  int _generation = 0;
  int _page = 1;
  int _activeTab = 0;
  final _searchController = TextEditingController();
  String _search = '';
  Map<String, dynamic> _inboxMeta = {};
  Map<String, dynamic> _outboxMeta = {};
  Object? _loadedQuery;
  late Object _accountKey;
  bool _listFresh = false;
  bool _detailsLoading = false;
  String? _detailsError;
  Map<String, dynamic>? _detailsTarget;
  bool _detailsInbox = false;

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

  Object get _queryKey => (_identity, _activeTab, _page, _inboxFilter, _search);

  @override
  Future<void> refreshLiveData() => _load(silent: true);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _accountKey = _identity;
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(() {
      if (mounted && _activeTab != _tabs.index) {
        setState(() {
          _activeTab = _tabs.index;
          _page = 1;
        });
        _load();
      }
    });
    _load().then((_) => _openInitialRequest());
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
      _busy = false;
      _detailsTarget = null;
      _detailsError = null;
      _load();
    }
  }

  @override
  void didUpdateWidget(covariant DocumentRequestsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialRequestId != widget.initialRequestId) {
      _openInitialRequest();
    }
  }

  Future<void> _openInitialRequest() async {
    final id = widget.initialRequestId;
    if (id == null || !mounted) return;
    final identity = _identity;
    try {
      final api = context.read<AuthProvider>().api;
      final data = await Future.wait([
        api.documentRequestsList(view: 'inbox', requestId: id),
        api.documentRequestsList(view: 'outbox', requestId: id),
      ]);
      if (!mounted || widget.initialRequestId != id || identity != _identity) {
        return;
      }
      final inbox = _parseList(data[0]);
      final outbox = _parseList(data[1]);
      final matches = [...inbox, ...outbox].where((r) => r['id'] == id);
      if (matches.isEmpty) {
        setState(
          () => _error =
              'This request is unavailable in your inbox or My requests.',
        );
      } else {
        await _details(
          matches.first,
          inbox.any((r) => r['id'] == id),
          verified: true,
        );
      }
    } catch (e) {
      if (mounted && identity == _identity) {
        setState(() => _error = apiErrorMessage(e));
      }
    }
  }

  @override
  void didChangeMetrics() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabs.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!mounted || (silent && (_loading || _busy))) return;
    final generation = ++_generation;
    final query = _queryKey;
    final sameQuery = _loadedQuery == query;
    setState(() {
      if (!silent || !sameQuery) _loading = true;
      _listFresh = false;
      if (!sameQuery) {
        _inbox = [];
        _outbox = [];
        _inboxMeta = {};
        _outboxMeta = {};
        _pendingInbox = 0;
        _loadedQuery = null;
        _error = null;
      }
    });
    try {
      final api = context.read<AuthProvider>().api;
      final data = await Future.wait([
        api.documentRequestsList(
          view: 'inbox',
          page: _activeTab == 0 ? _page : 1,
          status: switch (_inboxFilter) {
            _InboxFilter.active => 'active',
            _InboxFilter.past => 'past',
            _ => null,
          },
          overdue: _inboxFilter == _InboxFilter.overdue,
          search: _search,
        ),
        api.documentRequestsList(
          view: 'outbox',
          page: _activeTab == 1 ? _page : 1,
          status: switch (_inboxFilter) {
            _InboxFilter.active => 'active',
            _InboxFilter.past => 'past',
            _ => null,
          },
          overdue: _inboxFilter == _InboxFilter.overdue,
          search: _search,
        ),
      ]);
      final inbox = data[0];
      final outbox = data[1];
      if (!mounted || generation != _generation || query != _queryKey) return;
      setState(() {
        _inbox = _parseList(inbox);
        _outbox = _parseList(outbox);
        _pendingInbox = (inbox['pending_inbox_count'] as int?) ?? 0;
        _inboxMeta = inbox;
        _outboxMeta = outbox;
        _loadedQuery = query;
        _listFresh = true;
        _error = null;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (mounted && generation == _generation && query == _queryKey) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted && generation == _generation && query == _queryKey) {
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

  Map<String, dynamic> get _currentMeta =>
      _activeTab == 0 ? _inboxMeta : _outboxMeta;
  int get _inboxActiveCount =>
      ((_currentMeta['counts'] as Map?)?['active'] as num?)?.toInt() ??
      (_activeTab == 0 ? _inbox : _outbox)
          .where((r) => ['pending', 'approved'].contains(r['status']))
          .length;

  int get _inboxPastCount =>
      ((_currentMeta['counts'] as Map?)?['past'] as num?)?.toInt() ??
      (_activeTab == 0 ? _inbox : _outbox)
          .where(
            (r) => ['fulfilled', 'rejected', 'cancelled'].contains(r['status']),
          )
          .length;

  int get _inboxOverdueCount =>
      ((_currentMeta['counts'] as Map?)?['overdue'] as num?)?.toInt() ??
      (_activeTab == 0 ? _inbox : _outbox)
          .where((r) => r['is_overdue'] == true)
          .length;

  List<Map<String, dynamic>> get _filteredInbox {
    return _inbox;
  }

  void _changeFilter(_InboxFilter filter) {
    if (_busy) return;
    setState(() {
      _inboxFilter = filter;
      _page = 1;
    });
    _load();
  }

  void _searchRequests(String value) {
    if (_busy) return;
    setState(() {
      _search = value.trim();
      _page = 1;
    });
    _load();
  }

  Future<void> _openCreate() async {
    final identity = _identity;
    final created = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CreateRequestSheet(homeRoute: widget.homeRoute),
    );
    if (created != null && mounted && identity == _identity) {
      final request = created['request'];
      if (request is! Map || request['id'] is! num) {
        await _load();
        if (mounted) {
          setState(
            () => _detailsError =
                'Request saved, but its details were not returned. Refresh My requests to find it.',
          );
        }
        return;
      }
      final target = Map<String, dynamic>.from(request);
      HapticFeedback.lightImpact();
      sfShowSuccessSnack(
        context,
        message:
            'Request sent — ${request['request_code'] ?? 'ticket ${request['id']}'}',
        actionLabel: 'View',
        onAction: () {
          if (!_detailsLoading && !_busy) _details(target, false);
        },
      );
      await _load(silent: true);
      if (mounted) await _details(target, false);
    }
  }

  Future<void> _act(
    Map<String, dynamic> req,
    String action, {
    required Object expectedIdentity,
    bool? inbox,
  }) async {
    if (!mounted || _busy || expectedIdentity != _identity) return;
    final auth = context.read<AuthProvider>();
    if (auth.loggingOut) return;
    final identity = _identity;
    final api = auth.api;
    final reviewed = Map<String, dynamic>.from(req);
    // Reserve the decision before confirmation so a retained row callback cannot
    // open a second decision while this one is awaiting the user's response.
    setState(() => _busy = true);
    try {
      final notes = await _confirmAction(reviewed, action);
      if (!mounted ||
          notes == null ||
          identity != _identity ||
          auth.loggingOut) {
        return;
      }
      await api.documentRequestUpdate(
        requestId: (reviewed['id'] as num).toInt(),
        action: action,
        reviewNotes: notes.isEmpty ? null : notes,
        relatedDocumentId: action == 'fulfill'
            ? reviewed['related_document_id']?.toString()
            : null,
        expectedStatus: reviewed['status']?.toString(),
        expectedRevision: reviewed['revision']?.toString(),
      );
      if (mounted && identity == _identity) {
        final msg = switch (action) {
          'approve' =>
            'Accepted — open details to link or register the physical folder',
          'reject' => 'Declined — also notify the requester by phone or memo',
          'fulfill' => _fulfillSuccessMessage(req),
          'cancel' => 'Request cancelled',
          _ => 'Request updated',
        };
        HapticFeedback.lightImpact();
        sfShowSuccessSnack(
          context,
          message: msg,
          backgroundColor: action == 'reject' ? SfColors.gold : SfColors.green,
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
    } catch (e) {
      if (mounted && identity == _identity) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(apiErrorMessage(e)),
            backgroundColor: SfColors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
        if (e is ApiException && e.statusCode == 409) {
          await _load();
          if (mounted && identity == _identity && inbox != null) {
            setState(() => _busy = false);
            if (!auth.loggingOut) await _details(reviewed, inbox);
          }
        }
      }
    } finally {
      if (mounted && identity == _identity) setState(() => _busy = false);
    }
  }

  /// Returns null when cancelled, otherwise the trimmed notes (may be empty unless declining).
  Future<String?> _confirmAction(
    Map<String, dynamic> req,
    String action,
  ) async {
    var notes = '';
    final requireNotes = action == 'reject';
    final paymentRelease = action == 'fulfill' && _isDisbursement(req);
    final title = switch (action) {
      'approve' => 'Accept request',
      'reject' => 'Decline request',
      'cancel' => 'Cancel request',
      _ => paymentRelease ? 'Mark payment released' : 'Close request',
    };
    final explanation = switch (action) {
      'approve' =>
        'Accepting records your office’s review. It does not receive, send or complete the physical folder.',
      'cancel' =>
        'Cancelling closes this ticket for both offices and cannot be undone. It records no physical handoff. Existing folder custody and history remain unchanged.',
      'reject' => 'Explain why your office cannot accept this request.',
      _ =>
        paymentRelease
            ? 'Confirm only after Treasury has actually released the payment.'
            : 'Confirm that the requested work is complete. Closing this ticket does not record a physical handoff.',
    };
    final notesLabel = switch (action) {
      'approve' => 'Review notes (optional)',
      'reject' => 'Decline notes (required)',
      'cancel' => 'Cancellation notes (optional)',
      _ => 'Closing notes (optional)',
    };
    final linked = req['related_document_id']?.toString().trim() ?? '';
    final purpose = req['purpose']?.toString().trim() ?? '';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          scrollable: true,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          title: Text(title),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${req['request_code'] ?? 'Request ${req['id']}'}',
                style: Theme.of(ctx).textTheme.labelLarge,
              ),
              if (purpose.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Purpose', style: Theme.of(ctx).textTheme.labelMedium),
                const SizedBox(height: 2),
                Text(purpose),
              ],
              const SizedBox(height: 8),
              Text(explanation),
              if (action == 'fulfill') ...[
                const SizedBox(height: 12),
                Text(
                  linked.isNotEmpty
                      ? 'Linked folder: $linked'
                      : 'No folder linked. If a folder is involved, cancel and select or register it from Request details first.',
                  style: Theme.of(ctx).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 16),
              TextField(
                decoration: InputDecoration(
                  label: Text(notesLabel),
                  alignLabelWithHint: true,
                ),
                minLines: 2,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (value) => setDialogState(() => notes = value),
              ),
              if (requireNotes) ...[
                const SizedBox(height: 12),
                Text(
                  'A separate notice (phone call or memo) to the requester is also required.',
                  style: Theme.of(ctx).textTheme.bodySmall,
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(action == 'cancel' ? 'Keep request' : 'Cancel'),
            ),
            FilledButton(
              style: action == 'reject' || action == 'cancel'
                  ? FilledButton.styleFrom(backgroundColor: SfColors.red)
                  : null,
              onPressed: requireNotes && notes.trim().isEmpty
                  ? null
                  : () => Navigator.pop(ctx, true),
              child: Text(title),
            ),
          ],
        ),
      ),
    );
    return ok == true ? notes.trim() : null;
  }

  Future<void> _linkFolder(
    Map<String, dynamic> req, {
    required Object expectedIdentity,
  }) async {
    if (!mounted || _busy || expectedIdentity != _identity) return;
    final auth = context.read<AuthProvider>();
    if (auth.loggingOut) return;
    final identity = _identity;
    final api = auth.api;
    setState(() => _busy = true);
    try {
      final id = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        builder: (_) => RequestFolderPicker(request: req),
      );
      if (!mounted || id == null || identity != _identity || auth.loggingOut) {
        return;
      }
      await api.documentRequestUpdate(
        requestId: (req['id'] as num).toInt(),
        action: 'link',
        relatedDocumentId: id,
        expectedStatus: req['status']?.toString(),
        expectedRevision: req['revision']?.toString(),
      );
      if (!mounted || identity != _identity) return;
      sfShowSuccessSnack(
        context,
        message:
            'Folder linked — physical custody still uses Receive (IN) / Send (OUT).',
      );
      await _load();
    } catch (e) {
      if (mounted && identity == _identity) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
      }
    } finally {
      if (mounted && identity == _identity) setState(() => _busy = false);
    }
  }

  Future<void> _details(
    Map<String, dynamic> req,
    bool inbox, {
    bool verified = false,
  }) async {
    if (_detailsLoading) return;
    final identity = _identity;
    setState(() {
      _detailsLoading = true;
      _detailsTarget = req;
      _detailsInbox = inbox;
    });
    try {
      if (!verified) {
        final response = await context
            .read<AuthProvider>()
            .api
            .documentRequestsList(
              view: inbox ? 'inbox' : 'outbox',
              requestId: (req['id'] as num).toInt(),
            );
        if (!mounted || identity != _identity) return;
        final matches = _parseList(
          response,
        ).where((row) => row['id'] == req['id']);
        if (matches.isEmpty) {
          throw ApiException(
            'This request is no longer available in this view.',
          );
        }
        req = matches.first;
      }
      setState(() {
        _detailsTarget = req;
        _detailsError = null;
      });
    } catch (e) {
      if (mounted && identity == _identity) {
        setState(() => _detailsError = apiErrorMessage(e));
      }
      return;
    } finally {
      if (mounted) setState(() => _detailsLoading = false);
    }
    if (!mounted || identity != _identity) return;
    final user = context.read<AuthProvider>().user!;
    final handler = req['handler_office'] as Map<String, dynamic>? ?? {};
    final canLink =
        req['status'] == 'approved' &&
        (user.role == 'admin' || handler['office_id'] == user.officeId);
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => RequestDetailsSheet(
        request: req,
        inbox: inbox,
        canLink: canLink,
        myOfficeCode: user.officeCode,
      ),
    );
    if (!mounted || result == null || identity != _identity) return;
    if (result == 'link') {
      await _linkFolder(req, expectedIdentity: identity);
    } else if (result == 'register') {
      await context.push(
        '${widget.homeRoute}/register?request_id=${req['id']}',
        extra: {'request': req},
      );
      if (mounted) await _load();
    } else if (result == 'folder') {
      final id = Uri.encodeQueryComponent(
        req['related_document_id'].toString(),
      );
      final scope = user.role == 'admin' ? '&scope=municipal' : '';
      await context.push(
        '${widget.homeRoute}/documents?id=$id$scope',
        extra: {'fromRequest': true},
      );
      if (!mounted) return;
      await _load(silent: true);
      if (!mounted) return;
      await _details(req, inbox);
    } else if (result == 'history') {
      context.push(
        '${widget.homeRoute}/history',
        extra: {'documentId': req['related_document_id'].toString()},
      );
    } else {
      await _act(req, result, expectedIdentity: identity, inbox: inbox);
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AuthProvider>();
    final onInbox = _tabs.index == 0;
    final tabHeight = MediaQuery.textScalerOf(
      context,
    ).scale(32).clamp(48.0, 72.0).toDouble();
    final createHeight =
        (MediaQuery.textScalerOf(context).scale(14) * 1.25 + 32).clamp(
          56.0,
          double.infinity,
        );
    final listBottomPadding = createHeight + 48;

    return Scaffold(
      backgroundColor: SfColors.bg,
      // The role shell already resizes the page above the keyboard.
      resizeToAvoidBottomInset: false,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      // The outer Scaffold consumes MediaQuery's keyboard inset when resizing.
      floatingActionButton: View.of(context).viewInsets.bottom > 0
          ? null
          : Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.paddingOf(context).bottom,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width - 32,
                ),
                child: FilledButton.icon(
                  onPressed: _busy ? null : _openCreate,
                  style: FilledButton.styleFrom(
                    minimumSize: Size(0, createHeight),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    elevation: 3,
                    shadowColor: SfColors.navy.withValues(alpha: 0.2),
                    textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontSize: 14,
                      height: 1.25,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 20),
                  label: const Text('New request'),
                ),
              ),
            ),
      body: SafeArea(
        top: false,
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SfAuthenticatedPageHeader(
                          fallbackRoute: widget.homeRoute,
                          hideBackOnRoleHome: false,
                        ),
                        const SizedBox(height: 6),
                        const SfPageTitle(title: 'Requests'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (_error != null &&
                      (_inbox.isNotEmpty || _outbox.isNotEmpty))
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SfErrorBanner(
                            message:
                                'Refresh failed. Showing the last loaded requests. $_error',
                          ),
                          TextButton(
                            onPressed: _busy || _loading ? null : _load,
                            child: const Text('Retry requests'),
                          ),
                        ],
                      ),
                    ),
                  if (_detailsLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 8,
                      ),
                      child: LinearProgressIndicator(),
                    ),
                  if (_detailsError != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 8,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SfErrorBanner(
                            message:
                                'Request details unavailable. Actions stay disabled until this ticket is verified. $_detailsError',
                          ),
                          Wrap(
                            spacing: 8,
                            children: [
                              if (_detailsTarget != null)
                                TextButton(
                                  onPressed: _detailsLoading || _busy
                                      ? null
                                      : () => _details(
                                          _detailsTarget!,
                                          _detailsInbox,
                                        ),
                                  child: const Text('Retry request'),
                                ),
                              TextButton(
                                onPressed: _detailsLoading || _busy
                                    ? null
                                    : () => setState(() {
                                        _detailsTarget = null;
                                        _detailsError = null;
                                      }),
                                child: const Text('Back to requests'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  if (!_loading &&
                      !_listFresh &&
                      _error == null &&
                      (_inbox.isNotEmpty || _outbox.isNotEmpty))
                    const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 8,
                      ),
                      child: Text(
                        'Refreshing requests. Actions are temporarily disabled.',
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5EBF3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TabBar(
                        controller: _tabs,
                        labelColor: SfColors.navy,
                        unselectedLabelColor: SfColors.muted,
                        indicatorSize: TabBarIndicatorSize.tab,
                        indicatorPadding: const EdgeInsets.all(4),
                        dividerColor: Colors.transparent,
                        indicator: BoxDecoration(
                          color: SfColors.paper,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        labelStyle: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                        tabs: [
                          Tab(
                            height: tabHeight,
                            child: Text(
                              _pendingInbox > 0
                                  ? 'Inbox ($_pendingInbox)'
                                  : 'Inbox',
                              softWrap: true,
                              maxLines: 2,
                              textAlign: TextAlign.center,
                              style: const TextStyle(height: 1.1),
                            ),
                          ),
                          Tab(
                            height: tabHeight,
                            child: const Text(
                              'My requests',
                              softWrap: true,
                              maxLines: 2,
                              textAlign: TextAlign.center,
                              style: TextStyle(height: 1.1),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 6, 18, 0),
                    child: Text(
                      '${onInbox ? 'Requests for your office.' : 'Tickets you created.'} '
                      'Tickets do not record physical handoffs.',
                      style: const TextStyle(
                        color: SfColors.muted,
                        fontSize: 13,
                        height: 1.3,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
                    child: TextField(
                      controller: _searchController,
                      enabled: !_busy,
                      textInputAction: TextInputAction.search,
                      onSubmitted: _searchRequests,
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        labelText: 'Search requests',
                        hintText: 'Request ID, purpose, or linked folder',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _search.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Clear search',
                                icon: const Icon(Icons.close_rounded),
                                onPressed: _busy
                                    ? null
                                    : () {
                                        _searchController.clear();
                                        _searchRequests('');
                                      },
                              ),
                      ),
                    ),
                  ),
                  if (!_loading && _error == null) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 4, 18, 0),
                      child: _InboxFilterChips(
                        active: _inboxActiveCount,
                        past: _inboxPastCount,
                        overdue: _inboxOverdueCount,
                        total:
                            ((_currentMeta['counts'] as Map?)?['total'] as num?)
                                ?.toInt() ??
                            (onInbox ? _inbox.length : _outbox.length),
                        selected: _inboxFilter,
                        onSelected: _changeFilter,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          body: RefreshIndicator(
            onRefresh: _load,
            color: SfColors.blue,
            child: _loading
                ? ListView(
                    padding: EdgeInsets.fromLTRB(18, 16, 18, listBottomPadding),
                    children: const [SfLoadingCard()],
                  )
                : _error != null && _inbox.isEmpty && _outbox.isEmpty
                ? ListView(
                    padding: EdgeInsets.fromLTRB(18, 18, 18, listBottomPadding),
                    children: [
                      SfErrorBanner(message: 'Requests unavailable. $_error'),
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
                        bottomPadding: listBottomPadding,
                        filterEmpty:
                            _inbox.isNotEmpty && _filteredInbox.isEmpty,
                      ),
                      _listView(
                        _outbox,
                        inbox: false,
                        bottomPadding: listBottomPadding,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _listView(
    List<Map<String, dynamic>> items, {
    required bool inbox,
    required double bottomPadding,
    bool filterEmpty = false,
  }) {
    final identity = _identity;
    final query = _queryKey;
    void act(Map<String, dynamic> request, String action) {
      if (!mounted ||
          query != _queryKey ||
          _loadedQuery != query ||
          !_listFresh ||
          _detailsError != null) {
        return;
      }
      _act(request, action, expectedIdentity: identity, inbox: inbox);
    }

    final meta = inbox ? _inboxMeta : _outboxMeta;
    final total = (meta['total'] as num?)?.toInt() ?? items.length;
    final page = (meta['page'] as num?)?.toInt() ?? _page;
    final pageSize = (meta['page_size'] as num?)?.toInt() ?? 25;
    final filtered = _inboxFilter != _InboxFilter.all || _search.isNotEmpty;
    if (filterEmpty) {
      return ListView(
        padding: EdgeInsets.fromLTRB(18, 16, 18, bottomPadding),
        children: [
          SfEmptyState(
            icon: Icons.filter_list_off_outlined,
            title: _error != null
                ? 'Last loaded list: no requests in this filter'
                : 'No requests in this filter',
            subtitle: _error != null
                ? 'The latest refresh failed, so this may be out of date. Retry requests to confirm.'
                : 'Try All to see every ticket in your inbox.',
            actionLabel: 'Show all',
            onAction: () => _changeFilter(_InboxFilter.all),
          ),
        ],
      );
    }
    if (items.isEmpty) {
      return ListView(
        padding: EdgeInsets.fromLTRB(18, 16, 18, bottomPadding),
        children: [
          SfEmptyState(
            icon: inbox ? Icons.inbox_outlined : Icons.send_outlined,
            title: _error != null
                ? 'Last loaded list: no requests shown'
                : filtered
                ? 'No requests in this filter'
                : inbox
                ? 'No requests for this office'
                : 'No requests yet',
            subtitle: _error != null
                ? 'The latest refresh failed, so this may be out of date. Retry requests to confirm.'
                : filtered
                ? 'Active includes pending and accepted tickets. Choose Past for closed, declined or cancelled tickets, or All for every ticket.'
                : inbox
                ? 'Requests sent to your office will appear here.'
                : 'Create a request when another office holds the folder.',
          ),
        ],
      );
    }
    return ListView(
      padding: EdgeInsets.fromLTRB(18, 12, 18, bottomPadding),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            '$total requests',
            style: const TextStyle(color: SfColors.muted, fontSize: 12),
          ),
        ),
        SfFormCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0)
                  const Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    color: Color(0xFFE1E6ED),
                  ),
                _RequestCard(
                  request: items[i],
                  inbox: inbox,
                  myOfficeCode: context.read<AuthProvider>().user!.officeCode,
                  onApprove: () => act(items[i], 'approve'),
                  onReject: () => act(items[i], 'reject'),
                  onFulfill: () => act(items[i], 'fulfill'),
                  onCancel: () => act(items[i], 'cancel'),
                  onDetails: () => _details(items[i], inbox),
                  busy: _busy || _loading || _detailsLoading,
                  actionsEnabled: _listFresh && _detailsError == null,
                ),
              ],
            ],
          ),
        ),
        if (total > pageSize) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton(
                onPressed: _busy || _loading || page <= 1
                    ? null
                    : () {
                        setState(() => _page = page - 1);
                        _load();
                      },
                child: const Text('Previous'),
              ),
              Text('Page $page of ${(total / pageSize).ceil()}'),
              OutlinedButton(
                onPressed: _busy || _loading || meta['has_more'] != true
                    ? null
                    : () {
                        setState(() => _page = page + 1);
                        _load();
                      },
                child: const Text('Next'),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Full request record; actions return to the owning page for a fresh server decision.
class RequestDetailsSheet extends StatelessWidget {
  const RequestDetailsSheet({
    super.key,
    required this.request,
    required this.inbox,
    required this.canLink,
    required this.myOfficeCode,
  });
  final Map<String, dynamic> request;
  final bool inbox;
  final bool canLink;
  final String myOfficeCode;

  @override
  Widget build(BuildContext context) {
    final r = request;
    final requester = r['requester'] as Map<String, dynamic>? ?? {};
    final handler = r['handler_office'] as Map<String, dynamic>? ?? {};
    final status = '${r['status'] ?? ''}';
    final linked = '${r['related_document_id'] ?? ''}'.trim();
    final fields = <String, String>{
      'Category': _categoryLabel('${r['document_category'] ?? ''}'),
      'Requester':
          '${requester['name'] ?? '—'} · @${requester['username'] ?? '—'}',
      'Requesting office':
          '${requester['office_name'] ?? requester['office_code'] ?? '—'}',
      'Handling office':
          '${handler['office_name'] ?? handler['office_code'] ?? '—'}',
      'Required by':
          '${r['required_by_display'] ?? r['required_by'] ?? '—'}${r['is_overdue'] == true ? ' · Overdue' : ''}',
      'Created': '${r['created_at'] ?? '—'}',
      if (r['updated_at'] != null) 'Updated': '${r['updated_at']}',
      if (linked.isNotEmpty) 'Linked folder': linked,
    };
    void action(String value) => Navigator.pop(context, value);
    final physicalType = switch (r['document_category']) {
      'budget' => 'Approved Budget',
      'disbursement' => 'Disbursement Voucher',
      _ => kOtherDocumentType,
    };
    final user = context.read<AuthProvider>().user!;
    final canRecordPaymentRelease = _canRecordPaymentRelease(
      role: user.role,
      officeCode: myOfficeCode,
    );
    final canRegister =
        user.role == 'staff' &&
        handler['office_id'] == user.officeId &&
        documentTypesForOffice(user.officeCode).contains(physicalType);
    final actions = <Widget>[
      if (linked.isNotEmpty)
        OutlinedButton.icon(
          onPressed: () => action('folder'),
          icon: const Icon(Icons.folder_open_outlined),
          label: const Text('Open linked folder in Documents'),
        ),
      if (linked.isNotEmpty)
        TextButton.icon(
          onPressed: () => action('history'),
          icon: const Icon(Icons.history),
          label: const Text('View custody history'),
        ),
      if (status == 'approved' && canLink && linked.isEmpty) ...[
        FilledButton.icon(
          onPressed: () => action('link'),
          icon: const Icon(Icons.link),
          label: const Text('Select existing folder'),
        ),
        if (canRegister)
          OutlinedButton.icon(
            onPressed: () => action('register'),
            icon: const Icon(Icons.create_new_folder_outlined),
            label: const Text('Register new physical folder'),
          ),
      ],
      if (inbox && status == 'pending') ...[
        FilledButton(
          onPressed: () => action('approve'),
          child: const Text('Accept request'),
        ),
        TextButton(
          onPressed: () => action('reject'),
          child: const Text('Decline request'),
        ),
      ],
      if (inbox &&
          status == 'approved' &&
          (!_isDisbursement(r) || canRecordPaymentRelease))
        OutlinedButton(
          onPressed: () => action('fulfill'),
          child: Text(
            _isDisbursement(r) ? 'Mark payment released' : 'Close request',
          ),
        ),
      if (!inbox && (status == 'pending' || status == 'approved'))
        TextButton(
          onPressed: () => action('cancel'),
          child: const Text('Cancel request'),
        ),
    ];
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .88,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${r['request_code'] ?? 'Request details'}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: SfColors.navy,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _RequestStatusBadge(request: r),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    tooltip: 'Close details',
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE1E6ED)),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const Text(
                    'Purpose',
                    style: TextStyle(color: SfColors.muted, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  SelectableText(
                    '${r['purpose'] ?? '—'}',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      height: 1.45,
                      color: SfColors.ink,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SfInfoBanner(text: _requestNextStep(r, inbox)),
                  const SizedBox(height: 24),
                  for (final field in fields.entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            field.key,
                            style: const TextStyle(
                              color: SfColors.muted,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          SelectableText(
                            field.value,
                            style: const TextStyle(fontSize: 15, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  RequestDecisionHistory(request: r),
                  if (status == 'approved') ...[
                    const SizedBox(height: 16),
                    const SfInfoBanner(
                      text:
                          'Acceptance authorizes the request. Link an existing folder or register only an actual unlabelled folder. Linking does not record a physical handoff.',
                    ),
                    if (_isDisbursement(r) && !canRecordPaymentRelease)
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Text(
                          'Treasury records payment release before this DV request closes.',
                        ),
                      ),
                  ],
                ],
              ),
            ),
            if (actions.isNotEmpty)
              Container(
                decoration: const BoxDecoration(
                  color: SfColors.paper,
                  border: Border(top: BorderSide(color: Color(0xFFE1E6ED))),
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * .36,
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < actions.length; i++) ...[
                          if (i > 0) const SizedBox(height: 8),
                          actions[i],
                        ],
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The API marks historical mixed notes; never infer an initial decision from them.
class RequestDecisionHistory extends StatelessWidget {
  const RequestDecisionHistory({super.key, required this.request});
  final Map<String, dynamic> request;

  @override
  Widget build(BuildContext context) {
    final r = request;
    final status = '${r['status'] ?? ''}';
    final terminal = status == 'fulfilled' || status == 'cancelled';
    final legacyNotes =
        r['review_notes_kind'] == 'legacy' ||
        (terminal &&
            r['review_notes_kind'] == null &&
            (status == 'fulfilled'
                ? r['fulfilled_notes'] == null
                : r['cancelled_notes'] == null));
    final reviewedAt = r['reviewed_at']?.toString();
    final reviewNotes = r['review_notes']?.toString();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!legacyNotes &&
            (reviewedAt != null ||
                reviewNotes != null ||
                r['reviewer'] != null))
          _RequestHistoryEntry(
            title: status == 'rejected' ? 'Decline' : 'Review',
            at: reviewedAt,
            actor: r['reviewer'] as Map?,
            notes: reviewNotes,
            notesLabel: status == 'rejected'
                ? 'Decline reason'
                : 'Review notes',
          ),
        if (status == 'fulfilled')
          _RequestHistoryEntry(
            title: _isDisbursement(r) ? 'Payment release' : 'Closing',
            at: r['fulfilled_at']?.toString(),
            actor: r['fulfiller'] as Map?,
            notes: r['fulfilled_notes']?.toString(),
            notesLabel: _isDisbursement(r)
                ? 'Payment release notes'
                : 'Closing notes',
            unknownNotes:
                'Separate outcome notes were not recorded for this older request.',
          ),
        if (status == 'cancelled')
          _RequestHistoryEntry(
            title: 'Cancellation',
            at: r['cancelled_at']?.toString(),
            actor: r['canceller'] as Map?,
            notes: r['cancelled_notes']?.toString(),
            notesLabel: 'Cancellation notes',
            unknownNotes:
                'Separate cancellation notes were not recorded for this older request.',
          ),
        if (legacyNotes &&
            (reviewNotes != null ||
                reviewedAt != null ||
                r['reviewer'] != null)) ...[
          _RequestHistoryEntry(
            title: 'Existing recorded notes',
            notesLabel: 'Recorded notes',
            at: reviewedAt,
            actor: r['reviewer'] as Map?,
            notes: reviewNotes,
            showMetadata: reviewedAt != null || r['reviewer'] != null,
          ),
          const Text(
            'This older record does not separate initial review from the final outcome. The notes and recorded metadata may refer to either stage.',
            style: TextStyle(color: SfColors.muted, fontSize: 13),
          ),
        ],
      ],
    );
  }
}

class _RequestHistoryEntry extends StatelessWidget {
  const _RequestHistoryEntry({
    required this.title,
    required this.notesLabel,
    this.at,
    this.actor,
    this.notes,
    this.unknownNotes,
    this.showMetadata = true,
  });
  final String title;
  final String notesLabel;
  final String? at;
  final Map? actor;
  final String? notes;
  final String? unknownNotes;
  final bool showMetadata;

  @override
  Widget build(BuildContext context) {
    final name = actor?['name']?.toString().trim() ?? '';
    final username = actor?['username']?.toString().trim() ?? '';
    final office = actor?['office_name']?.toString().trim() ?? '';
    final officeCode = actor?['office_code']?.toString().trim() ?? '';
    final actorLabel = name.isNotEmpty
        ? name
        : username.isNotEmpty
        ? '@$username'
        : 'Actor not recorded';
    final officeLabel = office.isNotEmpty
        ? office
        : officeCode.isNotEmpty
        ? officeCode
        : 'Office not recorded';
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          if (showMetadata) ...[
            SelectableText(
              '$actorLabel · $officeLabel',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              at == null || at!.isEmpty ? 'Time not recorded' : at!,
              style: const TextStyle(color: SfColors.muted, fontSize: 13),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            notesLabel,
            style: const TextStyle(color: SfColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 4),
          SelectableText(
            notes == null
                ? unknownNotes ?? 'Notes not recorded.'
                : notes!.trim().isEmpty
                ? 'No notes added.'
                : notes!,
            style: const TextStyle(fontSize: 15, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class RequestFolderPicker extends StatefulWidget {
  const RequestFolderPicker({super.key, required this.request});
  final Map<String, dynamic> request;
  @override
  State<RequestFolderPicker> createState() => _RequestFolderPickerState();
}

class _RequestFolderPickerState extends State<RequestFolderPicker> {
  List<Map<String, dynamic>> _folders = [];
  String _query = '';
  String? _error;
  bool _loading = true;
  bool _matchesCategory(Map<String, dynamic> d) =>
      switch (widget.request['document_category']) {
        'budget' => isApprovedBudgetDocumentType('${d['type']}'),
        'disbursement' => isDisbursementDocumentType('${d['type']}'),
        'other' => isOtherDocumentType('${d['type']}'),
        _ => true,
      };
  Future<void> _lookup() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await context.read<AuthProvider>().api.documentShow(
        _query.trim(),
      );
      final folder = Map<String, dynamic>.from(data['document'] as Map);
      if (!_matchesCategory(folder)) {
        throw ApiException('This folder does not match the request category.');
      }
      if (mounted) {
        setState(() {
          _folders.removeWhere((d) => d['id'] == folder['id']);
          _folders.add(folder);
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final auth = context.read<AuthProvider>();
      final data = auth.user!.role == 'admin'
          ? await auth.api.municipalDocuments()
          : await auth.api.officeDocuments();
      if (!mounted) return;
      setState(() {
        _folders = (data['documents'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .where(_matchesCategory)
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = apiErrorMessage(e);
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = _folders
        .where(
          (d) => '${d['id']} ${d['title']} ${d['reference_no'] ?? ''}'
              .toLowerCase()
              .contains(_query.toLowerCase()),
        )
        .toList();
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .8,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Select existing folder',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Text(
                'Choose the folder that answers this request. The server verifies handling-office access and category.',
              ),
              const SizedBox(height: 12),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Search tracking ID, title or reference',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
              if (_query.trim().isNotEmpty)
                TextButton.icon(
                  onPressed: _loading ? null : _lookup,
                  icon: const Icon(Icons.manage_search),
                  label: const Text(
                    'Look up this exact tracking ID (including past handoffs)',
                  ),
                ),
              if (_loading) const LinearProgressIndicator(),
              if (_error != null) ...[
                SfErrorBanner(message: _error!),
                TextButton(onPressed: _load, child: const Text('Try again')),
              ],
              Expanded(
                child: ListView(
                  children: [
                    if (!_loading && _error == null && rows.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          'No matching accessible folders. Register only if the physical folder has no tracking ID.',
                        ),
                      ),
                    for (final d in rows)
                      ListTile(
                        title: Text('${d['title']}'),
                        subtitle: Text(
                          '${d['id']} · ${d['type']}\nReference: ${d['reference_no'] ?? '—'}',
                        ),
                        isThreeLine: true,
                        trailing: const Icon(Icons.link),
                        onTap: () => Navigator.pop(context, '${d['id']}'),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _requestNextStep(Map<String, dynamic> request, bool inbox) {
  final status = request['status'];
  if (status == 'pending') {
    return inbox
        ? 'Review the full purpose, then accept or decline this request.'
        : 'Waiting for the handling office to review this request.';
  }
  if (status == 'approved') {
    if (_isDisbursement(request)) {
      return 'Accepted. Physical folder handoffs remain separate. Payment release must be recorded after the actual release.';
    }
    return 'Accepted. The handling office completes the requested work, then closes the ticket. Linking a folder records no handoff.';
  }
  if (status == 'fulfilled') {
    return _isDisbursement(request)
        ? 'Payment release was recorded. This request is closed.'
        : 'The requested work was marked complete. Review the closing notes below.';
  }
  if (status == 'rejected') {
    return 'This request was declined. Review the reason below.';
  }
  return 'This request was cancelled. Its details remain available for reference.';
}

String _fulfillSuccessMessage(Map<String, dynamic> req) {
  final cat = req['document_category']?.toString().toLowerCase() ?? '';
  if (cat == 'disbursement') {
    return 'Payment release recorded — request closed';
  }
  return 'Request closed — requested work complete';
}

bool _isDisbursement(Map<String, dynamic> request) =>
    (request['document_category']?.toString().toLowerCase() ?? '') ==
    'disbursement';

bool _canRecordPaymentRelease({
  required String role,
  required String officeCode,
}) => role == 'admin' || officeCode.toUpperCase() == 'TRE';

String _requestStatusLabel(String status, {bool disbursement = false}) {
  switch (status) {
    case 'pending':
      return 'Pending';
    case 'approved':
      return 'Accepted';
    case 'rejected':
      return 'Declined';
    case 'fulfilled':
      return disbursement ? 'Payment released' : 'Closed';
    case 'cancelled':
      return 'Cancelled';
    default:
      return status.isEmpty
          ? '—'
          : status[0].toUpperCase() + status.substring(1);
  }
}

String _categoryLabel(String cat) {
  if (cat.toLowerCase() == 'other') return 'Others';
  if (cat.isEmpty) return 'Document';
  return cat
      .split(RegExp(r'[_\s]+'))
      .where((p) => p.isNotEmpty)
      .map((p) => '${p[0].toUpperCase()}${p.substring(1)}')
      .join(' ');
}

class _InboxFilterChips extends StatelessWidget {
  const _InboxFilterChips({
    required this.active,
    required this.past,
    required this.overdue,
    required this.total,
    required this.selected,
    required this.onSelected,
  });

  final int active;
  final int past;
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
          _chip('Active', _InboxFilter.active, active),
          _chip('Overdue', _InboxFilter.overdue, overdue),
          _chip('Past', _InboxFilter.past, past),
          _chip('All', _InboxFilter.all, total),
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
        showCheckmark: false,
        backgroundColor: Colors.transparent,
        selectedColor: SfColors.blue.withValues(alpha: 0.08),
        side: BorderSide(
          color: isSelected
              ? SfColors.blue.withValues(alpha: 0.22)
              : const Color(0xFFDCE3EC),
        ),
        labelStyle: TextStyle(
          fontSize: 13,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
          color: isSelected ? SfColors.blue : SfColors.muted,
        ),
      ),
    );
  }
}

class _RequestStatusBadge extends StatelessWidget {
  const _RequestStatusBadge({required this.request});
  final Map<String, dynamic> request;

  @override
  Widget build(BuildContext context) {
    final status = '${request['status'] ?? ''}';
    final tone = switch (status) {
      'pending' => SfPillTone.warning,
      'rejected' => SfPillTone.danger,
      'fulfilled' => SfPillTone.success,
      'cancelled' => SfPillTone.muted,
      _ => SfPillTone.neutral,
    };
    return SfStatusPill(
      label: _requestStatusLabel(
        status,
        disbursement: _isDisbursement(request),
      ),
      tone: tone,
    );
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
    required this.onDetails,
    this.busy = false,
    this.actionsEnabled = true,
  });

  final Map<String, dynamic> request;
  final bool inbox;
  final String myOfficeCode;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onFulfill;
  final VoidCallback onCancel;
  final VoidCallback onDetails;
  final bool busy;
  final bool actionsEnabled;

  @override
  Widget build(BuildContext context) {
    final status = request['status']?.toString() ?? '';
    final requester = request['requester'] as Map<String, dynamic>? ?? {};
    final handler = request['handler_office'] as Map<String, dynamic>? ?? {};
    final category = request['document_category']?.toString() ?? '';
    final purpose = request['purpose']?.toString().trim() ?? '';
    final code = request['request_code']?.toString() ?? '';
    final fromCode = requester['office_code']?.toString() ?? '—';
    final toCode = handler['office_code']?.toString() ?? '—';
    final requiredBy =
        (request['required_by_display'] ?? request['required_by'])?.toString();
    final isOverdue = request['is_overdue'] == true;
    final title = purpose.isNotEmpty ? purpose : _categoryLabel(category);
    final routeLine = inbox ? 'From $fromCode' : 'To $toCode';
    final canRecordPaymentRelease = _canRecordPaymentRelease(
      role: context.read<AuthProvider>().user!.role,
      officeCode: myOfficeCode,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: busy ? null : onDetails,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Text(
                            code,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: SfColors.muted,
                            ),
                          ),
                          _RequestStatusBadge(request: request),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          height: 1.35,
                          color: SfColors.ink,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$routeLine · ${_categoryLabel(category)}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: SfColors.muted,
                        ),
                      ),
                      if (requiredBy != null && requiredBy.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              isOverdue
                                  ? Icons.warning_amber_rounded
                                  : Icons.event_rounded,
                              size: 16,
                              color: isOverdue ? SfColors.red : SfColors.muted,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                isOverdue
                                    ? 'Overdue — required by $requiredBy'
                                    : 'Required by $requiredBy',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isOverdue
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: isOverdue
                                      ? SfColors.red
                                      : SfColors.muted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (request['related_document_id'] != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Linked: ${request['related_document_id']}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: SfColors.blue,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: SfColors.muted,
                    size: 22,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (inbox && status == 'pending')
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton(
                  onPressed: busy || !actionsEnabled ? null : onReject,
                  child: const Text('Decline'),
                ),
                FilledButton(
                  onPressed: busy || !actionsEnabled ? null : onApprove,
                  child: const Text('Accept request'),
                ),
              ],
            ),
          ),
        if (inbox && status == 'approved')
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: _isDisbursement(request) && !canRecordPaymentRelease
                ? const Text(
                    'Treasury records payment release.',
                    style: TextStyle(color: SfColors.muted, fontSize: 13),
                  )
                : FilledButton(
                    onPressed: busy || !actionsEnabled ? null : onFulfill,
                    child: Text(
                      _isDisbursement(request)
                          ? 'Mark payment released'
                          : 'Close request',
                    ),
                  ),
          ),
        if (!inbox && (status == 'pending' || status == 'approved'))
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 16, 8),
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: busy || !actionsEnabled ? null : onCancel,
                child: const Text('Cancel request'),
              ),
            ),
          ),
      ],
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
  late final AuthProvider _auth;
  late final Object _identity;
  late final SmartflowApi _api;
  late final AppUser _user;
  bool get _current => mounted && _auth.sessionIdentity == _identity;
  String _kind = 'access';
  String _category = 'budget';
  int? _targetOfficeId;
  DateTime? _requiredBy;
  final _purpose = TextEditingController();
  List<Map<String, dynamic>> _offices = [];
  bool _loading = false;
  String? _error;
  bool _officesLoading = true;
  String? _officesError;

  List<MapEntry<String, String>> get _categories {
    return documentRequestCategoriesForOffice(_user.officeCode);
  }

  @override
  void initState() {
    super.initState();
    _auth = context.read<AuthProvider>();
    _identity = _auth.sessionIdentity;
    _api = _auth.api;
    _user = _auth.user!;
    _requiredBy = DateTime.now().add(const Duration(days: 7));
    _loadOffices();
  }

  @override
  void dispose() {
    _purpose.dispose();
    super.dispose();
  }

  Future<void> _loadOffices() async {
    if (!_current) return;
    setState(() {
      _officesLoading = true;
      _officesError = null;
    });
    try {
      final list = await _api.offices();
      if (!mounted || !_current) return;
      final cats = _categories;
      setState(() {
        _offices = list
            .where((office) => office['id'] != _user.officeId)
            .toList();
        _officesLoading = false;
        if (cats.isNotEmpty) _category = cats.first.key;
      });
    } catch (e) {
      if (_current) {
        setState(() {
          _officesError = apiErrorMessage(e);
          _officesLoading = false;
        });
      }
    }
  }

  Future<void> _pickRequiredBy() async {
    final now = DateUtils.dateOnly(DateTime.now());
    final required = _requiredBy ?? now.add(const Duration(days: 7));
    final picked = await showDatePicker(
      context: context,
      initialDate: required.isBefore(now) ? now : required,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 2)),
      helpText: 'Required-by date',
    );
    if (picked != null && _current) {
      setState(() => _requiredBy = picked);
    }
  }

  String? _requiredByPayload() {
    if (_requiredBy == null) return null;
    final d = _requiredBy!;
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _submit() async {
    if (!_current || _auth.loggingOut || _loading) return;
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
    if (_kind == 'access' && _category == 'other' && _targetOfficeId == null) {
      setState(() => _error = 'Choose which office should receive this');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _api.documentRequestCreate(
        requestKind: _kind,
        documentCategory: _kind == 'pull' ? 'general' : _category,
        targetOfficeId: _kind == 'pull' || _category == 'other'
            ? _targetOfficeId
            : null,
        purpose: _purpose.text.trim(),
        requiredBy: _requiredByPayload()!,
      );
      if (mounted && _current) Navigator.pop(context, result);
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
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: SfColors.navy,
              ),
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
              CreationRecoveryPanel(
                kind: 'request',
                onRecovered: (result) => Navigator.pop(context, result),
              ),
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
                        isExpanded: true,
                        key: ValueKey('category-$_category'),
                        initialValue: categories.any((e) => e.key == _category)
                            ? _category
                            : categories.first.key,
                        decoration: const InputDecoration(
                          labelText: 'Document type',
                        ),
                        items: categories
                            .map(
                              (e) => DropdownMenuItem(
                                value: e.key,
                                child: Text(
                                  e.value,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(
                          () => _category = v ?? categories.first.key,
                        ),
                      ),
              if (_kind == 'access' && _category == 'other') ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  isExpanded: true,
                  key: ValueKey('others-office-$_targetOfficeId'),
                  initialValue: _targetOfficeId,
                  decoration: const InputDecoration(
                    labelText: 'Send Others to office',
                  ),
                  items: _offices
                      .where(
                        (o) =>
                            o['id'] !=
                            context.read<AuthProvider>().user!.officeId,
                      )
                      .map((o) {
                        final id = o['id'] as int;
                        return DropdownMenuItem(
                          value: id,
                          child: Text(
                            '${o['name']} (${o['code']})',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      })
                      .toList(),
                  onChanged: (v) => setState(() => _targetOfficeId = v),
                ),
              ],
              if (_kind != 'access')
                DropdownButtonFormField<int>(
                  isExpanded: true,
                  key: ValueKey('target-office-$_targetOfficeId'),
                  initialValue: _targetOfficeId,
                  decoration: const InputDecoration(
                    labelText: 'Send request to office',
                  ),
                  items: _offices.map((o) {
                    final id = o['id'] as int;
                    return DropdownMenuItem(
                      value: id,
                      child: Text(
                        '${o['name']} (${o['code']})',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => _targetOfficeId = v),
                ),
              if (_kind == 'pull') ...[
                const SizedBox(height: 8),
                const Text(
                  'Request a folder from this office without restricting its document type.',
                  style: TextStyle(fontSize: 12, color: SfColors.muted),
                ),
              ],
              if (_kind == 'pull' || _category == 'other') ...[
                if (_officesLoading)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('Loading receiving offices…'),
                  ),
                if (_officesError != null) ...[
                  SfErrorBanner(message: _officesError!),
                  TextButton(
                    onPressed: _loadOffices,
                    child: const Text('Try loading offices again'),
                  ),
                ],
              ],
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
                onPressed:
                    _loading ||
                        ((_kind == 'pull' || _category == 'other') &&
                            (_officesLoading || _officesError != null))
                    ? null
                    : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
