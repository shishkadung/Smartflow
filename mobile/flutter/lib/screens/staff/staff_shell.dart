import '../../widgets/home_folder_actions.dart';
import '../../utils/live_refresh.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_client.dart';
import '../../services/smartflow_api.dart';
import '../../theme/sf_icons.dart';
import '../../theme/smartflow_theme.dart';
import '../../utils/alert_actions.dart';
import '../../utils/api_error.dart';
import '../../widgets/sf_account_menu.dart';
import '../../utils/format_time.dart';
import '../../utils/recent_docs.dart';
import '../../utils/tracking_id.dart';
import '../../widgets/mark_out_destination_dialog.dart';
import '../../widgets/folder_contents.dart';
import '../../widgets/profile_snapshot_feedback.dart';
import '../../widgets/sf_help.dart';
import '../../widgets/sf_page.dart';
import '../../widgets/sf_pdf_chrome.dart';
import '../../widgets/sf_widgets.dart';
import '../admin/admin_shell.dart';
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

class _StaffShellState extends State<StaffShell> with LiveRefresh<StaffShell> {
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
    if (!auth.isAuthenticated || !auth.user!.isStaff) return;
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
    '/staff',
    '/staff/documents',
    '/staff/scan',
    '/staff/alerts',
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
    final profileActive = sfIsOnProfilePage(loc, 'staff');

