import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_client.dart';
import '../../theme/sf_icons.dart';
import '../../theme/smartflow_theme.dart';
import '../../utils/alert_actions.dart';
import '../../utils/api_error.dart';
import '../../utils/format_time.dart';
import '../../utils/tracking_id.dart';
import '../../widgets/mark_out_destination_dialog.dart';
import '../../widgets/sf_help.dart';
import '../../widgets/sf_page.dart';
import '../../widgets/sf_pdf_chrome.dart';
import '../../widgets/sf_widgets.dart';
import '../admin/admin_shell.dart';
import '../head/head_widgets.dart';
import '../shared/change_password_sheet.dart';
import '../shared/edit_profile_sheet.dart';
import '../shared/profile_photo.dart';
import 'clerk_widgets.dart';

class StaffShell extends StatefulWidget {
  const StaffShell({super.key, required this.child});

  final Widget child;

  @override
  State<StaffShell> createState() => _StaffShellState();
}

class _StaffShellState extends State<StaffShell> {
  int _alertCount = 0;

  @override
  void initState() {
    super.initState();
    _loadAlertCount();
  }

  Future<void> _loadAlertCount() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated || !auth.user!.isStaff) return;
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
    '/staff',
    '/staff/scan',
    '/staff/alerts',
  ];

  /// Secondary destinations from bottom Menu sheet (not Profile — that’s ENG).
  static const _menuRoutes = [
    '/staff/register',
    '/staff/history',
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
            icon: SfIcons.clerkHome,
            activeIcon: SfIcons.clerkHomeActive,
            label: 'Home',
          ),
          const SfNavTab(
            icon: SfIcons.clerkScan,
            activeIcon: SfIcons.clerkScanActive,
            label: 'Scan',
            elevated: true,
          ),
          SfNavTab(
            icon: SfIcons.clerkAlerts,
            activeIcon: SfIcons.clerkAlertsActive,
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

// ─── Dashboard (Figma page 6) ───────────────────────────────────────────────

class StaffDashboardScreen extends StatefulWidget {
  const StaffDashboardScreen({super.key});

  @override
  State<StaffDashboardScreen> createState() => _StaffDashboardScreenState();
}

class _StaffDashboardScreenState extends State<StaffDashboardScreen> {
  final _scrollCtrl = ScrollController();
  final _activeSectionKey = GlobalKey();

  Map<String, dynamic>? _stats;
  Map<String, dynamic>? _requestSummary;
  List<dynamic> _activeDocs = [];
  List<dynamic> _recentMoves = [];
  List<dynamic> _inTransit = [];
  String? _error;
  bool _loading = true;
  String? _markingOutDocId;
  String? _markingInDocId;
  DateTime? _lastLoaded;

  @override
  void initState() {
    super.initState();
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) maybeShowSfRoleTip(context);
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _refreshShellAlerts() {
    context.findAncestorStateOfType<_StaffShellState>()?._loadAlertCount();
  }

  Future<void> _load() async {
    final user = context.read<AuthProvider>().user!;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<AuthProvider>().api;
      final data = await api.dashboardStats(user.officeId);
      Map<String, dynamic>? reqSum;
      try {
        reqSum = await api.documentRequestsSummary();
      } on ApiException {
        // Optional — old XAMPP copy may lack this file until sync.
        reqSum = null;
      } catch (_) {
        reqSum = null;
      }
      if (!mounted) return;
      setState(() {
        _stats = data['stats'] as Map<String, dynamic>?;
        _requestSummary = reqSum;
        _activeDocs = data['active_documents'] as List<dynamic>? ?? [];
        _recentMoves = data['recent_movements'] as List<dynamic>? ?? [];
        _inTransit = data['in_transit'] as List<dynamic>? ?? [];
        _loading = false;
        _lastLoaded = DateTime.now();
      });
      _refreshShellAlerts();
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

  void _scrollToActive() {
    final ctx = _activeSectionKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
  }

  String _activeDeskEmptyMessage(String _) {
    return 'No folders IN here right now.';
  }

  Future<void> _markInIncoming(Map<String, dynamic> doc) async {
    final user = context.read<AuthProvider>().user!;
    final id = doc['document_id']?.toString() ?? '';
    final fromOffice = doc['last_office_name']?.toString() ?? 'another office';
    final destCode = doc['destination_office_code']?.toString();
    final destName = doc['destination_office_name']?.toString();
    final destLine = destCode != null && destCode.isNotEmpty
        ? '\nSent to: $destName ($destCode).'
        : '';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Receive folder?'),
        content: Text(
          'Mark $id as IN at ${user.officeName}? '
          'It is currently OUT from $fromOffice.$destLine',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Mark IN'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _markingInDocId = id);
    try {
      await context.read<AuthProvider>().api.recordMovement(
            documentId: id,
            officeId: user.officeId,
            status: 'IN',
            remarks: 'Received at ${user.officeName}',
          );
      if (!mounted) return;
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$id received at ${user.officeName}'),
          backgroundColor: SfColors.green,
        ),
      );
      await _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: SfColors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _markingInDocId = null);
    }
  }

  Future<void> _markOut(
    String documentId, {
    String? documentType,
  }) async {
    final user = context.read<AuthProvider>().user!;
    final destination = await showMarkOutDestinationDialog(
      context,
      documentId: documentId,
      myOfficeId: user.officeId,
      myOfficeName: user.officeName,
      myOfficeCode: user.officeCode,
      documentType: documentType,
    );
    if (destination == null || !mounted) return;

    setState(() => _markingOutDocId = documentId);
    try {
      await context.read<AuthProvider>().api.recordMovement(
            documentId: documentId,
            officeId: user.officeId,
            status: 'OUT',
            destinationOfficeId: destination.officeId,
            remarks:
                'Forwarded from ${user.officeName} → ${destination.code}',
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$documentId marked OUT'),
          backgroundColor: SfColors.blue,
        ),
      );
      await _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: SfColors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _markingOutDocId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _stats;
    final dash = s == null && !_loading ? null : s;
    final inFlow = dash == null ? '—' : '${dash['in_flow']}';
    final outFlow = dash == null ? '—' : '${dash['out_flow']}';
    final tags = dash == null ? '—' : '${dash['active_tags']}';

    final outbox = _requestSummary?['outbox'] as Map<String, dynamic>?;
    final rejected = (outbox?['rejected'] as int?) ?? 0;
    final approved = (outbox?['approved'] as int?) ?? 0;
    final pendingOut = (outbox?['pending'] as int?) ?? 0;
    String? requestHint;
    if (rejected > 0 || approved > 0 || pendingOut > 0) {
      final parts = <String>[];
      if (rejected > 0) {
        parts.add('$rejected declined');
      }
      if (approved > 0) {
        parts.add('$approved approved');
      }
      if (pendingOut > 0) {
        parts.add('$pendingOut pending');
      }
      requestHint = parts.join(' · ');
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: SfColors.blue,
      child: ListView(
        controller: _scrollCtrl,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          const SfClerkAppHeader(),
          const SizedBox(height: 10),
          const SfClerkPageOverviewCard(screen: SfClerkScreen.home),
          if (requestHint != null) ...[
            const SizedBox(height: 12),
            SfClerkStartHereCard(requestStatusHint: requestHint),
          ],
          const SizedBox(height: 14),
          if (_error != null) ...[
            SfErrorBanner(message: _error!),
            const SizedBox(height: 10),
          ],
          if (_loading)
            const SfDashboardStatSkeleton()
          else
            SfDashboardStatRow(
              inFlow: inFlow,
              outFlow: outFlow,
              activeTags: tags,
              onInFlowTap: () => context.go(
                    '/staff/history',
                    extra: {'todayFilter': 'IN'},
                  ),
              onOutFlowTap: () => context.go(
                    '/staff/history',
                    extra: {'todayFilter': 'OUT'},
                  ),
              onActiveTap: _scrollToActive,
            ),
          if (_inTransit.isNotEmpty) ...[
            const SizedBox(height: 20),
            SfClerkSectionHeader(
              title: 'Incoming',
              link: '${_inTransit.length}',
            ),
            const SizedBox(height: 8),
            ..._inTransit.map((d) {
              final m = d as Map<String, dynamic>;
              final id = m['document_id']?.toString() ?? '';
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SfClerkIncomingDocRow(
                  documentId: id,
                  title: m['title']?.toString() ?? m['type']?.toString() ?? '',
                  fromOfficeCode:
                      m['last_office_code']?.toString() ?? '—',
                  fromOfficeName:
                      m['last_office_name']?.toString() ?? '',
                  sentToOfficeCode:
                      m['destination_office_code']?.toString(),
                  outAt: m['last_scanned_at']?.toString(),
                  receiving: _markingInDocId == id,
                  onTap: () => context.push(
                    '/staff/history',
                    extra: {'documentId': id},
                  ),
                  onMarkIn: () => _markInIncoming(m),
                ),
              );
            }),
          ],
          const SizedBox(height: 20),
          SfClerkSectionHeader(
            key: _activeSectionKey,
            title: 'At your office now',
            link: _activeDocs.isEmpty
                ? '0 folders'
                : '${_activeDocs.length} folder(s)',
          ),
          const SizedBox(height: 10),
          if (_activeDocs.isEmpty)
            SfClerkEmptyDeskCard(message: _activeDeskEmptyMessage(outFlow))
          else
            ..._activeDocs.map((d) {
              final m = d as Map<String, dynamic>;
              final id = m['document_id']?.toString() ?? '';
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SfClerkActiveDocumentRow(
                  documentId: id,
                  title: m['title']?.toString() ?? m['type']?.toString() ?? '',
                  lastScannedAt: m['last_scanned_at']?.toString(),
                  markingOut: _markingOutDocId == id,
                  onTap: () => context.push(
                    '/staff/history',
                    extra: {'documentId': id},
                  ),
                  onMarkOut: () => _markOut(
                    id,
                    documentType: m['type']?.toString(),
                  ),
                ),
              );
            }),
          if (_recentMoves.isNotEmpty) ...[
            const SizedBox(height: 16),
            const SfClerkSectionHeader(title: "Today's activity"),
            const SizedBox(height: 4),
            const Text(
              'Latest scans at your office (newest first)',
              style: TextStyle(fontSize: 11, color: SfColors.muted),
            ),
            const SizedBox(height: 10),
            ..._recentMoves.take(5).map((r) {
              final m = r as Map<String, dynamic>;
              final st = m['status']?.toString() ?? '';
              final title = m['title']?.toString();
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: SfFormCard(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      SfStatusPill(
                        label: st == 'OUT' ? 'SENT' : 'IN',
                        tone: st == 'IN'
                            ? SfPillTone.success
                            : SfPillTone.danger,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              m['document_id']?.toString() ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                            if (title != null && title.isNotEmpty)
                              Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: SfColors.ink,
                                ),
                              ),
                            Text(
                              movementScanSubtitle(m),
                              style: const TextStyle(
                                fontSize: 10,
                                color: SfColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
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

class StaffAlertsScreen extends StatefulWidget {
  const StaffAlertsScreen({super.key});

  @override
  State<StaffAlertsScreen> createState() => _StaffAlertsScreenState();
}

class _StaffAlertsScreenState extends State<StaffAlertsScreen> {
  List<dynamic> _alerts = [];
  Map<String, AlertActionState> _actions = const {};
  String? _error;
  bool _loading = true;
  SfAlertFilter _filter = SfAlertFilter.all;
  DateTime? _lastLoaded;

  String _actionKey(Map a) =>
      '${a['document_id']}::${a['kind']}';

  AlertActionState _stateFor(Map a) =>
      _actions[_actionKey(a)] ?? const AlertActionState();

  List<Map<String, dynamic>> get _visibleAlerts {
    return _alerts
        .map((a) => Map<String, dynamic>.from(a as Map))
        .where((m) => !_stateFor(m).isHidden)
        .toList();
  }

  int get _hiddenCount => _alerts
      .map((a) => Map<String, dynamic>.from(a as Map))
      .where((m) => _stateFor(m).isHidden)
      .length;

  int get _countDelayed => _visibleAlerts
      .where((a) => a['kind'] == 'delayed')
      .length;

  int get _countDueSoon => _visibleAlerts
      .where((a) => a['kind'] == 'due_soon')
      .length;

  int get _countUnconfirmed => _visibleAlerts
      .where((a) => a['kind'] == 'unconfirmed')
      .length;

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

  Future<void> _syncAlertBadge() async {
    final count = await AlertActionsStore.visibleCount(_alerts);
    if (mounted) {
      context.findAncestorStateOfType<_StaffShellState>()?.refreshAlertBadge(count);
    }
  }

  Future<void> _remindLater(Map<String, dynamic> a) async {
    final id = a['document_id']?.toString() ?? '';
    final kind = a['kind']?.toString() ?? '';
    if (id.isEmpty || kind.isEmpty) return;
    await AlertActionsStore.snooze(id, kind, const Duration(hours: 24));
    await _refreshActions(_alerts);
    await _syncAlertBadge();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Hidden until tomorrow. Undo if you still need it.'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              await AlertActionsStore.unsnooze(id, kind);
              await _refreshActions(_alerts);
              await _syncAlertBadge();
            },
          ),
        ),
      );
    }
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
      setState(() {
        _alerts = list;
        _loading = false;
        _lastLoaded = DateTime.now();
      });
      await _refreshActions(list);
      await _syncAlertBadge();
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
    context.push('/staff/history', extra: {'documentId': docId});
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
    final docTitle = _compactText(m['document_title']);
    final detail = _compactText(m['detail']);
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
    final title = docTitle.isNotEmpty
        ? docTitle
        : (docId.isNotEmpty ? docId : 'Document alert');
    final subtitle =
        detail.isNotEmpty ? detail : 'Open Scan to follow up on this folder.';

    return SfAlertCardWithActions(
      title: title,
      subtitle: subtitle,
      accent: accent,
      pill1: pill1,
      pill2: pendingLabel,
      rule: rule,
      onOpen: docId.isEmpty ? null : () => _openHistory(docId),
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
          const SizedBox(height: 8),
          const SfClerkPageOverviewCard(screen: SfClerkScreen.alerts),
          const SizedBox(height: 14),
          if (_error != null) ...[
            SfErrorBanner(message: _error!),
            const SizedBox(height: 12),
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
                SfFormCard(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.filter_list_off_outlined,
                            size: 18,
                            color: SfColors.muted,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _filter == SfAlertFilter.all
                                ? 'No alerts'
                                : 'No alerts in this filter',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _filter == SfAlertFilter.all
                            ? 'Your office is within processing thresholds.'
                            : 'Try All or pull to refresh.',
                        style: const TextStyle(
                          fontSize: 12,
                          color: SfColors.muted,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          if (_filter != SfAlertFilter.all)
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => setState(() => _filter = SfAlertFilter.all),
                                icon: const Icon(Icons.tune_rounded, size: 16),
                                label: const Text('Show all'),
                              ),
                            ),
                          if (_filter != SfAlertFilter.all) const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => context.go('/staff/history'),
                              icon: const Icon(Icons.history_rounded, size: 16),
                              label: const Text('Go to history'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
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

// ─── Audit trail (Figma page 8) ─────────────────────────────────────────────

enum StaffTodayScanFilter { all, received, sent }

extension StaffTodayScanFilterX on StaffTodayScanFilter {
  bool matchesStatus(String status) {
    final st = status.toUpperCase();
    switch (this) {
      case StaffTodayScanFilter.all:
        return true;
      case StaffTodayScanFilter.received:
        return st == 'IN';
      case StaffTodayScanFilter.sent:
        return st == 'OUT';
    }
  }

  String get sectionTitle {
    switch (this) {
      case StaffTodayScanFilter.all:
        return "Today's activity";
      case StaffTodayScanFilter.received:
        return "Today's received";
      case StaffTodayScanFilter.sent:
        return "Today's sent";
    }
  }
}

class StaffHistoryScreen extends StatefulWidget {
  const StaffHistoryScreen({
    super.key,
    this.initialDocumentId,
    this.initialTodayFilter,
    this.monitorOnly = false,
  });

  final String? initialDocumentId;

  /// `IN` or `OUT` — office-level filter for today's scans list.
  final String? initialTodayFilter;

  /// Department head: read-only audit trail (no scanner shortcuts).
  final bool monitorOnly;

  static StaffTodayScanFilter parseTodayFilter(String? raw) {
    switch (raw?.toUpperCase()) {
      case 'IN':
        return StaffTodayScanFilter.received;
      case 'OUT':
        return StaffTodayScanFilter.sent;
      default:
        return StaffTodayScanFilter.all;
    }
  }

  @override
  State<StaffHistoryScreen> createState() => _StaffHistoryScreenState();
}

class _StaffHistoryScreenState extends State<StaffHistoryScreen> {
  final _todaySectionKey = GlobalKey();
  final _lookupCtrl = TextEditingController();

  List<dynamic> _movements = [];
  List<dynamic> _officeTray = [];
  List<dynamic> _todayScans = [];
  final List<String> _recentIds = [];
  Map<String, dynamic>? _document;
  String? _loadedId;
  String? _error;
  bool _loading = false;
  bool _trayLoading = true;
  _MovementFilter _movementFilter = _MovementFilter.all;
  late StaffTodayScanFilter _todayScanFilter;

  int get _countTodayIn => _todayScans
      .where(
        (r) =>
            (r as Map)['status']?.toString().toUpperCase() == 'IN',
      )
      .length;

  int get _countTodayOut => _todayScans
      .where(
        (r) =>
            (r as Map)['status']?.toString().toUpperCase() == 'OUT',
      )
      .length;

  List<dynamic> get _filteredTodayScans => _todayScans.where((r) {
        final st = (r as Map)['status']?.toString() ?? '';
        return _todayScanFilter.matchesStatus(st);
      }).toList();

  int get _countIn => _movements
      .where((m) => (m as Map)['status']?.toString().toUpperCase() == 'IN')
      .length;

  int get _countOut => _movements
      .where((m) => (m as Map)['status']?.toString().toUpperCase() == 'OUT')
      .length;

  @override
  void initState() {
    super.initState();
    _todayScanFilter =
        StaffHistoryScreen.parseTodayFilter(widget.initialTodayFilter);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadOfficeTray();
      final initial = widget.initialDocumentId?.trim();
      if (initial != null && initial.isNotEmpty) {
        _openId(initial);
      }
      if (widget.initialTodayFilter != null) {
        _scrollToTodaySection();
      }
    });
  }

  @override
  void dispose() {
    _lookupCtrl.dispose();
    super.dispose();
  }

  void _scrollToTodaySection() {
    final ctx = _todaySectionKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _loadOfficeTray() async {
    final oid = context.read<AuthProvider>().user!.officeId;
    setState(() => _trayLoading = true);
    try {
      final data = await context.read<AuthProvider>().api.dashboardStats(oid);
      if (!mounted) return;
      setState(() {
        _officeTray = data['active_documents'] as List<dynamic>? ?? [];
        _todayScans = data['recent_movements'] as List<dynamic>? ?? [];
        _trayLoading = false;
      });
      if (widget.initialTodayFilter != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToTodaySection();
        });
      }
    } catch (_) {
      if (mounted) setState(() => _trayLoading = false);
    }
  }

  void _rememberId(String id) {
    _recentIds.remove(id);
    _recentIds.insert(0, id);
    if (_recentIds.length > 5) {
      _recentIds.removeRange(5, _recentIds.length);
    }
  }

  Future<void> _refresh() async {
    await _loadOfficeTray();
    if (_loadedId != null) {
      await _loadDocument(_loadedId!);
    }
  }

  Future<void> _loadDocument(String rawId) async {
    final parsed = parseTrackingId(rawId) ?? rawId.trim();
    if (parsed.isEmpty) return;
    final id = parsed;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<AuthProvider>().api;
      final movData = await api.documentMovements(id);
      final docData = await api.documentShow(id);
      if (!mounted) return;
      _rememberId(id);
      setState(() {
        _movements = movData['movements'] as List<dynamic>? ?? [];
        _document = docData['document'] as Map<String, dynamic>?;
        _loadedId = id;
        _loading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _movements = [];
        _document = null;
        _loadedId = null;
        _loading = false;
      });
    }
  }

  void _openId(String id) {
    final cleaned = parseTrackingId(id) ?? id.trim();
    if (cleaned.isEmpty) return;
    _lookupCtrl.text = cleaned;
    _loadDocument(cleaned);
  }

  void _clearLoaded() {
    setState(() {
      _movements = [];
      _document = null;
      _loadedId = null;
      _error = null;
      _movementFilter = _MovementFilter.all;
    });
  }

  bool get _showingTrail => _loadedId != null && _document != null;

  List<Widget> _browsePickList(BuildContext context) {
    if (_trayLoading) return [const SfLoadingCard()];

    // Head: one list — folders at office.
    if (widget.monitorOnly) {
      if (_officeTray.isEmpty) {
        return [
          const SfEmptyState(
            icon: Icons.inbox_outlined,
            title: 'Nothing at your office',
            subtitle: 'Folders appear when clerks scan them IN or OUT.',
          ),
        ];
      }
      return [
        const SfClerkSectionHeader(title: 'At your office'),
        const SizedBox(height: 8),
        ..._officeTray.map(_officeTrayRow),
      ];
    }

    // Clerk: one list — today's scans (home Received/Sent land here).
    return [
      SfClerkSectionHeader(
        key: _todaySectionKey,
        title: 'Today at your office',
      ),
      const SizedBox(height: 8),
      _TodayScanFilterChips(
        countAll: _todayScans.length,
        countIn: _countTodayIn,
        countOut: _countTodayOut,
        selected: _todayScanFilter,
        onSelected: (f) => setState(() => _todayScanFilter = f),
      ),
      const SizedBox(height: 10),
      if (_filteredTodayScans.isEmpty)
        SfEmptyState(
          icon: Icons.history_rounded,
          title: _todayScans.isEmpty
              ? 'No scans today'
              : 'No ${_todayScanFilter == StaffTodayScanFilter.received ? 'received' : 'sent'} scans',
          subtitle: _todayScans.isEmpty
              ? 'Scan a folder, or look up a tracking ID above.'
              : 'Try All, or look up an ID.',
          actionLabel: _todayScans.isEmpty ? 'Open Scanner' : 'Show all',
          onAction: _todayScans.isEmpty
              ? () => context.go('/staff/scan')
              : () => setState(() => _todayScanFilter = StaffTodayScanFilter.all),
        )
      else
        ..._filteredTodayScans.take(15).map(_todayMovementCard),
      if (_officeTray.isNotEmpty) ...[
        const SizedBox(height: 16),
        SfClerkSectionHeader(
          title: 'Still on desk',
          link: '${_officeTray.length}',
        ),
        const SizedBox(height: 8),
        ..._officeTray.take(8).map(_officeTrayRow),
      ],
    ];
  }

  Widget _officeTrayRow(dynamic d) {
    final m = d as Map<String, dynamic>;
    final id = m['document_id']?.toString() ?? '';
    final st = (m['current_status']?.toString() ?? 'IN').toUpperCase();
    final isIn = st == 'IN';
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: SfClerkModuleRow(
        code: st == 'OUT' ? 'SENT' : 'IN',
        title: id,
        subtitle: m['title']?.toString() ?? '',
        color: isIn ? SfColors.green : SfColors.blue,
        onTap: () => _openId(id),
      ),
    );
  }

  Widget _todayMovementCard(dynamic r) {
    final m = r as Map<String, dynamic>;
    final st = m['status']?.toString() ?? '';
    final docId = m['document_id']?.toString() ?? '';
    final title = m['title']?.toString();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: SfFormCard(
        flat: true,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: InkWell(
          onTap: docId.isEmpty ? null : () => _openId(docId),
          borderRadius: BorderRadius.circular(8),
          child: Row(
            children: [
              SfStatusPill(
                label: st == 'OUT' ? 'SENT' : 'IN',
                tone: st == 'IN' ? SfPillTone.success : SfPillTone.danger,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      docId,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    if (title != null && title.isNotEmpty)
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: SfColors.muted,
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                formatMovementListTime(m['scanned_at']?.toString()),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: SfColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reversed = _movements.reversed.toList();
    final timeline = reversed.where((row) {
      final st = (row as Map)['status']?.toString().toUpperCase() ?? '';
      switch (_movementFilter) {
        case _MovementFilter.all:
          return true;
        case _MovementFilter.inOnly:
          return st == 'IN';
        case _MovementFilter.outOnly:
          return st == 'OUT';
      }
    }).toList();

    return RefreshIndicator(
      onRefresh: _refresh,
      color: SfColors.blue,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          const SfAuthenticatedPageHeader(),
          const SizedBox(height: 10),
          if (widget.monitorOnly)
            const SfHeadPageOverviewCard(
              screen: SfHeadScreen.history,
              compact: true,
            )
          else
            const SfClerkPageOverviewCard(
              screen: SfClerkScreen.history,
              compact: true,
            ),
          const SizedBox(height: 8),
          Text(
            widget.monitorOnly
                ? 'Look up a tracking ID or open a folder from Queue.'
                : 'Browse today’s scans, then open a trail for one folder.',
            style: TextStyle(
              fontSize: 11.5,
              height: 1.35,
              color: SfColors.muted.withValues(alpha: 0.95),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          _HistoryLookupCard(
            controller: _lookupCtrl,
            loading: _loading,
            onLookup: () => _openId(_lookupCtrl.text),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            SfErrorBanner(message: _error!),
          ],

          // ── Trail mode: one document ─────────────────────────────────
          if (_showingTrail) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _clearLoaded,
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text('Back to list'),
                style: TextButton.styleFrom(
                  foregroundColor: SfColors.blue,
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
            const SizedBox(height: 8),
            SfHistoryDocumentSummary(
              doc: _document!,
              movementCount: _movements.length,
              onCopyId: () {
                Clipboard.setData(ClipboardData(text: _loadedId!));
                sfShowSuccessSnack(
                  context,
                  message: 'Tracking ID copied',
                  backgroundColor: SfColors.navy,
                );
              },
              onOpenScan:
                  widget.monitorOnly ? null : () => context.go('/staff/scan'),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text(
                  'Custody trail',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
                const Spacer(),
                if (_movements.isNotEmpty)
                  Text(
                    '${timeline.length} of ${_movements.length}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: SfColors.muted,
                    ),
                  ),
              ],
            ),
            if (_movements.isNotEmpty) ...[
              const SizedBox(height: 10),
              _MovementFilterChips(
                total: _movements.length,
                countIn: _countIn,
                countOut: _countOut,
                selected: _movementFilter,
                onSelected: (f) => setState(() => _movementFilter = f),
              ),
            ],
            const SizedBox(height: 12),
            if (_loading)
              const SfLoadingCard()
            else if (_movements.isEmpty)
              SfEmptyState(
                icon: SfIcons.timeline,
                title: 'No scans yet',
                subtitle: widget.monitorOnly
                    ? 'No IN/OUT movements for this tracking ID.'
                    : null,
                actionLabel: widget.monitorOnly ? null : 'Open Scanner',
                onAction: widget.monitorOnly
                    ? null
                    : () => context.go('/staff/scan'),
              )
            else if (timeline.isEmpty)
              SfEmptyState(
                icon: Icons.filter_list_off_outlined,
                title: 'No matching scans',
                subtitle:
                    'No ${_movementFilter == _MovementFilter.inOnly ? 'received' : 'sent'} events — try All.',
                actionLabel: 'Show all',
                onAction: () =>
                    setState(() => _movementFilter = _MovementFilter.all),
              )
            else
              ...List.generate(timeline.length, (i) {
                final row = timeline[i] as Map<String, dynamic>;
                return SfMovementTimelineTile(
                  status: row['status']?.toString() ?? '—',
                  officeName: row['office_name']?.toString() ?? '',
                  officeCode: row['office_code']?.toString() ?? '',
                  scannedAt: row['scanned_at']?.toString() ?? '',
                  username: row['username']?.toString() ?? '',
                  remarks: row['remarks']?.toString() ?? '',
                  destinationOfficeCode:
                      row['destination_office_code']?.toString(),
                  destinationOfficeName:
                      row['destination_office_name']?.toString(),
                  isLast: i == timeline.length - 1,
                );
              }),
          ]

          // ── Browse mode: pick something to open ──────────────────────
          else ...[
            if (_recentIds.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Recent lookups',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: SfColors.muted,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _recentIds.map((id) {
                  return ActionChip(
                    label: Text(
                      id,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onPressed: () => _openId(id),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 14),
            ..._browsePickList(context),
          ],
        ],
      ),
    );
  }
}

enum _MovementFilter { all, inOnly, outOnly }

class _HistoryLookupCard extends StatelessWidget {
  const _HistoryLookupCard({
    required this.controller,
    required this.loading,
    required this.onLookup,
  });

  final TextEditingController controller;
  final bool loading;
  final VoidCallback onLookup;

  @override
  Widget build(BuildContext context) {
    return SfFormCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Look up tracking ID',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          ),
          const SizedBox(height: 4),
          const Text(
            'Enter a tracking ID or tap a folder below.',
            style: TextStyle(fontSize: 11, color: SfColors.muted, height: 1.35),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            textCapitalization: TextCapitalization.characters,
            autocorrect: false,
            decoration: const InputDecoration(
              hintText: 'Enter tracking ID',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onSubmitted: loading ? null : (_) => onLookup(),
          ),
          const SizedBox(height: 10),
          SfPrimaryButton(
            label: loading ? 'Loading…' : 'Open audit trail',
            loading: loading,
            onPressed: loading ? null : onLookup,
          ),
        ],
      ),
    );
  }
}

class _TodayScanFilterChips extends StatelessWidget {
  const _TodayScanFilterChips({
    required this.countAll,
    required this.countIn,
    required this.countOut,
    required this.selected,
    required this.onSelected,
  });

  final int countAll;
  final int countIn;
  final int countOut;
  final StaffTodayScanFilter selected;
  final ValueChanged<StaffTodayScanFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _chip('All', StaffTodayScanFilter.all, countAll),
          const SizedBox(width: 8),
          _chip('Received', StaffTodayScanFilter.received, countIn),
          const SizedBox(width: 8),
          _chip('Sent', StaffTodayScanFilter.sent, countOut),
        ],
      ),
    );
  }

  Widget _chip(String label, StaffTodayScanFilter value, int count) {
    final isSelected = selected == value;
    return FilterChip(
      label: Text('$label${count > 0 ? ' ($count)' : ''}'),
      selected: isSelected,
      onSelected: (_) => onSelected(value),
      selectedColor: SfColors.blue.withValues(alpha: 0.15),
      checkmarkColor: SfColors.blue,
      labelStyle: TextStyle(
        fontSize: 11,
        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
      ),
    );
  }
}

class _MovementFilterChips extends StatelessWidget {
  const _MovementFilterChips({
    required this.total,
    required this.countIn,
    required this.countOut,
    required this.selected,
    required this.onSelected,
  });

  final int total;
  final int countIn;
  final int countOut;
  final _MovementFilter selected;
  final ValueChanged<_MovementFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _chip('All', _MovementFilter.all, total),
          const SizedBox(width: 8),
          _chip('Received', _MovementFilter.inOnly, countIn),
          const SizedBox(width: 8),
          _chip('Sent', _MovementFilter.outOnly, countOut),
        ],
      ),
    );
  }

  Widget _chip(String label, _MovementFilter value, int count) {
    final isSelected = selected == value;
    return FilterChip(
      label: Text('$label${count > 0 ? ' ($count)' : ''}'),
      selected: isSelected,
      onSelected: (_) => onSelected(value),
      selectedColor: SfColors.blue.withValues(alpha: 0.15),
      checkmarkColor: SfColors.blue,
      labelStyle: TextStyle(
        fontSize: 11,
        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
      ),
    );
  }
}

