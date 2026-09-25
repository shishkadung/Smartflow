import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_client.dart';
import '../../theme/sf_icons.dart';
import '../../theme/smartflow_theme.dart';
import '../shared/change_password_sheet.dart';
import '../shared/edit_profile_sheet.dart';
import '../shared/profile_photo.dart';
import '../../widgets/sf_help.dart';
import '../../widgets/sf_page.dart';
import '../../utils/api_error.dart';
import '../../widgets/sf_widgets.dart';
import '../staff/clerk_widgets.dart';
import 'admin_widgets.dart';

// ─── Shell ───────────────────────────────────────────────────────────────────

class AdminShell extends StatefulWidget {
  const AdminShell({super.key, required this.child});

  final Widget child;

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _pendingSignups = 0;

  @override
  void initState() {
    super.initState();
    _loadPendingBadge();
  }

  Future<void> _loadPendingBadge() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated || auth.user!.role != 'admin') return;
    try {
      final dash = await auth.api.accountantDashboard();
      final n = (dash['stats']?['pending_signups'] as int?) ?? 0;
      if (mounted) refreshPendingBadge(n);
    } catch (_) {}
  }

  void refreshPendingBadge(int count) {
    if (mounted) setState(() => _pendingSignups = count);
  }

  static const _primaryTabs = [
    '/admin',
    '/admin/scan',
    '/admin/reports',
  ];

  static const _menuRoutes = [
    '/admin/users',
    '/admin/requests',
    '/admin/register',
    '/admin/alerts',
    '/admin/history',
    '/admin/offices',
    '/admin/thresholds',
    '/admin/qr-monitor',
    '/admin/system',
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
    _loadPendingBadge();
  }

  @override
  Widget build(BuildContext context) {
    final loc = GoRouterState.of(context).uri.path;
    final index = _indexForPath(loc);

    return SfNavBadgeScope(
      alertCount: 0,
      child: SfAppScaffold(
        currentIndex: index,
        onTab: _onTab,
        tabs: [
          const SfNavTab(
            icon: SfIcons.adminHome,
            activeIcon: SfIcons.adminHomeActive,
            label: 'Home',
          ),
          const SfNavTab(
            icon: SfIcons.clerkScan,
            activeIcon: SfIcons.clerkScanActive,
            label: 'Scan',
          ),
          const SfNavTab(
            icon: SfIcons.adminCoaSummary,
            activeIcon: SfIcons.adminCoaSummaryActive,
            label: 'COA',
            elevated: true,
          ),
          SfNavTab(
            icon: SfIcons.more,
            activeIcon: SfIcons.moreActive,
            label: 'Menu',
            badge: _pendingSignups > 0 ? _pendingSignups : null,
          ),
        ],
        body: widget.child,
      ),
    );
  }
}

// ─── Profile (public for router) ───────────────────────────────────────────

class AdminProfileView extends StatefulWidget {
  const AdminProfileView({super.key, required this.user});

  final AppUser user;

  @override
  State<AdminProfileView> createState() => _AdminProfileViewState();
}

class _AdminProfileViewState extends State<AdminProfileView> {
  String? _activeDocs;
  String? _overdue;
  String? _pending;
  bool? _apiOnline;
  bool _statsLoading = true;
  bool _photoBusy = false;

  @override
  void initState() {
    super.initState();
    _loadMunicipalStats();
  }