    return SfNavBadgeScope(
      alertCount: _alertCount,
      child: SfAppScaffold(
        currentIndex: index,
        onTab: _onTab,
        onMenu: () =>
            showSfRoleMoreSheet(context, pendingRequests: _pendingRequests),
        onProfile: () => context.go(sfProfileRouteForRole('staff')),
        profileActive: profileActive,
        menuActive: index < 0 && !profileActive,
        tabs: [
          const SfNavTab(
            icon: SfIcons.clerkHome,
            activeIcon: SfIcons.clerkHomeActive,
            label: 'Home',
          ),
          const SfNavTab(
            icon: SfIcons.documents,
            activeIcon: SfIcons.documentsActive,
            label: 'Documents',
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
          const SfNavTab(icon: SfIcons.menu, label: 'Menu'),
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

class _StaffDashboardScreenState extends State<StaffDashboardScreen>
    with LiveRefresh<StaffDashboardScreen> {
  @override
  Future<void> refreshLiveData() => _load(silent: true);

  final _scrollCtrl = ScrollController();
  final _activeSectionKey = GlobalKey();

  Map<String, dynamic>? _stats;
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

  Future<void> _load({bool silent = false}) async {
    if (!mounted ||
        !context.read<AuthProvider>().isAuthenticated ||
        (silent && _loading)) {
      return;
    }
    final user = context.read<AuthProvider>().user!;
    setState(() {
      if (!silent) {
        _loading = true;
      }
      _error = null;
    });
    try {
      final api = context.read<AuthProvider>().api;
      final data = await api.dashboardStats(user.officeId);
      if (!mounted) return;
      setState(() {
        _stats = data['stats'] as Map<String, dynamic>?;
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

  Future<void> _markInIncoming(Map<String, dynamic> doc) async {
    if (_markingInDocId != null) return;
    final auth = context.read<AuthProvider>();
    final user = auth.user!;
    final api = auth.api;
    final identity = auth.sessionIdentity;
    bool currentSession() => mounted && auth.sessionIdentity == identity;
    if (auth.loggingOut) return;
    final id = doc['document_id']?.toString() ?? '';
    setState(() => _markingInDocId = id);
    try {
      final shown = await api.officeDocuments(id: id);
      if (!mounted || !currentSession()) return;
      final current = shown['document'] as Map<String, dynamic>;
      final contents = await showFolderReceiptDialog(context, current);
      if (contents == null ||
          !mounted ||
          !currentSession() ||
          auth.loggingOut) {
        return;
      }
      final result = await api.recordMovement(
        documentId: id,
        officeId: user.officeId,
        status: 'IN',
        movementSource: 'system',
        expectedMovementId: (current['last_movement_id'] as num).toInt(),
        receiptConfirmed: true,
        contentsReceipt: contents,
        remarks: 'Received at ${user.officeName}',
      );
      if (!mounted || !currentSession()) return;
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['message']?.toString() ??
                '$id received at ${user.officeName}',
          ),
          backgroundColor: SfColors.green,
        ),
      );
      await _load();
    } on ApiException catch (e) {
      if (mounted && currentSession()) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: SfColors.red),
        );
      }
    } finally {
      if (currentSession()) setState(() => _markingInDocId = null);
    }
  }

  Future<void> _markOut(String documentId, {String? documentType}) async {
    if (_markingOutDocId != null) return;
    final auth = context.read<AuthProvider>();
    final user = auth.user!;
    final api = auth.api;
    final identity = auth.sessionIdentity;
    bool currentSession() => mounted && auth.sessionIdentity == identity;
    if (auth.loggingOut) return;
    setState(() => _markingOutDocId = documentId);
    try {
      final shown = await api.officeDocuments(id: documentId);
      if (!mounted || !currentSession()) return;
      final current = Map<String, dynamic>.from(shown['document'] as Map);
      if (current['current_status'] != 'IN' ||
          current['current_office_id'] != user.officeId ||
          (current['tray'] == 'completed' &&
              current['can_return_to_accounting'] != true)) {
        throw ApiException(
          'This folder changed. Open Documents and review its current custody before sending.',
        );
      }
      final suggested = current['suggested_forward'] as Map?;
      final destination = await showMarkOutDestinationDialog(
        context,
        documentId: documentId,
        myOfficeId: user.officeId,
        myOfficeName: user.officeName,
        myOfficeCode: user.officeCode,
        documentType: current['type']?.toString() ?? documentType,
        suggestedOfficeId: (suggested?['office_id'] as num?)?.toInt(),
        suggestedOfficeCode: suggested?['office_code']?.toString(),
        suggestedReason: suggested?['reason']?.toString(),
        onlyDestinationCode: current['can_return_to_accounting'] == true
            ? 'ACC'
            : null,
      );
      if (destination == null ||
          !mounted ||
          !currentSession() ||
          auth.loggingOut) {
        return;
      }
      await api.recordMovement(
        documentId: documentId,
        officeId: user.officeId,
        status: 'OUT',
        movementSource: 'system',
        expectedMovementId: (current['last_movement_id'] as num).toInt(),
        destinationOfficeId: destination.officeId,
        isReturn: destination.isReturn,
        remarks: destination.isReturn
            ? destination.returnReason
            : 'Forwarded from ${user.officeName} → ${destination.code}',
      );
      if (!mounted || !currentSession()) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            destination.isReturn
                ? '$documentId returned to ${destination.code}'
                : '$documentId marked OUT',
          ),
          backgroundColor: SfColors.blue,
        ),
      );
      await _load();
    } on ApiException catch (e) {
      if (mounted && currentSession()) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: SfColors.red),
        );
      }
    } finally {
      if (currentSession()) setState(() => _markingOutDocId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _stats;
    final dash = s == null && !_loading ? null : s;
    final inFlow = dash == null ? '—' : '${dash['in_flow']}';
    final outFlow = dash == null ? '—' : '${dash['out_flow']}';
    final tags = dash == null ? '—' : '${dash['active_tags']}';

    return RefreshIndicator(
      onRefresh: _load,
      color: SfColors.blue,
      child: ListView(
        controller: _scrollCtrl,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 32),
        children: [
          const SfPageTitle(
            title: 'Dashboard',
            subtitle: 'Manage your office’s physical folders.',
          ),
          const SizedBox(height: 16),
          if (_error != null) ...[
            SfErrorBanner(
              message: _stats == null
                  ? _error!
                  : 'Refresh failed. Previously loaded folders and counts may be stale. $_error',
            ),
            const SizedBox(height: 10),
          ],
          HomeFolderActions(
            overview: _loading
                ? const SfDashboardStatSkeleton()
                : SfDashboardStatRow(
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
          ),
          const SizedBox(height: 4),
          SfClerkSectionHeader(
            key: _activeSectionKey,
            title: 'At your office',
            link: _stats == null
                ? null
                : _activeDocs.isEmpty
                ? '0 folders'
                : '${_activeDocs.length} folder${_activeDocs.length == 1 ? '' : 's'}',
          ),
          const SizedBox(height: 8),
          if (_stats == null && _loading)
            const _HomeFolderLoading()
          else if (_stats == null && _error != null)
            const SfEmptyState(
              icon: SfIcons.documents,
              title: 'Folder list unavailable',
              subtitle: 'Pull to refresh to try again.',
            )
          else if (_activeDocs.isEmpty)
            _HomeFolderEmpty(
              quiet: _error == null,
              icon: Icons.inventory_2_outlined,
              title: _error == null
                  ? 'No folders at your office'
                  : 'No folders in the last loaded list',
              message: _error == null
                  ? 'Folders held by your office appear here.'
                  : 'Pull to refresh to check current custody.',
            )
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
                    '/staff/documents?id=${Uri.encodeQueryComponent(id)}',
                  ),
                  onMarkOut: () =>
                      _markOut(id, documentType: m['type']?.toString()),
                ),
              );
            }),
          const SizedBox(height: 16),
          SfClerkSectionHeader(
            title: 'Incoming',
            link: _stats == null
                ? null
                : '${_inTransit.length} folder${_inTransit.length == 1 ? '' : 's'}',
          ),
          const SizedBox(height: 8),
          if (_stats == null && _loading)
            const _HomeFolderLoading()
          else if (_stats == null && _error != null)
            const SfEmptyState(
              icon: Icons.move_to_inbox_outlined,
              title: 'Incoming list unavailable',
              subtitle: 'Pull to refresh to try again.',
            )
          else if (_inTransit.isEmpty)
            _HomeFolderEmpty(
              quiet: _error == null,
              icon: Icons.move_to_inbox_outlined,
              title: _error == null
                  ? 'No incoming folders'
                  : 'No folders in the last loaded list',
              message: _error == null
                  ? 'Sent folders appear here until received.'
                  : 'Pull to refresh to check incoming folders.',
            )
          else
            ..._inTransit.map((d) {
              final m = d as Map<String, dynamic>;
              final id = m['document_id']?.toString() ?? '';
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SfClerkIncomingDocRow(
                  documentId: id,
                  title: m['title']?.toString() ?? m['type']?.toString() ?? '',
                  fromOfficeCode: m['last_office_code']?.toString() ?? '—',
                  fromOfficeName: m['last_office_name']?.toString() ?? '',
                  sentToOfficeCode: m['destination_office_code']?.toString(),
                  outAt: m['last_scanned_at']?.toString(),
                  receiving: _markingInDocId == id,
                  onTap: () => context.push(
                    '/staff/documents?id=${Uri.encodeQueryComponent(id)}',
                  ),
                  onMarkIn: () => _markInIncoming(m),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      SfStatusPill(
                        label: st == 'OUT' ? 'SENT' : 'IN',
                        tone: st == 'IN'
                            ? SfPillTone.success
                            : SfPillTone.neutral,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title != null && title.isNotEmpty
                                  ? title
                                  : m['document_id']?.toString() ?? '',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            if (title != null && title.isNotEmpty)
                              Text(
                                m['document_id']?.toString() ?? '',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: SfColors.muted,
                                ),
                              ),
                            Text(
                              movementScanSubtitle(m),
                              style: const TextStyle(
                                fontSize: 11,
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
              '${_error == null ? 'Updated' : 'Last successful update'} ${formatSmartflowTime(_lastLoaded!.toIso8601String())} · pull to refresh',
              textAlign: TextAlign.start,
              style: const TextStyle(fontSize: 11, color: SfColors.muted),
            ),
          ],
        ],
      ),
    );
  }
}

