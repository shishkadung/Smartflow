import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class _HeadShellState extends State<HeadShell> {
  int _alertCount = 0;

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
    } catch (_) {}
  }

  void refreshAlertBadge(int count) {
    if (mounted) setState(() => _alertCount = count);
  }

  static const _primaryTabs = [
    '/head',
    '/head/queue',
    '/head/alerts',
  ];

  static const _menuRoutes = [
    '/head/scan',
    '/head/register',
    '/head/analytics',
    '/head/history',
  ];

  int _indexForPath(String loc) {
    final primary = _primaryTabs.indexWhere((t) => loc == t);
    if (primary >= 0) return primary;
    if (_menuRoutes.contains(loc)) return 3;
    return -1;
  }

  void _onTab(int i) {
    if (i == 3) {
      showSfRoleMoreSheet(context);
      return;
    }
    context.go(_primaryTabs[i]);
    _loadAlertCount();
  }

  @override
  Widget build(BuildContext context) {
    final loc = GoRouterState.of(context).uri.path;
    final index = _indexForPath(loc);

    return SfNavBadgeScope(
      alertCount: _alertCount,
      child: SfAppScaffold(
        currentIndex: index,
        onTab: _onTab,
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
            elevated: true,
          ),
          SfNavTab(
            icon: SfIcons.headAlerts,
            activeIcon: SfIcons.headAlertsActive,
            label: 'Alerts',
            badge: _alertCount > 0 ? _alertCount : null,
          ),
          const SfNavTab(
            icon: SfIcons.more,
            activeIcon: SfIcons.moreActive,
            label: 'Menu',
          ),
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

class _HeadDashboardScreenState extends State<HeadDashboardScreen> {
  Map<String, dynamic>? _stats;
  List<Map<String, dynamic>> _queue = [];
  List<Map<String, dynamic>> _recentScans = [];
  String? _error;
  bool _loading = true;
  DateTime? _lastLoaded;

  List<Map<String, dynamic>> get _overdueItems => _queue
      .where((q) => q['status_label'] == 'overdue')
      .toList(growable: false);

  List<Map<String, dynamic>> get _forwardedItems => _queue
      .where(headQueueAwaitingReceive)
      .toList(growable: false);

  @override
  void initState() {
    super.initState();
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) maybeShowSfRoleTip(context);
    });
  }

  Future<void> _load() async {
    final oid = context.read<AuthProvider>().user!.officeId;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<AuthProvider>().api;
      final dash = await api.headDashboard(oid);
      final alertData = await api.alerts(oid);
      if (!mounted) return;
      context.findAncestorStateOfType<_HeadShellState>()?.refreshAlertBadge(
            (alertData['alerts'] as List<dynamic>? ?? []).length,
          );
      final list = alertData['alerts'] as List<dynamic>? ?? [];
      final keys = list
          .map((a) => Map<String, dynamic>.from(a as Map))
          .map((m) => (
                documentId: m['document_id']?.toString() ?? '',
                kind: m['kind']?.toString() ?? '',
              ))
          .toList();
      final actions = await AlertActionsStore.stateForMany(keys);
      var visibleAlerts = 0;
      for (final a in list) {
        final m = a as Map;
        final k = '${m['document_id']}::${m['kind']}';
        if (!(actions[k]?.isHidden ?? false)) visibleAlerts++;
      }
      if (!mounted) return;
      context.findAncestorStateOfType<_HeadShellState>()?.refreshAlertBadge(
            visibleAlerts,
          );
      setState(() {
        _stats = dash['stats'] as Map<String, dynamic>?;
        _queue = (dash['queue'] as List<dynamic>? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _recentScans = (dash['recent_movements'] as List<dynamic>? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
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

  void _openHistory(String docId) {
    context.push('/head/history', extra: {'documentId': docId});
  }

  void _goQueue({String? filter}) {
    context.go('/head/queue', extra: {if (filter != null) 'filter': filter});
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
          const SizedBox(height: 12),
          SfPrimaryButton(
            label: 'Open office queue',
            onPressed: () => context.go('/head/queue'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            SfErrorBanner(message: _error!),
          ],
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: SfLoadingCard(),
            )
          else if (s != null) ...[
            if (_lastLoaded != null) ...[
              const SizedBox(height: 10),
              Text(
                'Updated ${formatSmartflowTime(_lastLoaded!.toIso8601String())} · pull to refresh',
                style: const TextStyle(
                  fontSize: 10,
                  color: SfColors.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 12),
            SfHeadStatRow(
              inOffice: s['in_office'] as int? ?? 0,
              overdue: s['overdue'] as int? ?? 0,
              avgHours: (s['avg_hours'] as num?)?.toDouble() ?? 0,
              onInOfficeTap: () => _goQueue(filter: 'in_office'),
              onOverdueTap: () => _goQueue(filter: 'overdue'),
            ),
            if (_overdueItems.isEmpty &&
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

class _HeadQueueScreenState extends State<HeadQueueScreen> {
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _queue = [];
  String? _error;
  bool _loading = true;
  late SfHeadQueueFilter _filter;
  _HeadQueueSort _sort = _HeadQueueSort.hoursDesc;

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
      onCopyId: id.isNotEmpty ? () => _copyId(id) : null,
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
    if (_queue.isEmpty) {
      return [
        SfEmptyState(
          icon: Icons.inbox_outlined,
          title: 'No documents in the office queue',
          subtitle: 'Folders appear when clerks scan them IN or OUT.',
        ),
      ];
    }
    if (visible.isEmpty) {
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

  int get _countForwarded =>
      _queue.where(headQueueAwaitingReceive).length;

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
          return (a['document_id']?.toString() ?? '')
              .compareTo(b['document_id']?.toString() ?? '');
      }
    });
    return list;
  }

  Future<void> _load() async {
    final oid = context.read<AuthProvider>().user!.officeId;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await context.read<AuthProvider>().api.headDashboard(oid);
      if (!mounted) return;
      setState(() {
        _queue = (data['queue'] as List<dynamic>? ?? [])
            .map((e) {
              final item = Map<String, dynamic>.from(e as Map);
              item['status_label'] =
                  item['status_label']?.toString().trim().toLowerCase();
              return item;
            })
            .toList();
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

  void _openHistory(String docId) {
    context.push('/head/history', extra: {'documentId': docId});
  }

  void _copyId(String id) {
    Clipboard.setData(ClipboardData(text: id));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tracking ID copied')),
    );
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
            SfErrorBanner(message: _error!),
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
              const Text(
                'Active documents',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
              const Spacer(),
              if (!_loading)
                Text(
                  '${visible.length} of ${_queue.length}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: SfColors.muted,
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
      selectedColor: SfColors.blue.withValues(alpha: 0.15),
      checkmarkColor: SfColors.blue,
      labelStyle: TextStyle(
        fontSize: 11,
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

class _HeadAlertsScreenState extends State<HeadAlertsScreen> {
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
        .map((m) => (
              documentId: m['document_id']?.toString() ?? '',
              kind: m['kind']?.toString() ?? '',
            ))
        .toList();
    final actions = await AlertActionsStore.stateForMany(keys);
    if (mounted) setState(() => _actions = actions);
  }

  Future<void> _load() async {
    final oid = context.read<AuthProvider>().user!.officeId;
    setState(() {
      _loading = true;
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
        content: const Text('Hidden until tomorrow. Undo if you still need it.'),
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
    context.push('/head/history', extra: {'documentId': docId});
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
    final unconfirmed = kind == 'unconfirmed';
    final docId = _compactText(m['document_id']);
    final docTitle = _compactText(m['document_title']) != ''
        ? _compactText(m['document_title'])
        : _compactText(m['title']);
    final days = _asInt(m['days_pending']);
    final hours = _asInt(m['hours_pending']);
    final pendingLabel = days > 0
        ? '$days day${days == 1 ? '' : 's'}'
        : '${hours}h';
    final accent = delayed
        ? SfColors.red
        : (dueSoon ? SfColors.gold : SfColors.blue);
    final pill1 = unconfirmed
        ? 'Waiting for other office'
        : (delayed ? 'Still on your desk' : 'Due soon');
    final rule = m['threshold_rule']?.toString();
    final office = _compactText(m['last_office_name']);
    final title = docTitle.isNotEmpty ? docTitle : 'Document alert';
    final subtitle = [
      if (docId.isNotEmpty) docId,
      if (office.isNotEmpty) office,
      pendingLabel == '${hours}h' ? '$hours hours at this desk' : pendingLabel,
    ].join(' · ');

    return SfAlertCardWithActions(
      title: title,
      subtitle: subtitle,
      accent: accent,
      pill1: pill1,
      pill2: pendingLabel,
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
      SfAlertFilter.unconfirmed => 'No IN scan',
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
          if (_error != null) ...[
            const SizedBox(height: 12),
            SfErrorBanner(message: _error!),
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
                  'Updated ${formatSmartflowTime(_lastLoaded!.toIso8601String())} · pull to refresh',
                  style: const TextStyle(
                    fontSize: 10,
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
                        onPressed: () => setState(() => _filter = SfAlertFilter.all),
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
              const SfAlertsHealthyEmptyPanel(),
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

class _HeadAnalyticsScreenState extends State<HeadAnalyticsScreen> {
  Map<String, dynamic>? _data;
  String? _error;
  bool _loading = true;
  DateTime? _lastLoaded;
  late String _month;

  @override
  void initState() {
    super.initState();
    _month = DateFormat('yyyy-MM').format(DateTime.now());
    _load();
  }

  Future<void> _load() async {
    final oid = context.read<AuthProvider>().user!.officeId;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data =
          await context.read<AuthProvider>().api.headAnalytics(oid, _month);
      if (!mounted) return;
      setState(() {
        _data = data;
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
    context.push('/head/history', extra: {'documentId': docId});
  }

  @override
  Widget build(BuildContext context) {
    final stats = _data?['stats'] as Map<String, dynamic>?;
    final slow = _data?['slow_documents'] as List<dynamic>? ?? [];
    final user = context.watch<AuthProvider>().user!;
    final monthLabel = _data?['month']?.toString() ??
        DateFormat('MMMM yyyy').format(DateTime.parse('$_month-01'));
    final processed = (stats?['processed'] as int?) ?? 0;
    final late = (stats?['late_count'] as int?) ?? 0;
    final onTime = (stats?['on_time_percent'] as int?) ?? 0;
    final onTimeCount = (stats?['on_time_count'] as int?) ?? 0;
    final unforwardedCount = (stats?['unforwarded_count'] as int?) ?? 0;
    final delayedCount = (stats?['delayed_count'] as int?) ?? late;
    // Prefer backend-provided breakdown; fallback to legacy residual math.
    final delayed = (stats?['delayed_percent'] as int?) ??
        (processed > 0 ? ((late / processed) * 100).round() : 0);
    final unforwarded = (stats?['unforwarded_percent'] as int?) ??
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
            SfErrorBanner(message: _error!),
          ],
          const SizedBox(height: 12),
          SfFormCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.calendar_month_rounded,
                    size: 18, color: SfColors.blue),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    monthLabel,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _pickMonth,
                  child: const Text('Change month'),
                ),
              ],
            ),
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
            ),
            const SizedBox(height: 12),
            SfSummaryCard(
              title: 'Office summary',
              rows: [
                MapEntry('Office', '${user.officeName} (${user.officeCode})'),
                MapEntry('Month', monthLabel),
                MapEntry('Documents touched', '$processed'),
                MapEntry('On time', '$onTime% · $onTimeCount folder${onTimeCount == 1 ? '' : 's'}'),
                MapEntry(
                  'Unforwarded',
                  '$unforwarded% · $unforwardedCount folder${unforwardedCount == 1 ? '' : 's'}',
                ),
                MapEntry(
                  'Delayed',
                  '$delayed% · $delayedCount folder${delayedCount == 1 ? '' : 's'}',
                ),
                MapEntry('Exceeded threshold', '$late'),
              ],
            ),
            const SizedBox(height: 12),
            SfSecondaryOutlineButton(
              label: 'Open overdue in queue',
              icon: SfIcons.headQueueActive,
              onPressed: () => context.go(
                '/head/queue',
                extra: {'filter': 'overdue'},
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              const Text(
                'Slow documents',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
              const Spacer(),
              if (slow.isNotEmpty)
                Text(
                  'Top ${slow.length.clamp(0, 5)}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: SfColors.muted,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (!_loading && slow.isEmpty)
            const SfEmptyState(
              icon: Icons.speed_rounded,
              title: 'No slow documents',
              subtitle: 'All processed items met the threshold this month.',
            )
          else
            ...slow.map((d) {
              final m = d as Map<String, dynamic>;
              final id = m['document_id']?.toString() ?? '';
              final hours = m['hours'] as int? ?? 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SfFormCard(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                                  fontSize: 10,
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
              'Updated ${formatSmartflowTime(_lastLoaded!.toIso8601String())} · pull to refresh',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10,
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