  Future<void> _loadMunicipalStats() async {
    try {
      final api = context.read<AuthProvider>().api;
      final data = await api.accountantDashboard();
      final stats = data['stats'] as Map<String, dynamic>? ?? {};
      bool? online;
      try {
        final status = await api.systemStatus();
        final st = status['status'] as Map<String, dynamic>?;
        online = st?['api']?.toString().startsWith('On') == true;
      } catch (_) {
        online = false;
      }
      if (!mounted) return;
      setState(() {
        _activeDocs = '${stats['active_documents'] ?? '—'}';
        _overdue = '${stats['overdue'] ?? '—'}';
        _pending = '${stats['pending_signups'] ?? '—'}';
        _apiOnline = online;
        _statsLoading = false;
      });
      final n = (stats['pending_signups'] as int?) ?? 0;
      context.findAncestorStateOfType<_AdminShellState>()?.refreshPendingBadge(n);
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
      onRefresh: _loadMunicipalStats,
      color: SfColors.blue,
      child: ListView(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 32 + bottomInset),
        children: [
          const SfAuthenticatedPageHeader(),
          const SizedBox(height: 12),
          SfAdminPageOverviewCard(
            screen: isSecurity
                ? SfAdminScreen.accountSecurity
                : SfAdminScreen.profile,
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
            if (_apiOnline != null) ...[
              SfAdminSystemStatusBanner(
                apiOnline: _apiOnline!,
                onTap: () => context.go('/admin/system'),
              ),
              const SizedBox(height: 14),
            ],
            if (_statsLoading)
              const SfLoadingCard()
            else
              SfProfileAccountCard(
                user: user,
                roleLabel:
                    'Municipal Accountant · ${user.officeName} (${user.officeCode})',
                deskSectionTitle: 'Municipal snapshot',
                stat1Label: 'Active docs',
                stat2Label: 'Overdue',
                stat3Label: 'Sign-ups',
                inFlow: _activeDocs,
                outFlow: _overdue,
                activeTags: _pending,
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

// ─── Home ───────────────────────────────────────────────────────────────────

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  Map<String, dynamic>? _dash;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) maybeShowSfRoleTip(context);
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<AuthProvider>().api;
      final dash = await api.accountantDashboard();
      if (!mounted) return;
      final pending = (dash['stats']?['pending_signups'] as int?) ?? 0;
      context.findAncestorStateOfType<_AdminShellState>()?.refreshPendingBadge(pending);
      setState(() {
        _dash = dash;
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

  @override
  Widget build(BuildContext context) {
    final stats = _dash?['stats'] as Map<String, dynamic>?;
    final offices = _dash?['office_totals'] as List<dynamic>? ?? [];
    final month = _dash?['month']?.toString();
    final pending = (stats?['pending_signups'] as int?) ?? 0;
    final active = (stats?['active_documents'] as int?) ?? 0;
    final overdue = (stats?['overdue'] as int?) ?? 0;
    final pilotOffices = (stats?['pilot_offices'] as int?) ?? offices.length;

    return RefreshIndicator(
      onRefresh: _load,
      color: SfColors.blue,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          const SfAuthenticatedPageHeader(),
          const SizedBox(height: 12),
          SfAdminPageOverviewCard(
            screen: SfAdminScreen.home,
            pendingSignups: pending,
          ),
          const SizedBox(height: 12),
          if (pending > 0) ...[
            SfAdminStartHereCard(pendingSignups: pending),
            const SizedBox(height: 12),
          ],
          if (_error != null) ...[
            SfErrorBanner(message: _error!),
            const SizedBox(height: 12),
          ],
          if (month != null && month.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '$month · $pilotOffices office${pilotOffices == 1 ? '' : 's'}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: SfColors.muted,
              ),
            ),
          ],
          if (_loading) ...[
            const SizedBox(height: 12),
            const SfLoadingCard(),
          ] else if (stats != null) ...[
            const SizedBox(height: 12),
            SfAdminStatRow(
              activeDocs: active,
              overdue: overdue,
              pendingSignups: pending,
              onActiveDocsTap: () => context.go('/admin/offices'),
              onOverdueTap: () => context.go('/admin/offices'),
              onPendingTap: () => context.go('/admin/users'),
            ),
          ],
          if (!_loading && offices.isNotEmpty) ...[
            const SizedBox(height: 20),
            SfClerkSectionHeader(
              title: 'By office',
              link: 'All offices',
              onLinkTap: () => context.go('/admin/offices'),
            ),
            const SizedBox(height: 8),
            ...offices.map((o) {
              final m = o as Map<String, dynamic>;
              return SfAdminOfficeHealthTile(
                name: m['office_name']?.toString() ?? '',
                code: m['office_code']?.toString() ?? '',
                docsProcessed: (m['docs_processed'] as int?) ?? 0,
                inOffice: (m['in_office'] as int?) ?? 0,
                overdue: (m['overdue'] as int?) ?? 0,
                onTap: () => context.go('/admin/offices'),
              );
            }),
          ] else if (!_loading && _error == null && offices.isEmpty) ...[
            const SizedBox(height: 16),
            const SfEmptyState(
              icon: Icons.domain_outlined,
              title: 'No office activity yet',
              subtitle: 'Counts appear after an IN or OUT scan.',
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Users ──────────────────────────────────────────────────────────────────

enum _AdminUserFilter { all, pending, active }

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _pending = [];
  String _search = '';
  _AdminUserFilter _filter = _AdminUserFilter.all;
  String? _error;
  bool _loading = true;

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
      final api = context.read<AuthProvider>().api;
      final users = await api.usersList();
      final pending = await api.signupPending();
      if (!mounted) return;
      final pCount = (pending['pending'] as List<dynamic>? ?? []).length;
      context.findAncestorStateOfType<_AdminShellState>()?.refreshPendingBadge(pCount);
      setState(() {
        _users = (users['users'] as List<dynamic>? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _pending = (pending['pending'] as List<dynamic>? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
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

  Future<void> _approve(int id, String action) async {
    final label = action == 'approve' ? 'Approve' : 'Reject';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$label sign-up?'),
        content: Text(
          action == 'approve'
              ? 'This will create an active account with the requested role and office.'
              : 'The request will be marked rejected.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(label),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await context.read<AuthProvider>().api.signupApprove(id, action);
      if (!mounted) return;
      sfShowSuccessSnack(
        context,
        message: action == 'approve'
            ? 'Sign-up approved — account is active'
            : 'Sign-up rejected',
        backgroundColor:
            action == 'approve' ? SfColors.green : SfColors.gold,
      );
      await _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: SfColors.red),
        );
      }
    }
  }

  bool _matchesSearch(Map<String, dynamic> m) {
    if (_search.isEmpty) return true;
    final q = _search.toLowerCase();
    return (m['username']?.toString().toLowerCase().contains(q) ?? false) ||
        (m['office_name']?.toString().toLowerCase().contains(q) ?? false) ||
        (m['role']?.toString().toLowerCase().contains(q) ?? false);
  }

  @override
  Widget build(BuildContext context) {
    final showPending = _filter == _AdminUserFilter.all ||
        _filter == _AdminUserFilter.pending;
    final showActive = _filter == _AdminUserFilter.all ||
        _filter == _AdminUserFilter.active;
    final filteredPending =
        _pending.where(_matchesSearch).toList(growable: false);
    final filteredUsers = _users.where((m) {
      if (!_matchesSearch(m)) return false;
      if (_filter == _AdminUserFilter.active) {
        return m['is_active'] as bool? ?? true;
      }
      return true;
    }).toList(growable: false);

    return RefreshIndicator(
      onRefresh: _load,
      color: SfColors.blue,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          const SfAuthenticatedPageHeader(),
          const SizedBox(height: 12),
          SfAdminPageOverviewCard(
            screen: SfAdminScreen.users,
            pendingSignups: _pending.length,
            compact: true,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            SfErrorBanner(message: _error!),
          ],
          const SizedBox(height: 12),
          SfFormCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search username, role, office…',
                border: InputBorder.none,
                prefixIcon: Icon(Icons.search_rounded, size: 20),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _search = v.trim()),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip('All', _AdminUserFilter.all),
                const SizedBox(width: 8),
                _filterChip(
                  'Pending (${_pending.length})',
                  _AdminUserFilter.pending,
                ),
                const SizedBox(width: 8),
                _filterChip('Active', _AdminUserFilter.active),
              ],
            ),
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: SfLoadingCard(),
            )
          else ...[
            if (showPending && filteredPending.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Pending sign-up · ${filteredPending.length}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: SfColors.navy,
                ),
              ),
              const SizedBox(height: 8),
              ...filteredPending.map(
                (p) => SfAdminPendingSignupCard(
                  request: p,
                  onApprove: () => _approve(p['id'] as int, 'approve'),
                  onReject: () => _approve(p['id'] as int, 'reject'),
                ),
              ),
            ],
            if (showPending &&
                _filter != _AdminUserFilter.active &&
                filteredPending.isEmpty &&
                _pending.isNotEmpty &&
                _search.isNotEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: SfEmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'No pending match',
                  subtitle: 'Try a different search term.',
                ),
              ),
            if (showActive) ...[
              const SizedBox(height: 16),
              Text(
                'Directory · ${filteredUsers.length}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: SfColors.navy,
                ),
              ),
              const SizedBox(height: 8),
              if (filteredUsers.isEmpty)
                const SfEmptyState(
                  icon: Icons.people_outline_rounded,
                  title: 'No users found',
                  subtitle: 'Adjust filters or search.',
                )
              else
                ...filteredUsers.map((m) => SfAdminUserCard(user: m)),
            ],
          ],
        ],
      ),
    );
  }

  Widget _filterChip(String label, _AdminUserFilter value) {
    final selected = _filter == value;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _filter = value),
      selectedColor: SfColors.navy.withValues(alpha: 0.12),
      checkmarkColor: SfColors.navy,
      labelStyle: TextStyle(
        fontSize: 11,
        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
        color: selected ? SfColors.navy : SfColors.ink,
      ),
    );
  }
}