class _HomeFolderEmpty extends StatelessWidget {
  const _HomeFolderEmpty({
    required this.quiet,
    required this.icon,
    required this.title,
    required this.message,
  });

  final bool quiet;
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: SfColors.muted),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                  color: quiet ? SfColors.muted : SfColors.ink,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                message,
                style: const TextStyle(
                  fontSize: 12,
                  color: SfColors.muted,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
    return quiet
        ? Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: content,
          )
        : SfFormCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: content,
          );
  }
}

class _HomeFolderLoading extends StatelessWidget {
  const _HomeFolderLoading();

  @override
  Widget build(BuildContext context) => const SfFormCard(
    padding: EdgeInsets.all(20),
    child: Center(
      child: SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    ),
  );
}

class StaffAlertsScreen extends StatefulWidget {
  const StaffAlertsScreen({super.key, this.municipal = false});

  /// Municipal accountant: alerts across offices, not one desk.
  final bool municipal;

  @override
  State<StaffAlertsScreen> createState() => _StaffAlertsScreenState();
}

class _StaffAlertsScreenState extends State<StaffAlertsScreen>
    with LiveRefresh<StaffAlertsScreen> {
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

  Future<void> _syncAlertBadge() async {
    final count = await AlertActionsStore.visibleCount(_alerts);
    if (mounted) {
      context.findAncestorStateOfType<_StaffShellState>()?.refreshAlertBadge(
        count,
      );
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
          content: const Text(
            'Hidden until tomorrow. Undo if you still need it.',
          ),
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
      final data = widget.municipal
          ? await context.read<AuthProvider>().api.accountantAlerts()
          : await context.read<AuthProvider>().api.alerts(oid);
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
    final role = widget.municipal ? 'admin' : 'staff';
    context.push('/$role/documents?id=${Uri.encodeQueryComponent(docId)}');
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
    final docTitle = _compactText(m['document_title']);
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
    final title = docTitle.isNotEmpty
        ? docTitle
        : (docId.isNotEmpty ? docId : 'Document alert');
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
      SfAlertFilter.unconfirmed => 'Receipt not recorded',
    };

    return RefreshIndicator(
      onRefresh: _load,
      color: SfColors.blue,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
        children: [
          const SfAuthenticatedPageHeader(),
          const SizedBox(height: 4),
          SfPageTitle(
            title: 'Alerts',
            subtitle: widget.municipal
                ? 'Review delays and missing receipts across municipal offices.'
                : 'Review folders that need your office’s attention.',
          ),
          const SizedBox(height: 14),
          if (_error != null) ...[
            SfErrorBanner(
              message: _lastLoaded == null
                  ? 'Alerts unavailable. $_error'
                  : 'Refresh failed. Previously loaded alerts may be stale. $_error',
            ),
            TextButton(onPressed: _load, child: const Text('Retry')),
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
                  '${_error == null ? 'Updated' : 'Last successful update'} ${formatSmartflowTime(_lastLoaded!.toIso8601String())} · pull to refresh',
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
                        onPressed: () =>
                            setState(() => _filter = SfAlertFilter.all),
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
                                onPressed: () =>
                                    setState(() => _filter = SfAlertFilter.all),
                                icon: const Icon(Icons.tune_rounded, size: 16),
                                label: const Text('Show all'),
                              ),
                            ),
                          if (_filter != SfAlertFilter.all)
                            const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => context.go(
                                widget.municipal
                                    ? '/admin/history'
                                    : '/staff/history',
                              ),
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
  late final AuthProvider _auth;
  late final Object _identity;
  late final SmartflowApi _api;
  bool get _current => mounted && _auth.sessionIdentity == _identity;
  int _documentGeneration = 0;

  List<dynamic> _movements = [];
  List<dynamic> _todayScans = [];
  List<RecentDocRef> _recentIds = const [];
  Map<String, dynamic>? _document;
  String? _loadedId;
  String? _error;
  bool _loading = false;
  bool _activityLoading = true;
  String? _activityError;
  DateTime _activityDate = DateUtils.dateOnly(DateTime.now());
  int _activityPage = 1;
  int _activityGeneration = 0;
  Map<String, dynamic> _activityMeta = {};
  _MovementFilter _movementFilter = _MovementFilter.all;
  late StaffTodayScanFilter _todayScanFilter;
  late bool _officeActivityView;

  int get _countTodayIn =>
      ((_activityMeta['stats'] as Map?)?['in_flow'] as num?)?.toInt() ?? 0;

  int get _countTodayOut =>
      ((_activityMeta['stats'] as Map?)?['out_flow'] as num?)?.toInt() ?? 0;

  String get _activityDateValue =>
      '${_activityDate.year}-${_activityDate.month.toString().padLeft(2, '0')}-${_activityDate.day.toString().padLeft(2, '0')}';

  int get _countIn => _movements
      .where((m) => (m as Map)['status']?.toString().toUpperCase() == 'IN')
      .length;

  int get _countOut => _movements
      .where((m) => (m as Map)['status']?.toString().toUpperCase() == 'OUT')
      .length;

  @override
  void initState() {
    super.initState();
    _auth = context.read<AuthProvider>();
    _identity = _auth.sessionIdentity;
    _api = _auth.api;
    _officeActivityView = widget.initialTodayFilter != null;
    _todayScanFilter = StaffHistoryScreen.parseTodayFilter(
      widget.initialTodayFilter,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_current) return;
      _loadOfficeActivity();
      _loadRecents();
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

  Future<void> _loadOfficeActivity() async {
    if (!_current || _auth.loggingOut) return;
    final generation = ++_activityGeneration;
    setState(() => _activityLoading = true);
    try {
      final data = await _api.officeMovements(
        _auth.user!.officeId,
        date: _activityDateValue,
        status: switch (_todayScanFilter) {
          StaffTodayScanFilter.received => 'IN',
          StaffTodayScanFilter.sent => 'OUT',
          StaffTodayScanFilter.all => null,
        },
        page: _activityPage,
      );
      if (!_current || generation != _activityGeneration) return;
      setState(() {
        _todayScans = data['movements'] as List<dynamic>? ?? [];
        _activityMeta = data;
        _activityError = null;
        _activityLoading = false;
      });
      if (widget.initialTodayFilter != null) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _scrollToTodaySection(),
        );
      }
    } catch (e) {
      if (_current && generation == _activityGeneration) {
        setState(() {
          _activityError = apiErrorMessage(e);
          _activityLoading = false;
        });
      }
    }
  }

  void _changeActivityFilter(StaffTodayScanFilter filter) {
    setState(() {
      _todayScanFilter = filter;
      _activityPage = 1;
    });
    _loadOfficeActivity();
  }

  Future<void> _pickActivityDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _activityDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    setState(() {
      _activityDate = date;
      _activityPage = 1;
    });
    await _loadOfficeActivity();
  }

  Future<void> _loadRecents() async {
    final generation = _documentGeneration;
    final docs = await RecentDocsStore.load();
    if (_current && generation == _documentGeneration) {
      setState(() => _recentIds = docs);
    }
  }

  Future<void> _pasteLookup() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty) {
      if (mounted) setState(() => _error = 'Clipboard is empty.');
      return;
    }
    if (parseTrackingId(text) == null) {
      _lookupCtrl.text = text;
      if (mounted) setState(() => _error = 'That is not a tracking ID.');
      return;
    }
    _openId(text);
  }

  Future<void> _refresh() async {
    await _loadOfficeActivity();
    if (_loadedId != null) {
      await _loadDocument(_loadedId!);
    }
  }

  Future<void> _loadDocument(String rawId) async {
    if (!_current || _auth.loggingOut) return;
    final parsed = parseTrackingId(rawId) ?? rawId.trim();
    if (parsed.isEmpty) return;
    final id = parsed;
    final generation = ++_documentGeneration;
    bool ownsLookup() => _current && generation == _documentGeneration;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final movData = await _api.documentMovements(id);
      if (!ownsLookup()) return;
      final docData = await _api.documentShow(id);
      if (!ownsLookup()) return;
      final document = docData['document'] as Map<String, dynamic>?;
      final updated = await RecentDocsStore.add(
        id,
        title: document?['title']?.toString(),
        isCurrent: ownsLookup,
      );
      if (!ownsLookup()) return;
      setState(() {
        _movements = movData['movements'] as List<dynamic>? ?? [];
        _document = document;
        _loadedId = id;
        _recentIds = updated;
        _loading = false;
      });
    } catch (e) {
      if (!ownsLookup()) return;
      setState(() {
        _error = apiErrorMessage(e);
        _movements = [];
        _document = null;
        _loadedId = null;
        _loading = false;
      });
    }
  }

  void _openId(String id) {
    if (!_current || _auth.loggingOut) return;
    final cleaned = parseTrackingId(id) ?? id.trim();
    if (cleaned.isEmpty) return;
    setState(() => _officeActivityView = false);
    _lookupCtrl.text = cleaned;
    _loadDocument(cleaned);
  }

  void _clearLoaded() {
    if (!_current) return;
    _documentGeneration++;
    setState(() {
      _movements = [];
      _document = null;
      _loadedId = null;
      _error = null;
      _loading = false;
      _movementFilter = _MovementFilter.all;
    });
  }

  bool get _showingTrail => _loadedId != null && _document != null;

  List<Widget> _custodyTrail(List<dynamic> scans) {
    final events = <_TrailEvent>[];
    if (_movementFilter == _MovementFilter.all) {
      final reg = _document?['registered_by'];
      if (reg is Map) {
        final name = reg['name']?.toString().trim() ?? '';
        final office = reg['office_name']?.toString().trim() ?? '';
        if (name.isNotEmpty) {
          events.add(
            _TrailEvent(
              at: parseSmartflowDateTime(reg['registered_at']?.toString()),
              rank: 0,
              title: office.isEmpty ? 'Registered' : 'Registered at $office',
              personName: name,
              avatarUrl: reg['avatar_url']?.toString(),
              dotColor: SfColors.navy,
            ),
          );
        }
      }
      final reqs = _document?['linked_requests'];
      if (reqs is List) {
        for (final raw in reqs) {
          if (raw is! Map) continue;
          final name = raw['user_name']?.toString().trim() ?? '';
          if (name.isEmpty) continue;
          final purpose = raw['purpose']?.toString().trim() ?? '';
          final office = raw['office_name']?.toString().trim() ?? '';
          events.add(
            _TrailEvent(
              at: parseSmartflowDateTime(raw['created_at']?.toString()),
              rank: 1,
              title: purpose.isEmpty ? 'Request' : purpose,
              personName: name,
              personDetail: office.isEmpty ? null : office,
              avatarUrl: raw['avatar_url']?.toString(),
              dotColor: SfColors.gold,
            ),
          );
        }
      }
    }

    for (final raw in scans) {
      final row = raw as Map;
      final status = row['status']?.toString().toUpperCase() ?? '';
      final isIn = status == 'IN';
      final office = row['office_name']?.toString().trim() ?? '';
      final dest = row['destination_office_name']?.toString().trim() ?? '';
      final remarks = row['remarks']?.toString().trim() ?? '';
      final named = row['user_name']?.toString().trim() ?? '';
      final username = row['username']?.toString().trim() ?? '';
      events.add(
        _TrailEvent(
          at: parseSmartflowDateTime(row['scanned_at']?.toString()),
          rank: 2,
          title: isIn
              ? 'Received at ${office.isEmpty ? 'office' : office}'
              : (dest.isNotEmpty
                    ? 'Sent to $dest'
                    : 'Sent from ${office.isEmpty ? 'office' : office}'),
          personName: named.isNotEmpty ? named : username,
          avatarUrl: row['avatar_url']?.toString(),
          note: remarks.isEmpty ? null : remarks,
          showReceipt: isIn,
          receipt: row['contents_receipt'] == null
              ? null
              : Map<String, dynamic>.from(row['contents_receipt'] as Map),
          dotColor: isIn ? SfColors.green : SfColors.blue,
        ),
      );
      for (final correction in row['destination_corrections'] as List? ?? []) {
        events.add(
          _TrailEvent(
            at: parseSmartflowDateTime(correction['corrected_at']?.toString()),
            rank: 3,
            title:
                'Destination corrected: ${correction['previous_destination_office_name']} → ${correction['destination_office_name']}',
            personName: '${correction['corrected_by_name'] ?? ''}',
            personDetail: correction['corrected_by_office_name']?.toString(),
            note: correction['reason']?.toString(),
            dotColor: SfColors.gold,
          ),
        );
      }
    }

    if (_movementFilter == _MovementFilter.all) {
      final filed = _document?['filed_by'];
      if (filed is Map &&
          (filed['filed_at']?.toString().trim() ?? '').isNotEmpty) {
        final office = filed['office_name']?.toString().trim() ?? '';
        final name = filed['name']?.toString().trim() ?? '';
        // Filing is its own recorded event, not another scan or a derived route completion.
        events.add(
          _TrailEvent(
            at: parseSmartflowDateTime(filed['filed_at']?.toString()),
            rank: 4,
            title: office.isEmpty ? 'Filed' : 'Filed at $office',
            personName: name.isEmpty ? 'Staff (name not recorded)' : name,
            avatarUrl: filed['avatar_url']?.toString(),
            note: 'Folder filed. The route is finished.',
            dotColor: SfColors.green,
          ),
        );
      }
    }

    events.sort((a, b) {
      final aAt = a.at;
      final bAt = b.at;
      if (aAt == null && bAt == null) return a.rank.compareTo(b.rank);
      if (aAt == null) return -1;
      if (bAt == null) return 1;
      final byTime = aAt.compareTo(bAt);
      if (byTime != 0) return byTime;
      return a.rank.compareTo(b.rank);
    });

    final widgets = <Widget>[];
    String? lastDay;
    for (var i = 0; i < events.length; i++) {
      final event = events[i];
      final at = event.at;
      if (at != null) {
        final day = formatTrailDay(at);
        if (day != lastDay) {
          lastDay = day;
          widgets.add(
            Padding(
              padding: EdgeInsets.only(
                left: 22,
                bottom: 8,
                top: widgets.isEmpty ? 0 : 4,
              ),
              child: Text(
                day,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: SfColors.muted,
                ),
              ),
            ),
          );
        }
      }
      widgets.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SfTrailStop(
              title: event.title,
              personName: event.personName.isEmpty ? 'Staff' : event.personName,
              personDetail: event.personDetail,
              avatarUrl: event.avatarUrl,
              when: at == null ? '—' : formatTrailClock(at),
              note: event.note,
              dotColor: event.dotColor,
              isLast: i == events.length - 1,
            ),
            if (event.showReceipt)
              Padding(
                padding: const EdgeInsets.only(left: 22, bottom: 16),
                child: FolderReceiptSummary(receipt: event.receipt),
              ),
          ],
        ),
      );
    }
    return widgets;
  }

  List<Widget> _browsePickList(BuildContext context) {
    final total =
        (_activityMeta['total'] as num?)?.toInt() ?? _todayScans.length;
    final page = (_activityMeta['page'] as num?)?.toInt() ?? _activityPage;
    final pageSize = (_activityMeta['page_size'] as num?)?.toInt() ?? 25;
    return [
      SfClerkSectionHeader(key: _todaySectionKey, title: 'Office activity'),
      const SizedBox(height: 8),
      Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          onPressed: _activityLoading ? null : _pickActivityDate,
          icon: const Icon(Icons.calendar_today_outlined, size: 18),
          label: Text(_activityDateValue),
        ),
      ),
      const SizedBox(height: 8),
      if (!_activityLoading && _activityError == null)
        _TodayScanFilterChips(
          countAll:
              ((_activityMeta['stats'] as Map?)?['total'] as num?)?.toInt() ??
              0,
          countIn: _countTodayIn,
          countOut: _countTodayOut,
          selected: _todayScanFilter,
          onSelected: _changeActivityFilter,
        ),
      const SizedBox(height: 10),
      if (_activityLoading)
        const SfLoadingCard()
      else if (_activityError != null) ...[
        SfErrorBanner(message: _activityError!),
        TextButton(
          onPressed: _loadOfficeActivity,
          child: const Text('Try again'),
        ),
      ] else if (_todayScans.isEmpty)
        SfEmptyState(
          icon: Icons.history_rounded,
          title: 'No office activity in this filter',
          subtitle:
              'No matching movements on $_activityDateValue. Choose another date or All.',
        )
      else ...[
        Text(
          '$total ${total == 1 ? 'movement' : 'movements'}',
          style: const TextStyle(color: SfColors.muted, fontSize: 12),
        ),
        const SizedBox(height: 8),
        ..._todayScans.map(_todayMovementCard),
        if (total > pageSize) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton(
                onPressed: page <= 1
                    ? null
                    : () {
                        setState(() => _activityPage = page - 1);
                        _loadOfficeActivity();
                      },
                child: const Text('Previous'),
              ),
              Text('Page $page of ${(total / pageSize).ceil()}'),
              OutlinedButton(
                onPressed: _activityMeta['has_more'] != true
                    ? null
                    : () {
                        setState(() => _activityPage = page + 1);
                        _loadOfficeActivity();
                      },
                child: const Text('Next'),
              ),
            ],
          ),
        ],
      ],
    ];
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
    final scans = _movements.where((row) {
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
    final trail = _custodyTrail(scans);

    return RefreshIndicator(
      onRefresh: _refresh,
      color: SfColors.blue,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
        children: [
          const SfAuthenticatedPageHeader(),
          const SizedBox(height: 4),
          const SfPageTitle(
            title: 'History',
            subtitle:
                'See one folder’s history or your office’s daily activity.',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Folder history'),
                selected: !_officeActivityView,
                showCheckmark: false,
                onSelected: (_) => setState(() => _officeActivityView = false),
              ),
              ChoiceChip(
                label: const Text('Office activity'),
                selected: _officeActivityView,
                showCheckmark: false,
                onSelected: (_) => setState(() => _officeActivityView = true),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!_officeActivityView && _showingTrail)
            Wrap(
              spacing: 12,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  _loadedId ?? '',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: SfColors.ink,
                  ),
                ),
                TextButton(
                  onPressed: _clearLoaded,
                  child: const Text('Look up another'),
                ),
              ],
            )
          else if (!_officeActivityView)
            _HistoryLookupCard(
              controller: _lookupCtrl,
              loading: _loading,
              recents: _recentIds,
              onLookup: () => _openId(_lookupCtrl.text),
              onPaste: _pasteLookup,
              onOpenRecent: _openId,
              onClearRecents: () async {
                if (!_current || _auth.loggingOut) return;
                _documentGeneration++;
                await RecentDocsStore.clear();
                if (_current) setState(() => _recentIds = const []);
              },
            ),
          if (!_officeActivityView && _error != null) ...[
            const SizedBox(height: 12),
            SfErrorBanner(message: _error!),
            TextButton(
              onPressed: _loading ? null : () => _openId(_lookupCtrl.text),
              child: const Text('Retry'),
            ),
          ],

          // ── Trail mode: one document ─────────────────────────────────
          if (!_officeActivityView && _showingTrail) ...[
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
              onOpenScan: widget.monitorOnly
                  ? null
                  : () => context.go('/staff/scan'),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Folder history',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                ),
                const SizedBox(width: 8),
                if (_movements.isNotEmpty)
                  Text(
                    '${scans.length} of ${_movements.length}',
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
            else if (scans.isEmpty &&
                _movements.isNotEmpty &&
                _movementFilter != _MovementFilter.all)
              SfEmptyState(
                icon: Icons.filter_list_off_outlined,
                title: 'No matching scans',
                subtitle:
                    'No ${_movementFilter == _MovementFilter.inOnly ? 'received' : 'sent'} events — try All.',
                actionLabel: 'Show all',
                onAction: () =>
                    setState(() => _movementFilter = _MovementFilter.all),
              )
            else if (trail.isEmpty)
              SfEmptyState(
                icon: SfIcons.timeline,
                title: _loadedId == null
                    ? 'No scans yet'
                    : 'No movements for this ID',
                subtitle: _loadedId == null
                    ? 'Enter a tracking ID to see the custody trail.'
                    : 'No movements for this ID.',
                actionLabel: widget.monitorOnly ? null : 'Open Scanner',
                onAction: widget.monitorOnly
                    ? null
                    : () => context.go('/staff/scan'),
              )
            else
              ...trail,
          ]
          // ── Browse mode: pick something to open ──────────────────────
          else if (_officeActivityView) ...[
            const SizedBox(height: 14),
            ..._browsePickList(context),
          ] else if (_loading)
            const SfLoadingCard()
          else if (_error == null)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Text(
                'Enter a tracking ID to see who registered, received and sent the folder.',
                style: TextStyle(color: SfColors.muted),
              ),
            ),
        ],
      ),
    );
  }
}

