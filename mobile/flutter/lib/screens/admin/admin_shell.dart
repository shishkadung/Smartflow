import '../../widgets/home_folder_actions.dart';
import '../../utils/live_refresh.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_client.dart';
import '../../services/smartflow_api.dart';
import '../../theme/sf_icons.dart';
import '../../theme/smartflow_theme.dart';
import '../shared/change_password_sheet.dart';
import '../shared/edit_profile_sheet.dart';
import '../shared/profile_photo.dart';
import '../../widgets/sf_help.dart';
import '../../widgets/sf_page.dart';
import '../../utils/api_error.dart';
import '../../widgets/sf_account_menu.dart';
import '../../widgets/sf_widgets.dart';
import '../../widgets/sf_pdf_chrome.dart';
import '../../widgets/profile_snapshot_feedback.dart';
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
  int _pendingRequests = 0;

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
      if (!mounted) return;
      final pending = await sfPendingRequestCount(context);
      if (mounted) setState(() => _pendingRequests = pending);
    } catch (_) {}
  }

  void refreshPendingBadge(int count) {
    if (mounted) setState(() => _pendingSignups = count);
  }

  static const _primaryTabs = [
    '/admin',
    '/admin/history',
    '/admin/reports',
    '/admin/alerts',
  ];

  int _indexForPath(String loc) => _primaryTabs.indexWhere((t) => loc == t);

  void _onTab(int i) {
    context.go(_primaryTabs[i]);
    _loadPendingBadge();
  }

  @override
  Widget build(BuildContext context) {
    final loc = GoRouterState.of(context).uri.path;
    final index = _indexForPath(loc);
    final profileActive = sfIsOnProfilePage(loc, 'admin');

    return SfNavBadgeScope(
      alertCount: 0,
      child: SfAppScaffold(
        currentIndex: index,
        onTab: _onTab,
        onMenu: () => showSfRoleMoreSheet(
          context,
          pendingSignups: _pendingSignups,
          pendingRequests: _pendingRequests,
        ),
        onProfile: () => context.go(sfProfileRouteForRole('admin')),
        profileActive: profileActive,
        menuActive: index < 0 && !profileActive,
        tabs: [
          const SfNavTab(
            icon: SfIcons.adminHome,
            activeIcon: SfIcons.adminHomeActive,
            label: 'Home',
          ),
          const SfNavTab(
            icon: SfIcons.clerkHistory,
            activeIcon: SfIcons.clerkHistoryActive,
            label: 'History',
          ),
          const SfNavTab(
            icon: SfIcons.adminCoaSummary,
            activeIcon: SfIcons.adminCoaSummaryActive,
            label: 'Reports',
            elevated: true,
          ),
          const SfNavTab(
            icon: SfIcons.clerkAlerts,
            activeIcon: SfIcons.clerkAlertsActive,
            label: 'Alerts',
          ),
          SfNavTab(
            icon: SfIcons.menu,
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
  String? _statsError;
  DateTime? _statsUpdated;
  int _statsRead = 0;
  late Object _statsIdentity;
  bool _photoBusy = false;

  @override
  void initState() {
    super.initState();
    _statsIdentity = context.read<AuthProvider>().sessionIdentity;
    _loadMunicipalStats();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final identity = context.read<AuthProvider>().sessionIdentity;
    if (_statsIdentity == identity) return;
    _statsIdentity = identity;
    _activeDocs = _overdue = _pending = null;
    _apiOnline = null;
    _statsUpdated = null;
    _statsError = null;
    _loadMunicipalStats();
  }

  Future<void> _loadMunicipalStats() async {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated || auth.loggingOut) return;
    final identity = auth.sessionIdentity;
    final api = auth.api;
    final read = ++_statsRead;
    bool current() =>
        mounted && read == _statsRead && auth.sessionIdentity == identity;
    setState(() {
      _statsLoading = true;
      _apiOnline = null;
    });
    try {
      final data = await api.accountantDashboard();
      if (!current()) return;
      final stats = data['stats'] as Map<String, dynamic>? ?? {};
      Map<String, dynamic> status;
      try {
        status = await api.systemStatus();
      } catch (error) {
        throw ApiException(
          'System status unavailable. ${apiErrorMessage(error)}',
        );
      }
      if (!mounted || !current()) return;
      final apiStatus = (status['status'] as Map?)?['api']?.toString();
      setState(() {
        _activeDocs = '${stats['active_documents'] ?? '—'}';
        _overdue = '${stats['overdue'] ?? '—'}';
        _pending = '${stats['pending_signups'] ?? '—'}';
        _statsError = null;
        _apiOnline = apiStatus?.startsWith('On') == true
            ? true
            : apiStatus?.startsWith('Off') == true
            ? false
            : null;
        _statsUpdated = DateTime.now();
      });
      final n = (stats['pending_signups'] as int?) ?? 0;
      context.findAncestorStateOfType<_AdminShellState>()?.refreshPendingBadge(
        n,
      );
    } catch (error) {
      if (current()) setState(() => _statsError = apiErrorMessage(error));
    } finally {
      if (current()) setState(() => _statsLoading = false);
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
      onRefresh: _loadMunicipalStats,
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
            const SizedBox(height: 16),
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
              subtitle: 'Your municipal account and oversight summary.',
            ),
            const SizedBox(height: 16),
            ProfileSnapshotFeedback(
              updatedAt: _statsUpdated,
              error: _statsError,
              loading: _statsLoading,
              onRetry: _loadMunicipalStats,
              label: 'Municipal snapshot',
            ),
            if (_apiOnline != null) ...[
              SfAdminSystemStatusBanner(
                apiOnline: _apiOnline!,
                onTap: () => context.go('/admin/system'),
              ),
              const SizedBox(height: 14),
            ],
            if (_apiOnline == null && !_statsLoading)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  'System status unknown.',
                  style: TextStyle(color: SfColors.muted),
                ),
              ),
            if (_statsLoading && _statsUpdated == null)
              const SfLoadingCard()
            else
              SfProfileAccountCard(
                user: user,
                roleLabel:
                    'Administrator · ${user.officeName} (${user.officeCode})',
                deskSectionTitle: 'Municipal snapshot',
                stat1Label: 'Active docs',
                stat2Label: 'Overdue',
                stat3Label: 'Sign-ups',
                inFlow: _activeDocs,
                outFlow: _overdue,
                activeTags: _pending,
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

// ─── Home ───────────────────────────────────────────────────────────────────

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with LiveRefresh<AdminDashboardScreen> {
  @override
  Future<void> refreshLiveData() => _load(silent: true);

  Map<String, dynamic>? _dash;
  String? _error;
  bool _loading = true;
  bool _loadInFlight = false;

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
    setState(() {
      if (!silent) {
        _loading = true;
      }
    });
    try {
      final api = context.read<AuthProvider>().api;
      final dash = await api.accountantDashboard();
      if (!mounted) return;
      final pending = (dash['stats']?['pending_signups'] as int?) ?? 0;
      context.findAncestorStateOfType<_AdminShellState>()?.refreshPendingBadge(
        pending,
      );
      setState(() {
        _dash = dash;
        _loading = false;
        _error = null;
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

  @override
  Widget build(BuildContext context) {
    final stats = _dash?['stats'] as Map<String, dynamic>?;
    final offices = _dash?['office_totals'] as List<dynamic>? ?? [];
    final rawMonth = _dash?['month']?.toString();
    final parsedMonth = rawMonth == null
        ? null
        : DateTime.tryParse('$rawMonth-01');
    final month = parsedMonth != null
        ? DateFormat('MMMM yyyy').format(parsedMonth)
        : rawMonth;
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
          const SfAdminPageOverviewCard(screen: SfAdminScreen.home),
          const SizedBox(height: 16),
          if (_error != null) ...[
            SfErrorBanner(
              message: _dash == null
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
                : stats == null
                ? null
                : SfAdminStatRow(
                    activeDocs: active,
                    overdue: overdue,
                    pendingSignups: pending,
                    onActiveDocsTap: () => context.push(
                      '/admin/documents?scope=municipal&tray=in_office',
                    ),
                    onOverdueTap: () => context.push(
                      '/admin/documents?scope=municipal&overdue=1',
                    ),
                    onPendingTap: () => context.go('/admin/users'),
                  ),
          ),
          if (pending > 0) ...[
            SfAdminStartHereCard(pendingSignups: pending),
            const SizedBox(height: 12),
          ],
          if (month != null && month.isNotEmpty) ...[
            Text(
              '$month · $pilotOffices office${pilotOffices == 1 ? '' : 's'}',
              style: const TextStyle(fontSize: 12, color: SfColors.muted),
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
                onTap: () => context.push(
                  '/admin/documents?scope=municipal&office_id=${m['office_id']}&tray=in_office',
                ),
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

enum _AdminUserFilter { all, pending, active, inactive }

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
  String? _readError;
  bool _hasLoaded = false;
  bool _readFresh = false;
  bool _loading = true;
  int _loadGeneration = 0;
  int? _updatingUser;
  int? _decidingSignup;
  String? _signupAction;
  bool _signupSubmitted = false;

  Future<void> _toggleUser(Map<String, dynamic> user) async {
    final auth = context.read<AuthProvider>();
    final identity = auth.sessionIdentity;
    final api = auth.api;
    bool current() => mounted && auth.sessionIdentity == identity;
    final id = (user['id'] as num).toInt();
    if (auth.loggingOut ||
        !_readFresh ||
        _loading ||
        _decidingSignup != null ||
        _updatingUser != null ||
        id == context.read<AuthProvider>().user?.id) {
      return;
    }
    final active = user['is_active'] != true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          '${active ? 'Activate' : 'Deactivate'} ${user['username']}?',
        ),
        content: Text(
          active
              ? 'This account can sign in again with its existing role and office.'
              : 'This account will lose access. Its documents and audit history remain available.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(active ? 'Activate account' : 'Deactivate account'),
          ),
        ],
      ),
    );
    if (ok != true ||
        !mounted ||
        !current() ||
        auth.loggingOut ||
        !_readFresh ||
        _loading ||
        _decidingSignup != null) {
      return;
    }
    setState(() {
      _updatingUser = id;
      _error = null;
    });
    try {
      await api.setUserActive(id, active);
      if (!mounted || !current()) return;
      sfShowSuccessSnack(
        context,
        message: '${user['username']} ${active ? 'activated' : 'deactivated'}',
      );
      await _load();
    } catch (e) {
      if (current()) setState(() => _error = apiErrorMessage(e));
    } finally {
      if (current()) setState(() => _updatingUser = null);
    }
  }

  Future<void> _manageUser(Map<String, dynamic> user) async {
    final auth = context.read<AuthProvider>();
    if (auth.loggingOut ||
        !_readFresh ||
        _loading ||
        _decidingSignup != null ||
        _updatingUser != null ||
        !sfAdminCanManageUser(user)) {
      return;
    }
    final canReset = sfAdminCanResetPassword(user, auth.user?.id);
    final email = user['email']?.toString() ?? '';
    final choice = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Manage ${user['username']}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                  color: SfColors.navy,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${user['role']} · ${user['office_name'] ?? ''}',
                style: const TextStyle(fontSize: 13, color: SfColors.muted),
              ),
              const SizedBox(height: 4),
              Text(
                'Reset email: ${email.isEmpty ? 'not set' : email}${sfEmailNeedsCheck(user) ? ' · check this address' : ''}',
                style: const TextStyle(fontSize: 13, color: SfColors.muted),
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.mail_outline_rounded),
                title: const Text('Edit reset email'),
                onTap: () => Navigator.pop(ctx, 'email'),
              ),
              if (canReset)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.lock_reset_rounded),
                  title: const Text('Reset password'),
                  subtitle: const Text('Issue a temporary password'),
                  onTap: () => Navigator.pop(ctx, 'reset'),
                )
              else
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    'Password reset is available for active accounts only.',
                    style: TextStyle(fontSize: 13, color: SfColors.muted),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'email') {
      await _editEmail(user);
    } else if (choice == 'reset') {
      await _resetPassword(user);
    }
  }

  Future<void> _editEmail(Map<String, dynamic> user) async {
    final auth = context.read<AuthProvider>();
    final identity = auth.sessionIdentity;
    final api = auth.api;
    bool current() => mounted && auth.sessionIdentity == identity;
    final id = (user['id'] as num).toInt();
    final next = await showDialog<String>(
      context: context,
      builder: (ctx) => _AdminEditEmailDialog(
        name: (user['name'] ?? user['username']).toString(),
        username: user['username'].toString(),
        initial: user['email']?.toString() ?? '',
      ),
    );
    if (next == null ||
        !current() ||
        auth.loggingOut ||
        !_readFresh ||
        _loading ||
        _decidingSignup != null ||
        _updatingUser != null) {
      return;
    }
    setState(() {
      _updatingUser = id;
      _error = null;
    });
    try {
      final data = await api.adminSetUserEmail(id, next);
      if (!mounted || !current()) return;
      sfShowSuccessSnack(
        context,
        message: data['unchanged'] == true
            ? '${user['username']} already has that email address'
            : 'Email address for ${user['username']} updated',
      );
      await _load();
    } catch (e) {
      if (current()) setState(() => _error = apiErrorMessage(e));
    } finally {
      if (current()) setState(() => _updatingUser = null);
    }
  }

  Future<void> _resetPassword(Map<String, dynamic> user) async {
    final auth = context.read<AuthProvider>();
    final identity = auth.sessionIdentity;
    final api = auth.api;
    bool current() => mounted && auth.sessionIdentity == identity;
    final id = (user['id'] as num).toInt();
    if (auth.loggingOut ||
        !_readFresh ||
        _loading ||
        _decidingSignup != null ||
        _updatingUser != null ||
        !sfAdminCanResetPassword(user, auth.user?.id)) {
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Issue a temporary password?'),
        content: Text(
          '${user['name'] ?? user['username']} (@${user['username']}) will be signed out everywhere and their current password will stop working. '
          'You will see a temporary password once.\n\n'
          'Use this only when the emailed reset code does not reach the user. Prefer the Forgot password email when it works.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Issue temporary password'),
          ),
        ],
      ),
    );
    if (ok != true ||
        !current() ||
        auth.loggingOut ||
        !_readFresh ||
        _loading ||
        _decidingSignup != null ||
        _updatingUser != null) {
      return;
    }
    setState(() {
      _updatingUser = id;
      _error = null;
    });
    try {
      final data = await api.adminResetPassword(id);
      if (!mounted || !current()) return;
      final password = data['temporary_password']?.toString() ?? '';
      if (password.isEmpty) {
        setState(() => _error = 'No temporary password was returned. Try again.');
        return;
      }
      final target = data['user'] is Map
          ? Map<String, dynamic>.from(data['user'] as Map)
          : <String, dynamic>{};
      // The password lives only in this call; it is not stored or logged.
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => SfTemporaryPasswordDialog(
          name: (target['name'] ?? user['name'] ?? user['username']).toString(),
          username: (target['username'] ?? user['username']).toString(),
          password: password,
          expires: data['expires_at']?.toString(),
        ),
      );
    } catch (e) {
      if (current()) setState(() => _error = apiErrorMessage(e));
    } finally {
      if (current()) setState(() => _updatingUser = null);
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool afterDecision = false}) async {
    if (_decidingSignup != null && !afterDecision) return;
    final generation = ++_loadGeneration;
    final auth = context.read<AuthProvider>();
    final identity = auth.sessionIdentity;
    final api = auth.api;
    bool currentRead() =>
        mounted &&
        generation == _loadGeneration &&
        auth.sessionIdentity == identity;
    setState(() {
      _loading = true;
      _error = null;
      _readError = null;
      _readFresh = false;
    });
    try {
      final users = await api.usersList();
      if (!mounted || !currentRead()) return;
      final pending = await api.signupPending();
      if (!mounted || !currentRead()) return;
      final pCount = (pending['pending'] as List<dynamic>? ?? []).length;
      context.findAncestorStateOfType<_AdminShellState>()?.refreshPendingBadge(
        pCount,
      );
      setState(() {
        _users = (users['users'] as List<dynamic>? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _pending = (pending['pending'] as List<dynamic>? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _loading = false;
        _hasLoaded = true;
        _readFresh = true;
      });
    } on ApiException catch (e) {
      if (currentRead()) {
        setState(() {
          _readError = e.message;
          _loading = false;
        });
      }
    } catch (e) {
      if (currentRead()) {
        setState(() {
          _readError = apiErrorMessage(e);
          _loading = false;
        });
      }
    }
  }

  Future<void> _approve(int id, String action) async {
    final auth = context.read<AuthProvider>();
    final identity = auth.sessionIdentity;
    final api = auth.api;
    bool current() => mounted && auth.sessionIdentity == identity;
    if (auth.loggingOut ||
        !_readFresh ||
        _loading ||
        _decidingSignup != null ||
        _updatingUser != null) {
      return;
    }
    setState(() {
      _decidingSignup = id;
      _signupAction = action;
      _signupSubmitted = false;
      _error = null;
    });
    final label = action == 'approve' ? 'Approve' : 'Reject';
    try {
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
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(label),
            ),
          ],
        ),
      );
      if (ok != true ||
          !mounted ||
          !current() ||
          auth.loggingOut ||
          !_readFresh ||
          _loading ||
          _decidingSignup != id ||
          _signupAction != action) {
        return;
      }
      setState(() => _signupSubmitted = true);
      await api.signupApprove(id, action);
      if (!mounted || !current()) return;
      sfShowSuccessSnack(
        context,
        message: action == 'approve'
            ? 'Sign-up approved — account is active'
            : 'Sign-up rejected',
        backgroundColor: action == 'approve' ? SfColors.green : SfColors.gold,
      );
      await _load(afterDecision: true);
    } catch (error) {
      if (current()) setState(() => _error = apiErrorMessage(error));
    } finally {
      if (current() && _decidingSignup == id && _signupAction == action) {
        setState(() {
          _decidingSignup = null;
          _signupAction = null;
          _signupSubmitted = false;
        });
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
    final showPending =
        _filter == _AdminUserFilter.all || _filter == _AdminUserFilter.pending;
    final showActive = _filter != _AdminUserFilter.pending;
    final filteredPending = _pending
        .where(_matchesSearch)
        .toList(growable: false);
    final filteredUsers = _users
        .where((m) {
          if (!_matchesSearch(m)) return false;
          if (_filter == _AdminUserFilter.active) {
            return m['is_active'] as bool? ?? true;
          }
          if (_filter == _AdminUserFilter.inactive) {
            return m['is_active'] == false;
          }
          return true;
        })
        .toList(growable: false);

    return RefreshIndicator(
      onRefresh: _load,
      color: SfColors.blue,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          const SfAuthenticatedPageHeader(),
          const SizedBox(height: 12),
          const SfPageTitle(
            title: 'Users',
            subtitle: 'Review sign-ups and manage municipal account access.',
          ),
          if (_readError != null) ...[
            const SizedBox(height: 12),
            SfErrorBanner(
              message: _hasLoaded
                  ? 'Refresh failed. Previously loaded accounts and sign-ups may be stale. $_readError'
                  : 'Accounts and sign-ups unavailable. $_readError',
            ),
            TextButton(
              onPressed: _loading || _decidingSignup != null ? null : _load,
              child: const Text('Retry accounts'),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            SfErrorBanner(message: _error!),
          ],
          const SizedBox(height: 12),
          SfFormCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Search accounts',
                hintText: 'Search username, role, office…',
                border: InputBorder.none,
                prefixIcon: Icon(Icons.search_rounded, size: 20),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _search = v.trim()),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _filterChip('All', _AdminUserFilter.all),
              _filterChip(
                !_hasLoaded
                    ? 'Pending'
                    : _readFresh
                    ? 'Pending (${_pending.length})'
                    : 'Pending (${_pending.length} · stale)',
                _AdminUserFilter.pending,
              ),
              _filterChip('Active', _AdminUserFilter.active),
              _filterChip('Inactive', _AdminUserFilter.inactive),
            ],
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: SfLoadingCard(),
            )
          else if (_hasLoaded) ...[
            if (showPending && filteredPending.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Pending sign-up · ${filteredPending.length}${_readFresh ? '' : ' · may be stale'}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: SfColors.navy,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Check the requested office and role before approving access.',
                style: TextStyle(
                  fontSize: 13,
                  color: SfColors.muted,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 8),
              ...filteredPending.map(
                (p) => AbsorbPointer(
                  absorbing: !_readFresh,
                  child: Opacity(
                    opacity: _readFresh ? 1 : 0.55,
                    child: SfAdminPendingSignupCard(
                      request: p,
                      enabled: _decidingSignup == null && _updatingUser == null,
                      pendingAction:
                          _signupSubmitted && _decidingSignup == p['id']
                          ? _signupAction
                          : null,
                      onApprove: () => _approve(p['id'] as int, 'approve'),
                      onReject: () => _approve(p['id'] as int, 'reject'),
                    ),
                  ),
                ),
              ),
            ],
            if (showPending &&
                _readFresh &&
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
            if (_filter == _AdminUserFilter.pending &&
                _readFresh &&
                filteredPending.isEmpty &&
                (_pending.isEmpty || _search.isEmpty))
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: SfEmptyState(
                  icon: Icons.person_add_alt_1_outlined,
                  title: 'No pending sign-ups',
                  subtitle: 'Accounts awaiting approval will appear here.',
                ),
              ),
            if (showActive) ...[
              const SizedBox(height: 16),
              Text(
                'Directory · ${filteredUsers.length}${_readFresh ? '' : ' · may be stale'}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: SfColors.navy,
                ),
              ),
              const SizedBox(height: 8),
              if (filteredUsers.isEmpty && _readFresh)
                const SfEmptyState(
                  icon: Icons.people_outline_rounded,
                  title: 'No users found',
                  subtitle: 'Adjust filters or search.',
                )
              else
                ...filteredUsers.map(
                  (m) => SfAdminUserCard(
                    user: m,
                    isSelf: m['id'] == context.read<AuthProvider>().user?.id,
                    busy: _updatingUser != null,
                    onToggleActive: !_readFresh || _decidingSignup != null
                        ? null
                        : () => _toggleUser(m),
                    onManage:
                        !_readFresh ||
                            _decidingSignup != null ||
                            !sfAdminCanManageUser(m)
                        ? null
                        : () => _manageUser(m),
                  ),
                ),
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
        fontSize: 12,
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
          const SfPageTitle(
            title: 'Offices',
            subtitle: 'Municipal offices and their saved alert time limits.',
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            SfErrorBanner(message: _error!),
          ],
          const SizedBox(height: 12),
          SfNavigationRow(
            icon: Icons.schedule_outlined,
            title: 'Alert time limits',
            subtitle: 'Manage processing and receipt limits by office',
            onTap: () => context.push('/admin/thresholds'),
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
              final thresholds = m['thresholds'] as List<dynamic>? ?? [];
              final threshText = thresholds.isEmpty
                  ? 'No alert time limits configured'
                  : thresholds
                        .map((t) {
                          final th = t as Map<String, dynamic>;
                          return '${th['document_type']}\n${th['max_hours']}h processing · ${th['out_unconfirmed_hours']}h awaiting receipt';
                        })
                        .join('\n\n');
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
                            fontSize: 12,
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
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                color: SfColors.ink,
                              ),
                            ),
                            // No status pill: every office used to show a fixed "Active" that no data backed.
                            const SizedBox(height: 8),
                            Text(
                              threshText,
                              style: const TextStyle(
                                fontSize: 13,
                                color: SfColors.muted,
                                height: 1.35,
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
          const SfAdminPageOverviewCard(
            screen: SfAdminScreen.system,
            compact: true,
          ),
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
                            fontSize: 12,
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
                      '${_data?['role_counts']?['staff'] ?? 0} clerks · ${_data?['role_counts']?['head'] ?? 0} heads · ${_data?['role_counts']?['admin'] ?? 0} admin',
                      style: const TextStyle(
                        fontSize: 12,
                        color: SfColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (ops != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: SfStatCard(
                      value:
                          '${_data?['users']?['active'] ?? ops['pending_signups'] ?? 0}',
                      label: 'Active users',
                      color: SfColors.countInk(
                        _data?['users']?['active'] ??
                            ops['pending_signups'] ??
                            0,
                        live: SfColors.blue,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SfStatCard(
                      value: '${ops['movements_today'] ?? 0}',
                      label: 'Scans today',
                      color: SfColors.countInk(
                        ops['movements_today'] ?? 0,
                        live: SfColors.green,
                      ),
                    ),
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
                      style: const TextStyle(
                        fontSize: 12,
                        color: SfColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              sfAdminLastSyncLabel(_lastLoaded),
              style: const TextStyle(
                fontSize: 12,
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
  String _period = 'month';
  int _year = DateTime.now().year;
  int _quarterYear = DateTime.now().year;
  int _quarter = ((DateTime.now().month - 1) ~/ 3) + 1;
  String? _error;
  bool _loading = true;
  List<Map<String, dynamic>> _exceptions = [];
  bool _exceptionsLoaded = false;
  String? _exceptionsError;
  bool _loadingExceptions = false;
  bool _exporting = false;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
      _report = null;
      _exceptions = [];
      _exceptionsLoaded = false;
      _exceptionsError = null;
      _loadingExceptions = false;
    });
    try {
      final user = context.read<AuthProvider>().user!;
      final api = context.read<AuthProvider>().api;
      final data = switch (_period) {
        'year' => await api.reportsSummaryAnnual(user.officeId, _year),
        'quarter' => await api.reportsSummaryQuarterly(
          user.officeId,
          _quarterYear,
          _quarter,
        ),
        _ => await api.reportsSummary(user.officeId, _month),
      };
      if (!mounted || request != _request) return;
      setState(() {
        _report = data;
        _loading = false;
      });
      await _loadExceptions(request);
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

  Future<void> _loadExceptions(int request) async {
    if (!mounted || request != _request || _loadingExceptions) return;
    final user = context.read<AuthProvider>().user;
    if (user == null || user.officeCode.toUpperCase() != 'ACC') {
      return;
    }
    setState(() {
      _loadingExceptions = true;
      _exceptionsError = null;
    });
    final period = switch (_period) {
      'year' => {'period': 'year', 'year': '$_year'},
      'quarter' => {
        'period': 'quarter',
        'year': '$_quarterYear',
        'quarter': '$_quarter',
      },
      _ => {'period': 'month', 'month': _month},
    };
    try {
      final data = await context.read<AuthProvider>().api.auditExceptions(
        hours: 24,
        period: period,
      );
      if (!mounted || request != _request) return;
      setState(() {
        _exceptions = (data['exceptions'] as List<dynamic>? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _loadingExceptions = false;
        _exceptionsLoaded = true;
        _exceptionsError = null;
      });
    } catch (e) {
      if (mounted && request == _request) {
        setState(() {
          _loadingExceptions = false;
          _exceptionsError = apiErrorMessage(e);
        });
      }
    }
  }

  Future<void> _pickMonth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.parse('$_month-01'),
      firstDate: DateTime(now.year - 14),
      lastDate: now,
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked == null || !mounted) return;
    setState(() => _month = DateFormat('yyyy-MM').format(picked));
    await _load();
  }

  Future<void> _pickYear() async {
    final now = DateTime.now();
    final picked = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Report year'),
        content: SizedBox(
          width: 300,
          height: 300,
          child: YearPicker(
            firstDate: DateTime(now.year - 14),
            lastDate: now,
            selectedDate: DateTime(_year),
            onChanged: (d) => Navigator.pop(ctx, d.year),
          ),
        ),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() => _year = picked);
    await _load();
  }

  Future<void> _pickQuarter() async {
    final now = DateTime.now();
    final currentQuarter = ((now.month - 1) ~/ 3) + 1;
    final options = <(int, int)>[
      for (var y = now.year; y >= now.year - 14; y--)
        for (var q = y == now.year ? currentQuarter : 4; q >= 1; q--) (y, q),
    ];
    final picked = await showDialog<(int, int)>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Report quarter'),
        children: [
          SizedBox(
            width: 300,
            height: 300,
            child: ListView(
              children: [
                for (final (y, q) in options)
                  ListTile(
                    title: Text('Q$q $y'),
                    selected: y == _quarterYear && q == _quarter,
                    onTap: () => Navigator.pop(ctx, (y, q)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _quarterYear = picked.$1;
      _quarter = picked.$2;
    });
    await _load();
  }

  Future<void> _setPeriod(String period) async {
    if (period == _period) return;
    setState(() => _period = period);
    await _load();
  }

  Future<void> Function() get _pickPeriod => switch (_period) {
    'year' => _pickYear,
    'quarter' => _pickQuarter,
    _ => _pickMonth,
  };

  String get _pickerLabel => switch (_period) {
    'year' => 'Year',
    'quarter' => 'Quarter',
    _ => 'Month',
  };

  String get _periodLabel => switch (_period) {
    'year' => 'Annual $_year',
    'quarter' => 'Q$_quarter $_quarterYear',
    _ => DateFormat('MMMM yyyy').format(DateTime.parse('$_month-01')),
  };

  Future<void> _export(String format) async {
    final report = _report;
    if (report == null ||
        report['export_allowed'] != true ||
        _loading ||
        _exporting) {
      return;
    }
    setState(() => _exporting = true);
    try {
      final text = await context.read<AuthProvider>().api.reportExport({
        'office_id': '${report['office_id']}',
        'period': '${report['period']}',
        if (report['month'] != null) 'month': '${report['month']}',
        if (report['year'] != null) 'year': '${report['year']}',
        if (report['quarter'] != null) 'quarter': '${report['quarter']}',
      }, format);
      const channel = MethodChannel('smartflow/report_export');
      final done = format == 'print'
          ? await channel.invokeMethod<bool>('printReport', {'html': text})
          : await channel.invokeMethod<bool>('saveCsv', {
              'filename':
                  'SmartFlow-custody-${report['period']}-${'${report['period_start']}'.substring(0, 10)}.csv',
              'bytes': Uint8List.fromList(
                utf8.encode(text.startsWith('\uFEFF') ? text : '\uFEFF$text'),
              ),
            });
      if (mounted && done == true && format == 'csv') {
        sfShowSuccessSnack(context, message: 'Report CSV saved');
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is PlatformException
              ? e.message ?? 'Could not export report'
              : apiErrorMessage(e),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final comp = _report?['compliance'] as Map<String, dynamic>?;
    final offices = _report?['office_totals'] as List<dynamic>? ?? [];
    final totals = _report?['totals'] as Map<String, dynamic>?;
    final monthLabel = _periodLabel;
    final onTime = (comp?['on_time']?['percent'] as num?)?.round() ?? 0;
    final unforwarded =
        (comp?['unforwarded']?['percent'] as num?)?.round() ?? 0;
    final delayed = (comp?['delayed']?['percent'] as num?)?.round() ?? 0;
    final exportAllowed = _report?['export_allowed'] == true;
    final submissionNote = _report?['submission_note']?.toString() ?? '';

    return RefreshIndicator(
      onRefresh: _load,
      color: SfColors.blue,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          const SfAuthenticatedPageHeader(),
          const SizedBox(height: 12),
          const SfPageTitle(
            title: 'Custody reports',
            subtitle:
                'Review handoff metrics and custody exceptions by period.',
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            SfErrorBanner(message: 'Custody report unavailable. $_error'),
            TextButton(onPressed: _load, child: const Text('Retry report')),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final period in const {
                'month': 'Monthly',
                'quarter': 'Quarterly',
                'year': 'Annual',
              }.entries)
                ChoiceChip(
                  label: Text(period.value),
                  selected: _period == period.key,
                  onSelected: (_) => _setPeriod(period.key),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_loading)
            const SfLoadingCard()
          else if (comp != null) ...[
            SfCoaExportHero(
              monthLabel: monthLabel,
              exportAllowed: exportAllowed,
              docsInPeriod: (totals?['documents_in_period'] as int?) ?? 0,
              submissionNote: submissionNote,
              onChangeMonth: _pickPeriod,
              pickerLabel: _pickerLabel,
              onExport: _exporting ? null : () => _export('csv'),
              onPrint: _exporting ? null : () => _export('print'),
            ),
            const SizedBox(height: 8),
            Text(
              'Generated ${_report?['generated_at']} (${_report?['timezone']})\n${_report?['scope']} · Prepared by ${_report?['prepared_by']}',
              style: const TextStyle(fontSize: 13, color: SfColors.muted),
            ),
            const SizedBox(height: 14),
            SfComplianceRates(
              onTime: onTime,
              unforwarded: unforwarded,
              delayed: delayed,
              monthLabel: 'Municipal',
            ),
          ] else ...[
            SfNavigationRow(
              icon: Icons.calendar_month_outlined,
              title: monthLabel,
              subtitle: 'Change ${_pickerLabel.toLowerCase()}',
              onTap: _pickPeriod,
            ),
          ],
          const SizedBox(height: 16),
          const Text(
            'Audit exceptions (custody gaps)',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: SfColors.navy,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Unforwarded OUT, wrong-office IN, or skipped Budget/Accounting — '
            '$_periodLabel. Review before COA reporting.',
            style: const TextStyle(fontSize: 12, color: SfColors.muted),
          ),
          const SizedBox(height: 8),
          if (_exceptionsLoaded && _exceptions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '${_exceptions.length} audit exceptions',
                style: const TextStyle(color: SfColors.muted),
              ),
            ),
          if (_loading || _loadingExceptions)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator(),
            )
          else if (_exceptionsError != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SfErrorBanner(
                  message: 'Audit exceptions unavailable. $_exceptionsError',
                ),
                TextButton(
                  onPressed: () => _loadExceptions(_request),
                  child: const Text('Retry exceptions'),
                ),
              ],
            )
          else if (!_exceptionsLoaded)
            const SfInfoBanner(
              text:
                  'Audit exceptions have not been checked for this period. An empty report does not establish a complete custody trail.',
            )
          else if (_exceptions.isEmpty)
            SfEmptyState(
              icon: Icons.verified_outlined,
              title: 'No exceptions · $_periodLabel',
              subtitle:
                  'No unforwarded, wrong-receiver, or skipped-office trails detected.',
            )
          else
            ..._exceptions.map(
              (ex) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SfListTile(
                  title: ex['document_id']?.toString() ?? '',
                  subtitle: ex['detail']?.toString() ?? '',
                ),
              ),
            ),
          if (!_loading && _error == null && _report != null) ...[
            const SizedBox(height: 16),
            const Text(
              'Office totals',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: SfColors.navy,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Documents touched per office this ${_pickerLabel.toLowerCase()}',
              style: const TextStyle(
                fontSize: 12,
                color: SfColors.muted,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 8),
            if (offices.isEmpty)
              SfEmptyState(
                icon: Icons.assessment_outlined,
                title: 'No office data',
                subtitle:
                    'No movements recorded for this ${_pickerLabel.toLowerCase()} yet.',
              )
            else
              ...offices.map((o) {
                final m = o as Map<String, dynamic>;
                final code = m['office_code']?.toString() ?? 'ENG';
                final count = (m['docs_processed'] as int?) ?? 0;
                return SfListTile(
                  title: m['office_name']?.toString() ?? code,
                  subtitle:
                      '$count document${count == 1 ? '' : 's'} with movement this ${_pickerLabel.toLowerCase()}',
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
  late final AuthProvider _auth;
  late final Object _identity;
  late final SmartflowApi _api;
  bool get _current => mounted && _auth.sessionIdentity == _identity;
  List<dynamic> _offices = [];
  int? _officeId;
  final _typeCtrl = TextEditingController();
  final _hoursCtrl = TextEditingController();
  final _receiptHoursCtrl = TextEditingController();
  String? _error;
  bool _loading = true;
  bool _saving = false;
  bool _limitsFresh = false;

  List<Map<String, dynamic>> get _rules {
    for (final office in _offices) {
      if (office['office_id'] == _officeId || office['id'] == _officeId) {
        return (office['thresholds'] as List? ?? [])
            .map((rule) => Map<String, dynamic>.from(rule as Map))
            .toList();
      }
    }
    return [];
  }

  void _editRule(Map<String, dynamic>? rule) {
    _typeCtrl.text = rule?['document_type']?.toString() ?? '';
    _hoursCtrl.text = rule?['max_hours']?.toString() ?? '48';
    _receiptHoursCtrl.text = rule?['out_unconfirmed_hours']?.toString() ?? '24';
  }

  @override
  void initState() {
    super.initState();
    _auth = context.read<AuthProvider>();
    _identity = _auth.sessionIdentity;
    _api = _auth.api;
    _load();
  }

  @override
  void dispose() {
    _typeCtrl.dispose();
    _hoursCtrl.dispose();
    _receiptHoursCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!_current) return;
    setState(() {
      _loading = true;
      _error = null;
      _limitsFresh = false;
    });
    try {
      final data = await _api.adminOffices();
      if (!_current) return;
      setState(() {
        _offices = data['offices'] as List<dynamic>? ?? [];
        if (_offices.isNotEmpty && _officeId == null) {
          _officeId =
              (_offices.first['office_id'] ?? _offices.first['id']) as int;
        }
        final matches = _rules.where(
          (r) => r['document_type'] == _typeCtrl.text,
        );
        _editRule(matches.isNotEmpty ? matches.first : _rules.firstOrNull);
        _loading = false;
        _limitsFresh = true;
      });
    } catch (e) {
      if (_current) {
        setState(() {
          _error = apiErrorMessage(e);
          _loading = false;
        });
      }
    }
  }

  Future<void> _save() async {
    if (!_current || _auth.loggingOut || !_limitsFresh || _loading || _saving) {
      return;
    }
    final type = _typeCtrl.text.trim();
    final hours = int.tryParse(_hoursCtrl.text.trim());
    final receiptHours = int.tryParse(_receiptHoursCtrl.text.trim());
    if (_officeId == null || type.isEmpty) {
      setState(() => _error = 'Select an office and enter a document type.');
      return;
    }
    if (hours == null ||
        hours < 1 ||
        hours > 720 ||
        receiptHours == null ||
        receiptHours < 1 ||
        receiptHours > 168) {
      setState(
        () => _error = 'Use 1–720 processing hours and 1–168 receipt hours.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _api.updateThreshold(
        officeId: _officeId!,
        documentType: type,
        maxHours: hours,
        outHours: receiptHours,
      );
      if (!mounted || !_current) return;
      sfShowSuccessSnack(context, message: 'Alert time limits saved');
      await _load();
    } catch (e) {
      if (_current) setState(() => _error = apiErrorMessage(e));
    } finally {
      if (_current) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      color: SfColors.blue,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          const SfAuthenticatedPageHeader(),
          const SizedBox(height: 12),
          const SfPageTitle(
            title: 'Alert time limits',
            subtitle: 'Set processing and receipt limits for each office.',
          ),
          const SizedBox(height: 12),
          const Text(
            'These are elapsed calendar hours, including nights and weekends. 48 hours = 2 days. A folder’s own deadline takes priority.',
            style: TextStyle(color: SfColors.muted),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            SfErrorBanner(
              message: !_limitsFresh && _offices.isNotEmpty
                  ? 'Refresh failed. Previously loaded rules may be stale. $_error'
                  : _error!,
            ),
            TextButton(
              onPressed: _saving ? null : _load,
              child: const Text('Retry'),
            ),
          ],
          const SizedBox(height: 14),
          if (_loading)
            const SfLoadingCard()
          else if (_offices.isEmpty && _error == null)
            const SfEmptyState(
              icon: Icons.business_outlined,
              title: 'No offices loaded',
              subtitle: 'Pull to refresh or check the API connection.',
            )
          else if (_offices.isNotEmpty) ...[
            DropdownButtonFormField<int>(
              isExpanded: true,
              initialValue: _officeId,
              decoration: const InputDecoration(labelText: 'Office'),
              items: _offices.map((o) {
                final id = (o['office_id'] ?? o['id']) as int;
                return DropdownMenuItem(
                  value: id,
                  child: Text(
                    '${o['office_name'] ?? o['name']} (${o['office_code'] ?? o['code']})',
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: _saving || !_limitsFresh
                  ? null
                  : (v) => setState(() {
                      _officeId = v;
                      _editRule(_rules.firstOrNull);
                    }),
            ),
            const SizedBox(height: 16),
            const Text(
              'Saved rules',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: SfColors.navy,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Choose a rule to review or edit both time limits below.',
              style: TextStyle(
                fontSize: 13,
                color: SfColors.muted,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            if (_rules.isEmpty)
              const Text('No saved rule for this office. Add one below.'),
            for (final rule in _rules)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SfFormCard(
                  padding: EdgeInsets.zero,
                  child: ListTile(
                    title: Text('${rule['document_type']}'),
                    subtitle: Text(
                      '${rule['max_hours']}h processing · ${rule['out_unconfirmed_hours']}h awaiting receipt',
                    ),
                    trailing: const Icon(Icons.edit_outlined),
                    onTap: _saving || !_limitsFresh
                        ? null
                        : () => setState(() => _editRule(rule)),
                  ),
                ),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _saving || !_limitsFresh
                    ? null
                    : () => setState(() => _editRule(null)),
                icon: const Icon(Icons.add),
                label: const Text('Add a rule'),
              ),
            ),
            const SizedBox(height: 8),
            SfFormCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Time limit settings',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: SfColors.navy,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Save both limits for the selected office and document type.',
                    style: TextStyle(
                      fontSize: 13,
                      color: SfColors.muted,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _typeCtrl,
                    enabled: !_saving && _limitsFresh,
                    decoration: const InputDecoration(
                      labelText: 'Document type',
                      hintText: 'e.g. Disbursement Voucher',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _hoursCtrl,
                    enabled: !_saving && _limitsFresh,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Processing time limit (hours)',
                      helperText:
                          'Time after receipt before processing is flagged. 1–720 hours.',
                      helperMaxLines: 3,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _receiptHoursCtrl,
                    enabled: !_saving && _limitsFresh,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Receipt time limit (hours)',
                      helperText:
                          'Time after sending before a missing receipt is flagged. 1–168 hours.',
                      helperMaxLines: 3,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SfPrimaryButton(
                    label: _saving ? 'Saving…' : 'Save time limits',
                    loading: _saving,
                    onPressed: _saving || !_limitsFresh ? null : _save,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Owns its text controller so it is disposed with the dialog, not while the close animation runs.
class _AdminEditEmailDialog extends StatefulWidget {
  const _AdminEditEmailDialog({
    required this.name,
    required this.username,
    required this.initial,
  });

  final String name;
  final String username;
  final String initial;

  @override
  State<_AdminEditEmailDialog> createState() => _AdminEditEmailDialogState();
}

class _AdminEditEmailDialogState extends State<_AdminEditEmailDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final value = _controller.text.trim();
    if (value.length > 120 || !sfEmailPattern.hasMatch(value)) {
      setState(
        () => _error = 'Enter a valid email address, for example name@example.com.',
      );
      return;
    }
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit reset email'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.name} (@${widget.username}) receives the password reset code at this address.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              autofocus: true,
              maxLength: 120,
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              onSubmitted: (_) => _save(),
              decoration: InputDecoration(
                labelText: 'Email address',
                errorText: _error,
                border: const OutlineInputBorder(),
              ),
            ),
            const Text(
              'Use an address the person can open. Any unused reset code sent to the old address stops working.',
              style: TextStyle(fontSize: 12, color: SfColors.muted, height: 1.4),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save email')),
      ],
    );
  }
}