// ─── Offices ────────────────────────────────────────────────────────────────

class AdminOfficesScreen extends StatefulWidget {
  const AdminOfficesScreen({super.key});

  @override
  State<AdminOfficesScreen> createState() => _AdminOfficesScreenState();
}

class _AdminOfficesScreenState extends State<AdminOfficesScreen> {
  List<Map<String, dynamic>> _offices = [];
  String? _error;
  bool _loading = true;

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
      final data = await context.read<AuthProvider>().api.adminOffices();
      if (!mounted) return;
      setState(() {
        _offices = (data['offices'] as List<dynamic>? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
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

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      color: SfColors.blue,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          const SfAuthenticatedPageHeader(),
          const SizedBox(height: 12),
          const SfAdminPageOverviewCard(screen: SfAdminScreen.offices, compact: true),
          if (_error != null) ...[
            const SizedBox(height: 12),
            SfErrorBanner(message: _error!),
          ],
          const SizedBox(height: 12),
          SfPrimaryButton(
            label: 'Edit processing thresholds',
            onPressed: () => context.push('/admin/thresholds'),
          ),
          const SizedBox(height: 14),
          if (_loading)
            const SfLoadingCard()
          else if (_offices.isEmpty)
            const SfEmptyState(
              icon: Icons.business_rounded,
              title: 'No offices loaded',
              subtitle: 'Check API connection and refresh.',
            )
          else
            ..._offices.map((m) {
              final code = m['office_code']?.toString() ?? '';
              final name = m['office_name']?.toString() ?? '';
              final thresholds =
                  m['thresholds'] as List<dynamic>? ?? [];
              final threshText = thresholds.isEmpty
                  ? 'No thresholds configured'
                  : thresholds
                      .map((t) {
                        final th = t as Map<String, dynamic>;
                        return '${th['document_type']} · ${th['max_hours']} hours at this desk';
                      })
                      .join(' · ');
              final dept = SfColors.dept(code.isNotEmpty ? code : 'ENG');
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SfFormCard(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: dept.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          code.isNotEmpty ? code : '?',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: dept,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: SfColors.ink,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              threshText,
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: SfColors.muted,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SfStatusPill(
                        label: 'Active',
                        tone: SfPillTone.success,
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

// ─── System ─────────────────────────────────────────────────────────────────

class AdminSystemScreen extends StatefulWidget {
  const AdminSystemScreen({super.key});

  @override
  State<AdminSystemScreen> createState() => _AdminSystemScreenState();
}

class _AdminSystemScreenState extends State<AdminSystemScreen> {
  Map<String, dynamic>? _data;
  String? _error;
  bool _loading = true;
  DateTime? _lastLoaded;

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
      final data = await context.read<AuthProvider>().api.systemStatus();
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

  @override
  Widget build(BuildContext context) {
    final st = _data?['status'] as Map<String, dynamic>?;
    final ops = _data?['operations'] as Map<String, dynamic>?;
    final users = _data?['users'] as Map<String, dynamic>?;
    final apiOk = st?['api']?.toString().startsWith('On') == true;

    return RefreshIndicator(
      onRefresh: _load,
      color: SfColors.blue,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          const SfAuthenticatedPageHeader(),
          const SizedBox(height: 12),
          const SfAdminPageOverviewCard(screen: SfAdminScreen.system, compact: true),
          if (_error != null) ...[
            const SizedBox(height: 12),
            SfErrorBanner(message: _error!),
          ],
          const SizedBox(height: 12),
          if (_loading)
            const SfLoadingCard()
          else if (st != null) ...[
            SfFormCard(
              child: Row(
                children: [
                  Icon(
                    apiOk ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                    color: apiOk ? SfColors.green : SfColors.red,
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'API / PHP',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: SfColors.navy,
                          ),
                        ),
                        Text(
                          st['api']?.toString() ?? '',
                          style: const TextStyle(
                            fontSize: 12,
                            color: SfColors.muted,
                          ),
                        ),
                        Text(
                          st['php_version']?.toString() ?? '',
                          style: const TextStyle(
                            fontSize: 11,
                            color: SfColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SfStatusPill(
                    label: apiOk ? 'online' : 'offline',
                    tone: apiOk ? SfPillTone.success : SfPillTone.warning,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            SfFormCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'MySQL',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: SfColors.navy,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${st['mysql_version'] ?? ''} · ${st['documents'] ?? 0} documents in DB',
                    style: const TextStyle(fontSize: 12, color: SfColors.muted),
                  ),
                ],
              ),
            ),
            if (users != null) ...[
              const SizedBox(height: 10),
              SfFormCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Accounts on duty',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: SfColors.navy,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${users['clerks'] ?? 0} clerks · ${users['heads'] ?? 0} heads · ${users['accountants'] ?? 0} admin',
                      style: const TextStyle(fontSize: 12, color: SfColors.muted),
                    ),
                  ],
                ),
              ),
            ],
            if (ops != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  SfStatCard(
                    value: '${_data?['users']?['active'] ?? ops['pending_signups'] ?? 0}',
                    label: 'Active users',
                    color: SfColors.countInk(
                      _data?['users']?['active'] ?? ops['pending_signups'] ?? 0,
                      live: SfColors.blue,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SfStatCard(
                    value: '${ops['movements_today'] ?? 0}',
                    label: 'Scans today',
                    color: SfColors.countInk(ops['movements_today'] ?? 0, live: SfColors.green),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SfFormCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Flagged documents',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: SfColors.navy,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${ops['flagged_total'] ?? 0} total in system',
                      style: const TextStyle(fontSize: 12, color: SfColors.muted),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              sfAdminLastSyncLabel(_lastLoaded),
              style: const TextStyle(
                fontSize: 10,
                color: SfColors.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ] else if (!_loading && _error == null) ...[
            const SizedBox(height: 12),
            const SfEmptyState(
              icon: Icons.cloud_off_outlined,
              title: 'Status unavailable',
              subtitle:
                  'Could not read system status. Pull to refresh or check Apache/MySQL.',
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Reports ────────────────────────────────────────────────────────────────

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  Map<String, dynamic>? _report;
  String _month = DateFormat('yyyy-MM').format(DateTime.now());
  String? _error;
  bool _loading = true;
  List<Map<String, dynamic>> _exceptions = [];
  bool _loadingExceptions = false;

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
      final user = context.read<AuthProvider>().user!;
      final data = await context
          .read<AuthProvider>()
          .api
          .reportsSummary(user.officeId, _month);
      if (!mounted) return;
      setState(() {
        _report = data;
        _loading = false;
      });
      await _loadExceptions();
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

  Future<void> _loadExceptions() async {
    final user = context.read<AuthProvider>().user;
    if (user == null || user.officeCode.toUpperCase() != 'ACC') {
      return;
    }
    setState(() => _loadingExceptions = true);
    try {
      final data =
          await context.read<AuthProvider>().api.auditExceptions(hours: 24);
      if (!mounted) return;
      setState(() {
        _exceptions = (data['exceptions'] as List<dynamic>? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _loadingExceptions = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingExceptions = false);
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

  void _shareSummary() {
    final comp = _report?['compliance'] as Map<String, dynamic>?;
    final totals = _report?['totals'] as Map<String, dynamic>?;
    final monthLabel =
        _report?['month']?.toString() ?? _month;
    final onTime = (comp?['on_time']?['percent'] as num?)?.round() ?? 0;
    final unforwarded =
        (comp?['unforwarded']?['percent'] as num?)?.round() ?? 0;
    final delayed = (comp?['delayed']?['percent'] as num?)?.round() ?? 0;
    final docCount = totals?['documents_in_period'] ?? 0;
    final text = '''
SmartFlow · Municipality of Urbiztondo
COA Support Summary · $monthLabel (Municipality of Urbiztondo)

Documents with activity: $docCount
On time: $onTime%
Unforwarded: $unforwarded%
Delayed: $delayed%

Generated from SmartFlow mobile (admin / accountant view).
''';
    Clipboard.setData(ClipboardData(text: text.trim()));
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    sfShowSuccessSnack(
      context,
      message: 'Summary copied — paste into COA support notes',
      backgroundColor: SfColors.navy,
    );
  }

  @override
  Widget build(BuildContext context) {
    final comp = _report?['compliance'] as Map<String, dynamic>?;
    final offices = _report?['office_totals'] as List<dynamic>? ?? [];
    final totals = _report?['totals'] as Map<String, dynamic>?;
    final monthLabel = DateFormat('MMMM yyyy')
        .format(DateTime.parse('$_month-01'));
    final onTime = (comp?['on_time']?['percent'] as num?)?.round() ?? 0;
    final unforwarded =
        (comp?['unforwarded']?['percent'] as num?)?.round() ?? 0;
    final delayed = (comp?['delayed']?['percent'] as num?)?.round() ?? 0;
    final exportAllowed = _report?['export_allowed'] == true;
    final submissionNote =
        _report?['submission_note']?.toString() ?? '';

    return RefreshIndicator(
      onRefresh: _load,
      color: SfColors.blue,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          const SfAuthenticatedPageHeader(),
          const SizedBox(height: 12),
          const SfAdminPageOverviewCard(screen: SfAdminScreen.reports),
          if (_error != null) ...[
            const SizedBox(height: 12),
            SfErrorBanner(message: _error!),
          ],
          const SizedBox(height: 12),
          if (_loading)
            const SfLoadingCard()
          else if (comp != null) ...[
            SfCoaExportHero(
              monthLabel: monthLabel,
              exportAllowed: exportAllowed,
              onTimePercent: onTime,
              delayedPercent: delayed,
              docsInPeriod: (totals?['documents_in_period'] as int?) ?? 0,
              submissionNote: submissionNote,
              onChangeMonth: _pickMonth,
              onExport: _shareSummary,
            ),
            const SizedBox(height: 14),
            SfComplianceRates(
              onTime: onTime,
              unforwarded: unforwarded,
              delayed: delayed,
              monthLabel: 'Municipal',
            ),
          ] else ...[
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
          ],
          const SizedBox(height: 16),
          const Text(
            'Audit exceptions (custody gaps)',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
          ),
          const SizedBox(height: 4),
          const Text(
            'Unforwarded OUT scans or wrong-office IN — review before COA reporting.',
            style: TextStyle(fontSize: 11, color: SfColors.muted),
          ),
          const SizedBox(height: 8),
          if (_loadingExceptions)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator(),
            )
          else if (_exceptions.isEmpty)
            const SfEmptyState(
              icon: Icons.verified_outlined,
              title: 'No exceptions (24h)',
              subtitle: 'No unforwarded or wrong-receiver scans detected.',
            )
          else
            ..._exceptions.take(12).map(
                  (ex) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: SfListTile(
                      title: ex['document_id']?.toString() ?? '',
                      subtitle: ex['detail']?.toString() ?? '',
                      accent: ex['exception_type'] == 'wrong_receiver'
                          ? SfColors.red
                          : SfColors.gold,
                    ),
                  ),
                ),
          if (!_loading) ...[
            const SizedBox(height: 16),
            const Text(
              'Office totals',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: SfColors.ink,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Documents touched per office this month',
              style: TextStyle(fontSize: 11, color: SfColors.muted, height: 1.35),
            ),
            const SizedBox(height: 8),
            if (offices.isEmpty)
              const SfEmptyState(
                icon: Icons.assessment_outlined,
                title: 'No office data',
                subtitle: 'No movements recorded for this month yet.',
              )
            else
              ...offices.map((o) {
                final m = o as Map<String, dynamic>;
                final code = m['office_code']?.toString() ?? 'ENG';
                final count = (m['docs_processed'] as int?) ?? 0;
                return SfListTile(
                  title: m['office_name']?.toString() ?? code,
                  subtitle:
                      '$count document${count == 1 ? '' : 's'} with movement this month',
                  accent: SfColors.dept(code),
                );
              }),
          ],
        ],
      ),
    );
  }
}

// ─── Thresholds ─────────────────────────────────────────────────────────────

class AdminThresholdsScreen extends StatefulWidget {
  const AdminThresholdsScreen({super.key});

  @override
  State<AdminThresholdsScreen> createState() => _AdminThresholdsScreenState();
}

class _AdminThresholdsScreenState extends State<AdminThresholdsScreen> {
  List<dynamic> _offices = [];
  int? _officeId;
  final _typeCtrl = TextEditingController();
  final _hoursCtrl = TextEditingController();
  String? _error;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _typeCtrl.dispose();
    _hoursCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await context.read<AuthProvider>().api.adminOffices();
      final list = data['offices'] as List<dynamic>? ?? [];
      if (!mounted) return;
      setState(() {
        _offices = list;
        if (list.isNotEmpty && _officeId == null) {
          final first = list.first as Map<String, dynamic>;
          _officeId = first['office_id'] as int? ?? first['id'] as int?;
        }
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = apiErrorMessage(e);
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    final type = _typeCtrl.text.trim();
    final hoursRaw = _hoursCtrl.text.trim();
    if (_officeId == null) {
      setState(() => _error = 'Select an office.');
      return;
    }
    if (type.isEmpty) {
      setState(() => _error = 'Enter a document type (e.g. Disbursement Voucher).');
      return;
    }
    final hours = int.tryParse(hoursRaw);
    if (hours == null || hours < 1) {
      setState(() => _error = 'Enter max processing hours as a whole number (e.g. 48).');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await context.read<AuthProvider>().api.updateThreshold(
            officeId: _officeId!,
            documentType: type,
            maxHours: hours,
          );
      if (!mounted) return;
      sfShowSuccessSnack(context, message: 'Threshold saved');
      await _load();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      color: SfColors.blue,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          const SfAuthenticatedPageHeader(),
          const SizedBox(height: 12),
          const SfAdminPageOverviewCard(
            screen: SfAdminScreen.thresholds,
            compact: true,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            SfErrorBanner(message: _error!),
          ],
          const SizedBox(height: 14),
          if (_loading)
            const SfLoadingCard()
          else if (_offices.isEmpty)
            const SfEmptyState(
              icon: Icons.business_outlined,
              title: 'No offices loaded',
              subtitle: 'Pull to refresh or check the API connection.',
            )
          else
            SfFormCard(
              child: Column(
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: _officeId,
                    decoration: const InputDecoration(labelText: 'Office'),
                    items: _offices.map((o) {
                      final m = o as Map<String, dynamic>;
                      final id = m['office_id'] as int? ?? m['id'] as int;
                      final name = m['office_name'] ?? m['name'];
                      final code = m['office_code'] ?? m['code'];
                      return DropdownMenuItem(
                        value: id,
                        child: Text('$name ($code)'),
                      );
                    }).toList(),
                    onChanged: (v) => setState(() => _officeId = v),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _typeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Document type',
                      hintText: 'e.g. Disbursement Voucher',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _hoursCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Max processing hours',
                      hintText: 'e.g. 48',
                      helperText:
                          'Alerts fire when a folder stays longer than this at one office.',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  SfPrimaryButton(
                    label: _saving ? 'Saving…' : 'Save threshold',
                    loading: _saving,
                    onPressed: _saving ? null : _save,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