enum _MovementFilter { all, inOnly, outOnly }

class _TrailEvent {
  const _TrailEvent({
    required this.at,
    required this.rank,
    required this.title,
    required this.personName,
    required this.dotColor,
    this.avatarUrl,
    this.personDetail,
    this.note,
    this.showReceipt = false,
    this.receipt,
  });

  final DateTime? at;
  final int rank;
  final String title;
  final String personName;
  final Color dotColor;
  final String? avatarUrl;
  final String? personDetail;
  final String? note;
  final bool showReceipt;
  final Map<String, dynamic>? receipt;
}

class _HistoryLookupCard extends StatelessWidget {
  const _HistoryLookupCard({
    required this.controller,
    required this.loading,
    required this.recents,
    required this.onLookup,
    required this.onPaste,
    required this.onOpenRecent,
    required this.onClearRecents,
  });

  final TextEditingController controller;
  final bool loading;
  final List<RecentDocRef> recents;
  final VoidCallback onLookup;
  final VoidCallback onPaste;
  final ValueChanged<String> onOpenRecent;
  final VoidCallback onClearRecents;

  @override
  Widget build(BuildContext context) {
    return SfFormCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Tracking ID',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: SfColors.ink,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: loading ? null : onPaste,
                icon: const Icon(Icons.content_paste_rounded, size: 16),
                label: const Text('Paste'),
                style: TextButton.styleFrom(
                  foregroundColor: SfColors.blue,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 32),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
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
            label: loading ? 'Looking up…' : 'Look up document',
            loading: loading,
            onPressed: loading ? null : onLookup,
          ),
          if (recents.isNotEmpty) ...[
            const SizedBox(height: 14),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text(
                'Recently viewed',
                style: TextStyle(fontSize: 13),
              ),
              children: [
                SfQuickOpenChips(
                  docs: recents,
                  enabled: !loading,
                  onOpen: onOpenRecent,
                  onClear: onClearRecents,
                ),
              ],
            ),
          ],
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

