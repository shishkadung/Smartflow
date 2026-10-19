import '../../widgets/home_folder_actions.dart';
import '../../utils/live_refresh.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/api_client.dart';
import '../../utils/alert_actions.dart';
import '../../theme/sf_icons.dart';
import '../../theme/smartflow_theme.dart';
import '../../utils/format_time.dart';
import '../../widgets/sf_help.dart';
import '../../widgets/sf_page.dart';
import '../../widgets/sf_pdf_chrome.dart';
import '../../widgets/sf_widgets.dart';
import '../staff/clerk_widgets.dart';
import '../../utils/api_error.dart';
import 'head_widgets.dart';

class HeadShell extends StatefulWidget {
  const HeadShell({super.key, required this.child});

  final Widget child;

  @override
  State<HeadShell> createState() => _HeadShellState();
}

class _HeadShellState extends State<HeadShell> with LiveRefresh<HeadShell> {
  int _alertCount = 0;
  int _pendingRequests = 0;

  @override
  Future<void> refreshLiveData() => _loadAlertCount();

  @override
  void initState() {
    super.initState();
    _loadAlertCount();
  }

  Future<void> _loadAlertCount() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated || auth.user!.role != 'head') return;
    try {
      final data = await auth.api.alerts(auth.user!.officeId);
      final list = data['alerts'] as List<dynamic>? ?? [];
      final visible = await AlertActionsStore.visibleCount(list);
      if (mounted) refreshAlertBadge(visible);
      if (!mounted) return;
      final pending = await sfPendingRequestCount(context);
      if (mounted) setState(() => _pendingRequests = pending);
    } catch (_) {}
  }

  void refreshAlertBadge(int count) {
    if (mounted) setState(() => _alertCount = count);
  }

  static const _primaryTabs = [
    '/head',
    '/head/queue',
    '/head/scan',
    '/head/alerts',
  ];

  int _indexForPath(String loc) => _primaryTabs.indexWhere((t) => loc == t);

  void _onTab(int i) {
    context.go(_primaryTabs[i]);
    _loadAlertCount();
  }

  @override
  Widget build(BuildContext context) {
    final loc = GoRouterState.of(context).uri.path;
    final index = _indexForPath(loc);
    final profileActive = sfIsOnProfilePage(loc, 'head');

    return SfNavBadgeScope(
      alertCount: _alertCount,
      child: SfAppScaffold(
        currentIndex: index,
        onTab: _onTab,
        onMenu: () =>
            showSfRoleMoreSheet(context, pendingRequests: _pendingRequests),
        onProfile: () => context.go(sfProfileRouteForRole('head')),
        profileActive: profileActive,
        menuActive: index < 0 && !profileActive,
        tabs: [
          const SfNavTab(
            icon: SfIcons.headHome,
            activeIcon: SfIcons.headHomeActive,
            label: 'Home',
          ),
          const SfNavTab(
            icon: SfIcons.headQueue,
            activeIcon: SfIcons.headQueueActive,
            label: 'Queue',
          ),
          const SfNavTab(
            icon: SfIcons.clerkScan,
            activeIcon: SfIcons.clerkScanActive,
            label: 'Scan',
            elevated: true,
          ),
          SfNavTab(
            icon: SfIcons.headAlerts,
            activeIcon: SfIcons.headAlertsActive,
            label: 'Alerts',
            badge: _alertCount > 0 ? _alertCount : null,
          ),
          const SfNavTab(icon: SfIcons.menu, label: 'Menu'),
        ],
        body: widget.child,
      ),
    );
  }
}

// ─── Home ───────────────────────────────────────────────────────────────────

class HeadDashboardScreen extends StatefulWidget {
  const HeadDashboardScreen({super.key});

  @override
  State<HeadDashboardScreen> createState() => _HeadDashboardScreenState();
}