// ─── Profile (Figma page 10) — clerk uses enhanced layout ─────────────────────

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user!;
    if (user.isStaff) {
      return _ClerkProfileView(user: user);
    }
    if (user.isHead) {
      return _HeadProfileView(user: user);
    }
    if (user.isAdmin) {
      return AdminProfileView(user: user);
    }
    return _GenericProfileView(user: user);
  }
}

class _ClerkProfileView extends StatefulWidget {
  const _ClerkProfileView({required this.user});

  final AppUser user;

  @override
  State<_ClerkProfileView> createState() => _ClerkProfileViewState();
}

class _ClerkProfileViewState extends State<_ClerkProfileView> {
  String? _inFlow;
  String? _outFlow;
  String? _activeTags;
  bool _statsLoading = true;
  bool _photoBusy = false;

  @override
  void initState() {
    super.initState();
    _loadDeskStats();
  }

  Future<void> _loadDeskStats() async {
    try {
      final data = await context
          .read<AuthProvider>()
          .api
          .dashboardStats(widget.user.officeId);
      final stats = data['stats'] as Map<String, dynamic>? ?? {};
      if (!mounted) return;
      setState(() {
        _inFlow = '${stats['in_flow'] ?? '—'}';
        _outFlow = '${stats['out_flow'] ?? '—'}';
        _activeTags = '${stats['active_tags'] ?? '—'}';
        _statsLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _statsLoading = false);
    }
  }

  Future<void> _logout() async {
    await context.read<AuthProvider>().logout();
    if (mounted) context.go('/login');
  }

  Future<void> _openChangePassword() async {
    await ChangePasswordSheet.show(context);
  }

  Future<void> _openEditProfile() async {
    await EditProfileSheet.show(context);
  }

  Future<void> _changePhoto() async {
    setState(() => _photoBusy = true);
    await sfPickAndUploadProfilePhoto(context);
    if (mounted) setState(() => _photoBusy = false);
  }

  Future<void> _removePhoto() async {
    setState(() => _photoBusy = true);
    await sfRemoveProfilePhoto(context);
    if (mounted) setState(() => _photoBusy = false);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user ?? widget.user;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final isSecurity = sfIsProfileSecurityView(context);

    return RefreshIndicator(
      onRefresh: _loadDeskStats,
      color: SfColors.blue,
      child: ListView(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 32 + bottomInset),
        children: [
          const SfAuthenticatedPageHeader(),
          const SizedBox(height: 12),
          SfClerkPageOverviewCard(
            screen: isSecurity
                ? SfClerkScreen.accountSecurity
                : SfClerkScreen.profile,
          ),
          const SizedBox(height: 14),
          if (isSecurity) ...[
            SfProfilePhotoCard(
              user: user,
              onChangePhoto: _changePhoto,
              onRemovePhoto: _removePhoto,
              photoBusy: _photoBusy,
            ),
            const SizedBox(height: 14),
            SfProfileSessionCard(
              user: user,
              onLogout: _logout,
              onChangePassword: _openChangePassword,
              onEditProfile: _openEditProfile,
              onShowTips: () => showSfRoleTipAgain(context),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => context.go(sfProfileRouteForRole(user.role)),
              child: const Text('Back to profile'),
            ),
          ] else ...[
            if (_statsLoading)
              const SfLoadingCard()
            else
              SfProfileAccountCard(
                user: user,
                inFlow: _inFlow,
                outFlow: _outFlow,
                activeTags: _activeTags,
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () =>
                  context.go(sfProfileRouteForRole(user.role, security: true)),
              style: FilledButton.styleFrom(
                backgroundColor: SfColors.navy,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Account & security'),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            'Municipality of Urbiztondo · Official document tracking · COA support',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              color: SfColors.muted.withValues(alpha: 0.85),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeadProfileView extends StatefulWidget {
  const _HeadProfileView({required this.user});

  final AppUser user;

  @override
  State<_HeadProfileView> createState() => _HeadProfileViewState();
}

class _HeadProfileViewState extends State<_HeadProfileView> {
  String? _inOffice;
  String? _overdue;
  String? _avgHours;
  bool _statsLoading = true;
  bool _photoBusy = false;

  @override
  void initState() {
    super.initState();
    _loadOfficeStats();
  }

  Future<void> _loadOfficeStats() async {
    try {
      final data = await context
          .read<AuthProvider>()
          .api
          .headDashboard(widget.user.officeId);
      final stats = data['stats'] as Map<String, dynamic>? ?? {};
      if (!mounted) return;
      setState(() {
        _inOffice = '${stats['in_office'] ?? '—'}';
        _overdue = '${stats['overdue'] ?? '—'}';
        _avgHours = '${stats['avg_hours'] ?? '—'}h';
        _statsLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _statsLoading = false);
    }
  }

  Future<void> _logout() async {
    await context.read<AuthProvider>().logout();
    if (mounted) context.go('/login');
  }

  Future<void> _openChangePassword() async {
    await ChangePasswordSheet.show(context);
  }

  Future<void> _openEditProfile() async {
    await EditProfileSheet.show(context);
  }

  Future<void> _changePhoto() async {
    setState(() => _photoBusy = true);
    await sfPickAndUploadProfilePhoto(context);
    if (mounted) setState(() => _photoBusy = false);
  }

  Future<void> _removePhoto() async {
    setState(() => _photoBusy = true);
    await sfRemoveProfilePhoto(context);
    if (mounted) setState(() => _photoBusy = false);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user ?? widget.user;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final isSecurity = sfIsProfileSecurityView(context);

    return RefreshIndicator(
      onRefresh: _loadOfficeStats,
      color: SfColors.blue,
      child: ListView(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 32 + bottomInset),
        children: [
          const SfAuthenticatedPageHeader(),
          const SizedBox(height: 12),
          SfHeadPageOverviewCard(
            screen: isSecurity
                ? SfHeadScreen.accountSecurity
                : SfHeadScreen.profile,
          ),
          const SizedBox(height: 14),
          if (isSecurity) ...[
            SfProfilePhotoCard(
              user: user,
              onChangePhoto: _changePhoto,
              onRemovePhoto: _removePhoto,
              photoBusy: _photoBusy,
            ),
            const SizedBox(height: 14),
            SfProfileSessionCard(
              user: user,
              onLogout: _logout,
              onChangePassword: _openChangePassword,
              onEditProfile: _openEditProfile,
              onShowTips: () => showSfRoleTipAgain(context),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => context.go(sfProfileRouteForRole(user.role)),
              child: const Text('Back to profile'),
            ),
          ] else ...[
            if (_statsLoading)
              const SfLoadingCard()
            else
              SfProfileAccountCard(
                user: user,
                deskSectionTitle: 'Office snapshot',
                stat1Label: 'In office',
                stat2Label: 'Overdue',
                stat3Label: 'Avg time',
                inFlow: _inOffice,
                outFlow: _overdue,
                activeTags: _avgHours,
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () =>
                  context.go(sfProfileRouteForRole(user.role, security: true)),
              style: FilledButton.styleFrom(
                backgroundColor: SfColors.navy,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Account & security'),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            'Municipality of Urbiztondo · Official document tracking · COA support',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              color: SfColors.muted.withValues(alpha: 0.85),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _GenericProfileView extends StatelessWidget {
  const _GenericProfileView({required this.user});

  final AppUser user;

  String _roleSubtitle(String role) {
    switch (role) {
      case 'head':
        return 'Department head · monitors one office.';
      case 'admin':
        return 'LGU IT admin · system configuration.';
      default:
        return 'SmartFlow user.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isHead = user.role == 'head';
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        SfHeader(
          title: 'Profile / Settings',
          subtitle: _roleSubtitle(user.role),
        ),
        const SizedBox(height: 20),
        SfFormCard(
          child: Row(
            children: [
              SfUserAvatar(
                initials: SfUserAvatar.fromName(user.name),
                size: 52,
                color: SfColors.dept(user.officeCode),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.username,
                      style: const TextStyle(color: SfColors.muted, fontSize: 13),
                    ),
                    Text(
                      '${user.officeName} · LGU Urbiztondo',
                      style: const TextStyle(color: SfColors.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (isHead) ...[
          const SizedBox(height: 12),
          SfSummaryCard(
            title: 'Session',
            rows: [
              MapEntry(
                'Role (database)',
                '${user.role} · monitor one office only',
              ),
              MapEntry(
                'Office scope',
                '${user.officeName} (${user.officeCode})',
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        SfSecondaryOutlineButton(
          label: 'Change password',
          icon: Icons.lock_reset_rounded,
          onPressed: () => ChangePasswordSheet.show(context),
        ),
        const SizedBox(height: 10),
        SfPrimaryButton(
          label: 'Log out',
          onPressed: () async {
            await context.read<AuthProvider>().logout();
            if (context.mounted) context.go('/login');
          },
        ),
      ],
    );
  }
}