// ─── Profile ────────────────────────────────────────────────────────────────

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
  String? _statsError;
  DateTime? _statsUpdated;
  int _statsRead = 0;
  bool _photoBusy = false;

  @override
  void initState() {
    super.initState();
    _loadDeskStats();
  }

  Future<void> _loadDeskStats() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated || auth.loggingOut) return;
    final api = auth.api;
    final identity = auth.sessionIdentity;
    final officeId = auth.user!.officeId;
    final read = ++_statsRead;
    bool current() =>
        mounted && read == _statsRead && auth.sessionIdentity == identity;
    setState(() => _statsLoading = true);
    try {
      final data = await api.dashboardStats(officeId);
      final stats = data['stats'] as Map<String, dynamic>? ?? {};
      if (!current()) return;
      setState(() {
        _inFlow = '${stats['in_flow'] ?? '—'}';
        _outFlow = '${stats['out_flow'] ?? '—'}';
        _activeTags = '${stats['active_tags'] ?? '—'}';
        _statsError = null;
        _statsUpdated = DateTime.now();
        _statsLoading = false;
      });
    } catch (e) {
      if (current()) {
        setState(() {
          _statsError = apiErrorMessage(e);
          _statsLoading = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    await sfLogout(context);
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
        padding: EdgeInsets.fromLTRB(18, 18, 18, 32 + bottomInset),
        children: [
          const SfAuthenticatedPageHeader(),
          if (isSecurity) ...[
            const SizedBox(height: 4),
            const SfPageTitle(
              title: 'Account & security',
              subtitle: 'Your account details, photo and sign-in settings.',
            ),
            const SizedBox(height: 14),
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
            const SizedBox(height: 4),
            const SfPageTitle(
              title: 'Profile',
              subtitle: 'Your municipal account and office activity.',
            ),
            const SizedBox(height: 14),
            ProfileSnapshotFeedback(
              updatedAt: _statsUpdated,
              error: _statsError,
              loading: _statsLoading,
              onRetry: _loadDeskStats,
            ),
            if (_statsLoading && _statsUpdated == null)
              const SfLoadingCard()
            else
              SfProfileAccountCard(
                user: user,
                inFlow: _inFlow,
                outFlow: _outFlow,
                activeTags: _activeTags,
              ),
            const SizedBox(height: 16),
            SfNavigationRow(
              icon: Icons.manage_accounts_outlined,
              title: 'Account & security',
              subtitle: 'Photo, account details, password and sign out',
              onTap: () =>
                  context.go(sfProfileRouteForRole(user.role, security: true)),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            'Municipality of Urbiztondo · Official document tracking · COA support',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
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
  String? _statsError;
  DateTime? _statsUpdated;
  int _statsRead = 0;
  bool _photoBusy = false;

  @override
  void initState() {
    super.initState();
    _loadOfficeStats();
  }

  Future<void> _loadOfficeStats() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated || auth.loggingOut) return;
    final api = auth.api;
    final identity = auth.sessionIdentity;
    final officeId = auth.user!.officeId;
    final read = ++_statsRead;
    bool current() =>
        mounted && read == _statsRead && auth.sessionIdentity == identity;
    setState(() => _statsLoading = true);
    try {
      final data = await api.headDashboard(officeId);
      final stats = data['stats'] as Map<String, dynamic>? ?? {};
      if (!current()) return;
      setState(() {
        _inOffice = '${stats['in_office'] ?? '—'}';
        _overdue = '${stats['overdue'] ?? '—'}';
        _avgHours = '${stats['avg_hours'] ?? '—'}h';
        _statsError = null;
        _statsUpdated = DateTime.now();
        _statsLoading = false;
      });
    } catch (e) {
      if (current()) {
        setState(() {
          _statsError = apiErrorMessage(e);
          _statsLoading = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    await sfLogout(context);
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
        padding: EdgeInsets.fromLTRB(18, 18, 18, 32 + bottomInset),
        children: [
          const SfAuthenticatedPageHeader(),
          if (isSecurity) ...[
            const SizedBox(height: 4),
            const SfPageTitle(
              title: 'Account & security',
              subtitle: 'Your account details, photo and sign-in settings.',
            ),
            const SizedBox(height: 14),
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
            const SizedBox(height: 4),
            const SfPageTitle(
              title: 'Profile',
              subtitle: 'Your municipal account and office overview.',
            ),
            const SizedBox(height: 14),
            ProfileSnapshotFeedback(
              updatedAt: _statsUpdated,
              error: _statsError,
              loading: _statsLoading,
              onRetry: _loadOfficeStats,
            ),
            if (_statsLoading && _statsUpdated == null)
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
            SfNavigationRow(
              icon: Icons.manage_accounts_outlined,
              title: 'Account & security',
              subtitle: 'Photo, account details, password and sign out',
              onTap: () =>
                  context.go(sfProfileRouteForRole(user.role, security: true)),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            'Municipality of Urbiztondo · Official document tracking · COA support',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
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
        SfPageTitle(title: 'Profile', subtitle: _roleSubtitle(user.role)),
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
                      style: const TextStyle(
                        color: SfColors.muted,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      '${user.officeName} · LGU Urbiztondo',
                      style: const TextStyle(
                        color: SfColors.muted,
                        fontSize: 12,
                      ),
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
              MapEntry('Role', 'Department head · this office only'),
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
            await sfLogout(context);
          },
        ),
      ],
    );
  }
}