class _HeadDashboardScreenState extends State<HeadDashboardScreen>
    with LiveRefresh<HeadDashboardScreen> {
  @override
  Future<void> refreshLiveData() => _load(silent: true);

  Map<String, dynamic>? _stats;
  List<Map<String, dynamic>> _queue = [];
  List<Map<String, dynamic>> _recentScans = [];
  String? _error;
  bool _loading = true;
  bool _loadInFlight = false;
  DateTime? _lastLoaded;

  List<Map<String, dynamic>> get _overdueItems => _queue
      .where((q) => q['status_label'] == 'overdue')
      .toList(growable: false);

  List<Map<String, dynamic>> get _forwardedItems =>
      _queue.where(headQueueAwaitingReceive).toList(growable: false);

  @override
  void initState() {
    super.initState();
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) maybeShowSfRoleTip(context);
    });
  }

  Future<void> _load({bool silent = false}) async {
    if (!mounted ||
        !context.read<AuthProvider>().isAuthenticated ||
        _loadInFlight) {
      return;
    }
    _loadInFlight = true;
    final oid = context.read<AuthProvider>().user!.officeId;
    setState(() {
      if (!silent) {
        _loading = true;
      }
    });
    try {
      final api = context.read<AuthProvider>().api;
      final dash = await api.headDashboard(oid);
      if (!mounted) return;
      setState(() {
        _stats = dash['stats'] as Map<String, dynamic>?;
        _queue = (dash['queue'] as List<dynamic>? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _recentScans = (dash['recent_movements'] as List<dynamic>? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _loading = false;
        _error = null;
        _lastLoaded = DateTime.now();
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
    } finally {
      _loadInFlight = false;
    }
  }

  void _openHistory(String docId) {
    context.push('/head/documents?id=${Uri.encodeQueryComponent(docId)}');
  }

  void _goQueue({String? filter}) {
    context.go('/head/queue', extra: {'filter': ?filter});
  }

  @override
  Widget build(BuildContext context) {
    final s = _stats;

    return RefreshIndicator(
      onRefresh: _load,
      color: SfColors.blue,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          const SfAuthenticatedPageHeader(),
          const SizedBox(height: 12),
          const SfHeadPageOverviewCard(screen: SfHeadScreen.home),
          const SizedBox(height: 16),
          if (_error != null) ...[
            SfErrorBanner(
              message: s == null
                  ? 'Dashboard unavailable. $_error'
                  : 'Refresh failed. Showing previously loaded data; counts may be out of date.\n$_error',
            ),
            const SizedBox(height: 8),
            SfSecondaryOutlineButton(
              label: _loading ? 'Retrying…' : 'Try again',
              onPressed: _loading ? null : _load,
            ),
            const SizedBox(height: 12),
          ],
          HomeFolderActions(
            overview: _loading
                ? const SfLoadingCard()
                : s == null
                ? null
                : SfHeadStatRow(
                    inOffice: s['in_office'] as int? ?? 0,
                    overdue: s['overdue'] as int? ?? 0,
                    avgHours: (s['avg_hours'] as num?)?.toDouble() ?? 0,
                    onInOfficeTap: () => _goQueue(filter: 'in_office'),
                    onOverdueTap: () => _goQueue(filter: 'overdue'),
                  ),
          ),
          SfSecondaryOutlineButton(
            label: 'Open office queue',
            onPressed: () => context.go('/head/queue'),
          ),
          if (!_loading && s != null) ...[
            if (_error == null &&
                _overdueItems.isEmpty &&
                _forwardedItems.isEmpty &&
                (s['in_office'] as int? ?? 0) > 0) ...[
              const SizedBox(height: 14),
              SfFormCard(
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline_rounded,
                      color: SfColors.green.withValues(alpha: 0.9),
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Office on track — no overdue or unconfirmed forwards right now.',
                        style: TextStyle(
                          fontSize: 12,
                          color: SfColors.muted,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (_forwardedItems.isNotEmpty) ...[
              const SizedBox(height: 20),
              SfHeadForwardedPreview(
                items: _forwardedItems,
                onTapItem: _openHistory,
                onViewAll: () => _goQueue(filter: 'forwarded'),
              ),
            ],
            if (_overdueItems.isNotEmpty) ...[
              const SizedBox(height: 20),
              SfHeadOverduePreview(
                items: _overdueItems,
                onTapItem: _openHistory,
                onViewAll: () => _goQueue(filter: 'overdue'),
              ),
            ],
            if (_recentScans.isNotEmpty) ...[
              const SizedBox(height: 20),
              SfHeadStaffActivityList(
                scans: _recentScans,
                onTapDoc: _openHistory,
              ),
            ],
            if (_lastLoaded != null) ...[
              const SizedBox(height: 16),
              Text(
                '${_error == null ? 'Updated' : 'Last successful update'} ${formatSmartflowTime(_lastLoaded!.toIso8601String())} · pull to refresh',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: SfColors.muted),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

// ─── Queue ──────────────────────────────────────────────────────────────────

enum _HeadQueueSort { hoursDesc, hoursAsc, idAsc }

class HeadQueueScreen extends StatefulWidget {
  const HeadQueueScreen({super.key, this.initialFilter});

  final SfHeadQueueFilter? initialFilter;

  static SfHeadQueueFilter? parseFilter(String? name) {
    switch (name) {
      case 'in_office':
        return SfHeadQueueFilter.inOffice;
      case 'overdue':
        return SfHeadQueueFilter.overdue;
      case 'forwarded':
        return SfHeadQueueFilter.forwarded;
      default:
        return null;
    }
  }

  @override
  State<HeadQueueScreen> createState() => _HeadQueueScreenState();
}

class _HeadQueueScreenState extends State<HeadQueueScreen>
    with LiveRefresh<HeadQueueScreen> {
  @override
  Future<void> refreshLiveData() => _load(silent: true);

  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _queue = [];
  String? _error;
  bool _loading = true;
  bool _reading = false;
  DateTime? _lastLoaded;
  int _request = 0;
  late final AuthProvider _auth;
  late final Object _identity;
  late SfHeadQueueFilter _filter;
  _HeadQueueSort _sort = _HeadQueueSort.hoursDesc;

  bool get _current => mounted && _auth.sessionIdentity == _identity;

  String _normalizedStatus(Map<String, dynamic> item) =>
      item['status_label']?.toString().trim().toLowerCase() ?? '';

  String _compactText(dynamic value) =>
      value?.toString().replaceAll(RegExp(r'\s+'), ' ').trim() ?? '';

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  Widget _buildQueueRow(Map<String, dynamic> m) {
    final id = _compactText(m['document_id']);
    final title = _compactText(m['title']);
    final type = _compactText(m['type']);
    final meta = _compactText(m['meta']);
    final statusLabel = _compactText(m['status_label']);
    final statusPill = _compactText(m['status_pill']);

    return SfHeadQueueRow(
      documentId: id,
      title: title,
      type: type,
      meta: meta,
      statusLabel: statusLabel,
      statusPill: statusPill,
      hoursPending: _asInt(m['hours_pending']),
      onTap: () => _openHistory(id),
    );
  }

  Widget _buildQueueRowSafe(Map<String, dynamic> m) {
    try {
      return _buildQueueRow(m);
    } catch (_) {
      return const SfFormCard(
        child: Text(
          'Unable to render one queue item. Pull to refresh.',
          style: TextStyle(fontSize: 12, color: SfColors.muted),
        ),
      );
    }
  }

  /// Queue rows as direct [ListView] children (avoids nested scroll + flex issues).
  List<Widget> _activeDocumentListChildren(List<Map<String, dynamic>> visible) {
    if (_loading) return [const SfLoadingCard()];
    if (_lastLoaded == null) return [];
    if (_queue.isEmpty) {
      if (_error != null) {
        return [
          const SfInfoBanner(
            text:
                'The last successful read found no documents. Retry to verify the current queue.',
          ),
        ];
      }
      return [
        SfEmptyState(
          icon: Icons.inbox_outlined,
          title: 'No documents in the office queue',
          subtitle: 'Folders appear when clerks scan them IN or OUT.',
        ),
      ];
    }
    if (visible.isEmpty) {
      if (_searchCtrl.text.trim().isNotEmpty) {
        return [
          SfEmptyState(
            icon: Icons.search_off_rounded,
            title: 'No matching documents',
            subtitle: 'Clear the search to show folders in this view.',
            actionLabel: 'Clear search',
            onAction: _searchCtrl.clear,
          ),
        ];
      }
      return [
        SfEmptyState(
          icon: Icons.filter_list_off_outlined,
          title: 'No documents in this filter',
          subtitle: 'Try All to see every folder at your office.',
          actionLabel: 'Show all',
          onAction: () => setState(() => _filter = SfHeadQueueFilter.all),
        ),
      ];
    }
    return visible.map(_buildQueueRowSafe).toList();
  }

  @override
  void initState() {
    super.initState();
    _auth = context.read<AuthProvider>();
    _identity = _auth.sessionIdentity;
    _filter = widget.initialFilter ?? SfHeadQueueFilter.all;
    _searchCtrl.addListener(() {
      if (mounted) setState(() {});
    });
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  int get _countInOffice =>
      _queue.where((q) => _normalizedStatus(q) == 'in_office').length;

  int get _countOverdue =>
      _queue.where((q) => _normalizedStatus(q) == 'overdue').length;

  int get _countForwarded => _queue.where(headQueueAwaitingReceive).length;

  List<Map<String, dynamic>> get _visible {
    final q = _searchCtrl.text.trim().toUpperCase();
    var list = _queue.where((item) {
      switch (_filter) {
        case SfHeadQueueFilter.all:
          break;
        case SfHeadQueueFilter.inOffice:
          if (_normalizedStatus(item) != 'in_office') return false;
          break;
        case SfHeadQueueFilter.overdue:
          if (_normalizedStatus(item) != 'overdue') return false;
          break;
        case SfHeadQueueFilter.forwarded:
          if (!headQueueAwaitingReceive(item)) return false;
          break;
      }
      if (q.isNotEmpty) {
        final id = item['document_id']?.toString().toUpperCase() ?? '';
        final title = item['title']?.toString().toUpperCase() ?? '';
        if (!id.contains(q) && !title.contains(q)) return false;
      }
      return true;
    }).toList();

    list.sort((a, b) {
      switch (_sort) {
        case _HeadQueueSort.hoursDesc:
          final ha = _asInt(a['hours_pending']);
          final hb = _asInt(b['hours_pending']);
          return hb.compareTo(ha);
        case _HeadQueueSort.hoursAsc:
          final ha = _asInt(a['hours_pending']);
          final hb = _asInt(b['hours_pending']);
          return ha.compareTo(hb);
        case _HeadQueueSort.idAsc:
          return (a['document_id']?.toString() ?? '').compareTo(
            b['document_id']?.toString() ?? '',
          );
      }
    });
    return list;
  }

  Future<void> _load({bool silent = false}) async {
    if (!_current || !_auth.isAuthenticated || (silent && _loading)) {
      return;
    }
    final request = ++_request;
    final oid = _auth.user!.officeId;
    setState(() {
      _reading = true;
      if (!silent) {
        _loading = true;
      }
    });
    try {
      final data = await _auth.api.headDashboard(oid);
      if (!_current || request != _request) return;
      setState(() {
        _queue = (data['queue'] as List<dynamic>? ?? []).map((e) {
          final item = Map<String, dynamic>.from(e as Map);
          item['status_label'] = item['status_label']
              ?.toString()
              .trim()
              .toLowerCase();
          return item;
        }).toList();
        _loading = false;
        _reading = false;
        _error = null;
        _lastLoaded = DateTime.now();
      });
    } on ApiException catch (e) {
      if (_current && request == _request) {
        setState(() {
          _error = e.message;
          _loading = false;
          _reading = false;
        });
      }
    } catch (e) {
      if (_current && request == _request) {
        setState(() {
          _error = apiErrorMessage(e);
          _loading = false;
          _reading = false;
        });
      }
    }
  }

  void _openHistory(String docId) {
    context.push('/head/documents?id=${Uri.encodeQueryComponent(docId)}');
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;

    return RefreshIndicator(
      onRefresh: _load,
      color: SfColors.blue,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          const SfAuthenticatedPageHeader(),
          const SizedBox(height: 12),
          const SfHeadPageOverviewCard(screen: SfHeadScreen.queue),
          if (_error != null) ...[
            const SizedBox(height: 12),
            SfErrorBanner(
              message: _lastLoaded == null
                  ? 'Queue unavailable. $_error'
                  : 'Refresh failed. Previously loaded queue and counts may be stale. $_error',
            ),
            TextButton(
              onPressed: _reading ? null : _load,
              child: const Text('Retry queue'),
            ),
          ],
          if (_lastLoaded != null) ...[
            const SizedBox(height: 8),
            Text(
              '${_error == null ? 'Updated' : 'Last successful update'} ${formatSmartflowTime(_lastLoaded!.toIso8601String())} · pull to refresh',
              style: const TextStyle(fontSize: 12, color: SfColors.muted),
            ),
          ],
          if (_reading && !_loading) ...[
            const SizedBox(height: 8),
            const LinearProgressIndicator(),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _searchCtrl,
            textCapitalization: TextCapitalization.characters,
            autocorrect: false,
            decoration: InputDecoration(
              hintText: 'Search ID or title…',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () => _searchCtrl.clear(),
                    )
                  : null,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _sortChip('Longest wait', _HeadQueueSort.hoursDesc),
                const SizedBox(width: 8),
                _sortChip('Shortest wait', _HeadQueueSort.hoursAsc),
                const SizedBox(width: 8),
                _sortChip('ID A–Z', _HeadQueueSort.idAsc),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Expanded(
                flex: 3,
                child: Text(
                  'Active documents',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
              ),
              const SizedBox(width: 12),
              // A tight flex child so the count sits at the right edge instead of the middle of the row.
              if (!_loading && _lastLoaded != null)
                Expanded(
                  flex: 2,
                  child: Text(
                    '${visible.length} of ${_queue.length}${_error == null ? '' : ' · stale'}',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: SfColors.muted,
                    ),
                  ),
                ),
            ],
          ),
          if (_queue.isNotEmpty) ...[
            const SizedBox(height: 10),
            SfHeadQueueFilterChips(
              total: _queue.length,
              inOffice: _countInOffice,
              overdue: _countOverdue,
              forwarded: _countForwarded,
              selected: _filter,
              onSelected: (f) => setState(() => _filter = f),
            ),
          ],
          const SizedBox(height: 12),
          ..._activeDocumentListChildren(visible),
        ],
      ),
    );
  }

  Widget _sortChip(String label, _HeadQueueSort value) {
    final selected = _sort == value;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _sort = value),
      selectedColor: SfColors.navy.withValues(alpha: 0.1),
      checkmarkColor: SfColors.navy,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
      ),
    );
  }
}

// ─── Alerts ─────────────────────────────────────────────────────────────────

class HeadAlertsScreen extends StatefulWidget {
  const HeadAlertsScreen({super.key});

  @override
  State<HeadAlertsScreen> createState() => _HeadAlertsScreenState();
}

class _HeadAlertsScreenState extends State<HeadAlertsScreen>
    with LiveRefresh<HeadAlertsScreen> {
  @override
  Future<void> refreshLiveData() => _load(silent: true);

  List<dynamic> _alerts = [];
  Map<String, AlertActionState> _actions = const {};
  String? _error;
  bool _loading = true;
  SfAlertFilter _filter = SfAlertFilter.all;
  DateTime? _lastLoaded;

  String _actionKey(Map a) => '${a['document_id']}::${a['kind']}';

  AlertActionState _stateFor(Map a) =>
      _actions[_actionKey(a)] ?? const AlertActionState();

  List<Map<String, dynamic>> get _visibleAlerts => _alerts
      .map((a) => Map<String, dynamic>.from(a as Map))
      .where((m) => !_stateFor(m).isHidden)
      .toList();

  int get _hiddenCount => _alerts
      .map((a) => Map<String, dynamic>.from(a as Map))
      .where((m) => _stateFor(m).isHidden)
      .length;

  int get _countDelayed =>
      _visibleAlerts.where((a) => a['kind'] == 'delayed').length;

  int get _countDueSoon =>
      _visibleAlerts.where((a) => a['kind'] == 'due_soon').length;

  int get _countUnconfirmed =>
      _visibleAlerts.where((a) => a['kind'] == 'unconfirmed').length;

  List<Map<String, dynamic>> get _sortedAlerts {
    int rank(String kind) {
      switch (kind) {
        case 'delayed':
          return 0;
        case 'due_soon':
          return 1;
        case 'unconfirmed':
          return 2;
        default:
          return 3;
      }
    }

    final list = _visibleAlerts.where((m) {
      final kind = m['kind']?.toString() ?? '';
      switch (_filter) {
        case SfAlertFilter.all:
          return true;
        case SfAlertFilter.delayed:
          return kind == 'delayed';
        case SfAlertFilter.dueSoon:
          return kind == 'due_soon';
        case SfAlertFilter.unconfirmed:
          return kind == 'unconfirmed';
      }
    }).toList();
    list.sort((a, b) {
      final ra = rank(a['kind']?.toString() ?? '');
      final rb = rank(b['kind']?.toString() ?? '');
      if (ra != rb) return ra.compareTo(rb);
      final ha = a['hours_pending'] as int? ?? 0;
      final hb = b['hours_pending'] as int? ?? 0;
      return hb.compareTo(ha);
    });
    return list;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _refreshActions(List<dynamic> source) async {
    final keys = source
        .map((a) => Map<String, dynamic>.from(a as Map))
        .map(
          (m) => (
            documentId: m['document_id']?.toString() ?? '',
            kind: m['kind']?.toString() ?? '',
          ),
        )
        .toList();
    final actions = await AlertActionsStore.stateForMany(keys);
    if (mounted) setState(() => _actions = actions);
  }

  Future<void> _load({bool silent = false}) async {
    if (!mounted ||
        !context.read<AuthProvider>().isAuthenticated ||
        (silent && _loading)) {
      return;
    }
    final oid = context.read<AuthProvider>().user!.officeId;
    setState(() {
      if (!silent) {
        _loading = true;
      }
      _error = null;
    });
    try {
      final data = await context.read<AuthProvider>().api.alerts(oid);
      final list = data['alerts'] as List<dynamic>? ?? [];
      if (!mounted) return;
      await _refreshActions(list);
      if (!mounted) return;
      final visible = list.where((a) {
        final m = a as Map;
        return !_stateFor(m).isHidden;
      }).length;
      context.findAncestorStateOfType<_HeadShellState>()?.refreshAlertBadge(
        visible,
      );
      setState(() {
        _alerts = list;
        _loading = false;
        _lastLoaded = DateTime.now();
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

  Future<void> _remindLater(Map<String, dynamic> a) async {
    final id = a['document_id']?.toString() ?? '';
    final kind = a['kind']?.toString() ?? '';
    if (id.isEmpty || kind.isEmpty) return;
    await AlertActionsStore.snooze(id, kind, const Duration(hours: 24));
    await _refreshActions(_alerts);
    if (!mounted) return;
    final visible = _alerts.where((x) {
      final m = x as Map;
      return !_stateFor(m).isHidden;
    }).length;
    context.findAncestorStateOfType<_HeadShellState>()?.refreshAlertBadge(
      visible,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Hidden until tomorrow. Undo if you still need it.',
        ),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            await AlertActionsStore.unsnooze(id, kind);
            await _refreshActions(_alerts);
          },
        ),
      ),
    );
  }

  void _openHistory(String docId) {
    context.push('/head/documents?id=${Uri.encodeQueryComponent(docId)}');
  }

  String _compactText(dynamic value) =>
      value?.toString().replaceAll(RegExp(r'\s+'), ' ').trim() ?? '';

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  Widget _buildAlertCard(Map<String, dynamic> m) {
    final kind = m['kind']?.toString() ?? 'delayed';
    final delayed = kind == 'delayed';
    final dueSoon = kind == 'due_soon';
    final isOut =
        m['last_status']?.toString().toUpperCase() == 'OUT' ||
        kind == 'unconfirmed';
    final docId = _compactText(m['document_id']);
    final docTitle = _compactText(m['document_title']) != ''
        ? _compactText(m['document_title'])
        : _compactText(m['title']);
    final hours = _asInt(m['hours_pending']);
    final days = hours ~/ 24;
    final pendingLabel = days > 0
        ? '$days day${days == 1 ? '' : 's'}'
        : '${hours}h';
    final pill1 = delayed
        ? 'Overdue'
        : (dueSoon ? 'Due soon' : 'Receipt not recorded');
    final detail = _compactText(m['detail']);
    final deadline = _compactText(m['due_at_display']).isNotEmpty
        ? _compactText(m['due_at_display'])
        : _compactText(m['due_at']);
    final threshold = _compactText(m['threshold_rule']);
    final rule = [
      if (detail.isNotEmpty) detail,
      if (deadline.isNotEmpty) 'Deadline: $deadline',
      if (threshold.isNotEmpty && threshold != detail) threshold,
    ].join('\n');
    final office = _compactText(m['last_office_name']);
    final title = docTitle.isNotEmpty ? docTitle : 'Document alert';
    final subtitle = [
      if (docId.isNotEmpty) docId,
      if (office.isNotEmpty) isOut ? 'Sent from $office' : 'At $office',
      '$pendingLabel since ${isOut ? 'sending' : 'receipt'}',
    ].join(' · ');

    return SfAlertCardWithActions(
      title: title,
      subtitle: subtitle,
      pill1: pill1,
      pill2: isOut && (delayed || dueSoon)
          ? 'Receipt not recorded'
          : pendingLabel,
      primaryTone: delayed
          ? SfPillTone.danger
          : dueSoon
          ? SfPillTone.warning
          : SfPillTone.neutral,
      secondaryTone: isOut ? SfPillTone.neutral : SfPillTone.muted,
      rule: rule,
      onOpen: docId.isNotEmpty ? () => _openHistory(docId) : null,
      onRemindLater: () => _remindLater(m),
      openLabel: 'Open',
    );
  }

  Widget _buildAlertCardSafe(Map<String, dynamic> m) {
    try {
      return _buildAlertCard(m);
    } catch (_) {
      return const SfFormCard(
        child: Text(
          'Unable to render one alert item. Pull to refresh.',
          style: TextStyle(fontSize: 12, color: SfColors.muted),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = _sortedAlerts;
    final hasAlerts = _alerts.isNotEmpty;
    final hasVisibleAlerts = _visibleAlerts.isNotEmpty;
    final hidden = _hiddenCount;
    final filterLabel = switch (_filter) {
      SfAlertFilter.all => 'All',
      SfAlertFilter.delayed => 'Overdue',
      SfAlertFilter.dueSoon => 'Due soon',
      SfAlertFilter.unconfirmed => 'Receipt not recorded',
    };

    return RefreshIndicator(
      onRefresh: _load,
      color: SfColors.blue,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          const SfAuthenticatedPageHeader(),
          const SizedBox(height: 12),
          const SfHeadPageOverviewCard(screen: SfHeadScreen.alerts),
          const SizedBox(height: 16),
          if (_error != null) ...[
            const SizedBox(height: 12),
            SfErrorBanner(
              message: _lastLoaded == null
                  ? 'Alerts unavailable. $_error'
                  : 'Refresh failed. Previously loaded alerts may be stale. $_error',
            ),
            TextButton(onPressed: _load, child: const Text('Retry')),
          ],
          if (_loading)
            const SfLoadingCard()
          else ...[
            if (hasVisibleAlerts) ...[
              SfAlertsSummaryRow(
                delayed: _countDelayed,
                dueSoon: _countDueSoon,
                unconfirmed: _countUnconfirmed,
              ),
              const SizedBox(height: 12),
              SfAlertFilterChips(
                delayed: _countDelayed,
                dueSoon: _countDueSoon,
                unconfirmed: _countUnconfirmed,
                selected: _filter,
                onSelected: (f) => setState(() => _filter = f),
              ),
              const SizedBox(height: 12),
              if (_lastLoaded != null)
                Text(
                  '${_error == null ? 'Updated' : 'Last successful update'} ${formatSmartflowTime(_lastLoaded!.toIso8601String())} · pull to refresh',
                  style: const TextStyle(
                    fontSize: 12,
                    color: SfColors.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              const SizedBox(height: 10),
              SfFormCard(
                child: Row(
                  children: [
                    const Icon(
                      Icons.notifications_active_rounded,
                      size: 18,
                      color: SfColors.blue,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _filter == SfAlertFilter.all
                            ? 'Active alerts (${visible.length})'
                            : '$filterLabel alerts (${visible.length})',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (_filter != SfAlertFilter.all)
                      TextButton(
                        onPressed: () =>
                            setState(() => _filter = SfAlertFilter.all),
                        child: const Text('Show all'),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              if (visible.isEmpty)
                SfEmptyState(
                  icon: _filter == SfAlertFilter.all
                      ? SfIcons.clerkAlerts
                      : Icons.filter_list_off_outlined,
                  title: _filter == SfAlertFilter.all
                      ? 'No alerts right now'
                      : 'No alerts in this filter',
                  actionLabel: _filter == SfAlertFilter.all ? null : 'Show all',
                  onAction: _filter == SfAlertFilter.all
                      ? null
                      : () => setState(() => _filter = SfAlertFilter.all),
                )
              else
                ...visible.map(_buildAlertCardSafe),
            ] else if (hasAlerts && hidden > 0) ...[
              if (_error == null)
                const SfAlertsHealthyEmptyPanel()
              else
                const Text(
                  'Previously loaded reminders are hidden. Retry to verify current alerts.',
                  style: TextStyle(color: SfColors.muted),
                ),
              const SizedBox(height: 8),
              Text(
                '$hidden reminder${hidden == 1 ? '' : 's'} hidden until tomorrow.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: SfColors.muted),
              ),
            ] else if (_error == null)
              const SfAlertsHealthyEmptyPanel(),
          ],
        ],
      ),
    );
  }
}

// ─── Analytics ──────────────────────────────────────────────────────────────

class HeadAnalyticsScreen extends StatefulWidget {
  const HeadAnalyticsScreen({super.key});

  @override
  State<HeadAnalyticsScreen> createState() => _HeadAnalyticsScreenState();
}

class _HeadAnalyticsScreenState extends State<HeadAnalyticsScreen>
    with LiveRefresh<HeadAnalyticsScreen> {
  @override
  Future<void> refreshLiveData() => _load(silent: true);

  Map<String, dynamic>? _data;
  String? _error;
  bool _loading = true;
  DateTime? _lastLoaded;
  int _request = 0;
  late String _month;

  @override
  void initState() {
    super.initState();
    _month = DateFormat('yyyy-MM').format(DateTime.now());
    _load();
  }

  Future<void> _load({bool silent = false}) async {
    if (!mounted ||
        !context.read<AuthProvider>().isAuthenticated ||
        (silent && _loading)) {
      return;
    }
    final request = ++_request;
    final oid = context.read<AuthProvider>().user!.officeId;
    setState(() {
      if (!silent) {
        _loading = true;
      }
      _error = null;
    });
    try {
      final data = await context.read<AuthProvider>().api.headAnalytics(
        oid,
        _month,
      );
      if (!mounted || request != _request) return;
      setState(() {
        _data = data;
        _loading = false;
        _lastLoaded = DateTime.now();
      });
    } on ApiException catch (e) {
      if (mounted && request == _request) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted && request == _request) {
        setState(() {
          _error = apiErrorMessage(e);
          _loading = false;
        });
      }
    }
  }

  Future<void> _pickMonth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.parse('$_month-01'),
      firstDate: DateTime(now.year - 1),
      lastDate: now,
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked == null || !mounted) return;
    setState(() => _month = DateFormat('yyyy-MM').format(picked));
    await _load();
  }

  void _openHistory(String docId) {
    context.push('/head/documents?id=${Uri.encodeQueryComponent(docId)}');
  }

  @override
  Widget build(BuildContext context) {
    final stats = _data?['stats'] as Map<String, dynamic>?;
    final slow = _data?['slow_documents'] as List<dynamic>? ?? [];
    // Keep rebuilding when the signed-in user changes, even though the summary no longer prints the office.
    context.watch<AuthProvider>();
    final monthLabel =
        _data?['month']?.toString() ??
        DateFormat('MMMM yyyy').format(DateTime.parse('$_month-01'));
    final processed = (stats?['processed'] as int?) ?? 0;
    final late = (stats?['late_count'] as int?) ?? 0;
    final onTime = (stats?['on_time_percent'] as int?) ?? 0;
    final onTimeCount = (stats?['on_time_count'] as int?) ?? 0;
    final unforwardedCount = (stats?['unforwarded_count'] as int?) ?? 0;
    final delayedCount = (stats?['delayed_count'] as int?) ?? late;
    // Prefer backend-provided breakdown; fallback to legacy residual math.
    final delayed =
        (stats?['delayed_percent'] as int?) ??
        (processed > 0 ? ((late / processed) * 100).round() : 0);
    final unforwarded =
        (stats?['unforwarded_percent'] as int?) ??
        (100 - onTime - delayed).clamp(0, 100);

    return RefreshIndicator(
      onRefresh: _load,
      color: SfColors.blue,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          const SfAuthenticatedPageHeader(),
          const SizedBox(height: 12),
          const SfHeadPageOverviewCard(
            screen: SfHeadScreen.analytics,
            compact: true,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            SfErrorBanner(
              message: _data == null
                  ? 'Analytics unavailable. $_error'
                  : 'Refresh failed. Previously loaded analytics may be stale. $_error',
            ),
            TextButton(onPressed: _load, child: const Text('Retry analytics')),
          ],
          const SizedBox(height: 12),
          SfNavigationRow(
            icon: Icons.calendar_month_outlined,
            title: monthLabel,
            subtitle: 'Change month',
            onTap: _pickMonth,
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: SfLoadingCard(),
            )
          else if (stats == null && _error == null) ...[
            const SizedBox(height: 14),
            const SfEmptyState(
              icon: Icons.analytics_outlined,
              title: 'No analytics for this month',
              subtitle: 'Try another month or pull to refresh.',
            ),
          ] else if (stats != null) ...[
            const SizedBox(height: 14),
            SfComplianceRates(
              onTime: onTime,
              unforwarded: unforwarded,
              delayed: delayed,
              monthLabel: 'Monthly',
              onTimeFolders: onTimeCount,
              unforwardedFolders: unforwardedCount,
              delayedFolders: delayedCount,
            ),
            const SizedBox(height: 12),
            // The rates and their folder counts are in the tiles above; the summary keeps only what they do not show.
            SfSummaryCard(
              title: 'Office summary',
              rows: [
                MapEntry('Month', monthLabel),
                MapEntry('Documents touched', '$processed'),
                MapEntry('Exceeded threshold', '$late'),
              ],
            ),
            const SizedBox(height: 12),
            SfSecondaryOutlineButton(
              label: 'Open overdue in queue',
              icon: SfIcons.headQueueActive,
              onPressed: () =>
                  context.go('/head/queue', extra: {'filter': 'overdue'}),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Slow documents',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
              ),
              const SizedBox(width: 12),
              if (slow.isNotEmpty)
                Text(
                  'Top ${slow.length.clamp(0, 5)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: SfColors.muted,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (!_loading && _error == null && stats != null && slow.isEmpty)
            const SfEmptyState(
              icon: Icons.speed_rounded,
              title: 'No slow documents',
              subtitle: 'All processed items met the threshold this month.',
            )
          else if (!_loading && _error != null && slow.isEmpty)
            const SfInfoBanner(
              text:
                  'Slow-document results are unavailable. Retry to verify this month’s activity.',
            )
          else
            ...slow.map((d) {
              final m = d as Map<String, dynamic>;
              final id = m['document_id']?.toString() ?? '';
              final hours = m['hours'] as int? ?? 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SfFormCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: InkWell(
                    onTap: id.isNotEmpty ? () => _openHistory(id) : null,
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: SfColors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.schedule_rounded,
                            size: 18,
                            color: SfColors.red,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                id,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                '${hours}h at office · tap for history',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: SfColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (id.isNotEmpty)
                          const Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: SfColors.muted,
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          if (_lastLoaded != null && !_loading) ...[
            const SizedBox(height: 16),
            Text(
              '${_error == null ? 'Updated' : 'Last successful update'} ${formatSmartflowTime(_lastLoaded!.toIso8601String())} · pull to refresh',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: SfColors.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
