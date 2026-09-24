import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/api_client.dart';
import '../../theme/smartflow_theme.dart';
import '../../widgets/sf_page.dart';
import '../../widgets/sf_pdf_chrome.dart';
import '../../widgets/sf_widgets.dart';
import '../staff/clerk_widgets.dart';

String roleLabel(String r) {
  switch (r) {
    case 'head':
      return 'Head';
    case 'admin':
      return 'Accountant / Admin';
    default:
      return 'Employee (Clerk)';
  }
}

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  int _step = 0;
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _confirm = TextEditingController();

  List<Map<String, dynamic>> _offices = [];
  int? _officeId;
  String _role = 'staff';
  bool _loading = false;
  bool _loadingOffices = true;
  String? _officesError;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOffices();
  }

  Future<void> _loadOffices() async {
    setState(() {
      _loadingOffices = true;
      _officesError = null;
    });
    try {
      final list = await context.read<AuthProvider>().api.offices();
      if (!mounted) return;
      setState(() {
        _offices = list;
        _loadingOffices = false;
        if (list.isNotEmpty) {
          _officeId = list.first['id'] as int;
        }
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _officesError = e.message;
        _loadingOffices = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _officesError = 'Could not load offices. Check that the server is running.';
        _loadingOffices = false;
      });
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _email.dispose();
    _pass.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_pass.text != _confirm.text) {
      setState(() => _error = 'Passwords do not match');
      return;
    }
    if (_officeId == null) {
      setState(() => _error = 'Please choose an office');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await context.read<AuthProvider>().api.signup({
        'full_name': _name.text.trim(),
        'username': _username.text.trim(),
        'email': _email.text.trim(),
        'password': _pass.text,
        'office_id': _officeId,
        'requested_role': _role,
      });
      final req = data['request'] as Map<String, dynamic>;
      if (!mounted) return;
      final office = _offices.firstWhere(
        (o) => o['id'] == _officeId,
        orElse: () => {'name': '', 'code': ''},
      );
      context.go('/signup/pending', extra: {
        'code': req['request_code'],
        'username': req['username'],
        'full_name': _name.text.trim(),
        'office_name': office['name'],
        'office_code': office['code'],
        'requested_role': _role,
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stepNum = _step + 1;
    final strap = _step == 0
        ? 'Step 1 of 2 · Account'
        : 'Step 2 of 2 · Workplace';
    final heroTitle =
        _step == 0 ? 'Create your account' : 'Select office & role';
    final heroBody = _step == 0
        ? 'Tell us who you are. Your account starts as Pending until the LGU IT admin approves it.'
        : "Choose where you work and what you'll do. Admin will verify this during approval.";

    return SfPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SfPageBackButton(
            fallbackRoute: '/login',
            hideOnRoleHome: false,
          ),
          const SizedBox(height: 6),
          const SfSignupTopHeader(),
          const SizedBox(height: 14),
          SfPdfHeroCard(strap: strap, title: heroTitle, body: heroBody),
          const SizedBox(height: 14),
          SfSignupStepProgress(step: stepNum, totalSteps: 2),
          const SizedBox(height: 14),
          SfFormCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_step == 0) ..._buildAccountStep() else ..._buildWorkplaceStep(),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  SfErrorBanner(message: _error!),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (_step == 0)
            SfSecondaryOutlineButton(
              label: 'Back to Login',
              onPressed: () => context.go('/login'),
            )
          else
            Row(
              children: [
                Expanded(
                  child: SfSecondaryOutlineButton(
                    label: '← Back',
                    onPressed: () => setState(() => _step = 0),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: SfPrimaryButton(
                    label: _loading ? 'Submitting…' : 'Submit Request',
                    loading: _loading,
                    onPressed: _loading ? null : _submit,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  List<Widget> _buildAccountStep() {
    return [
      TextField(
        controller: _name,
        decoration: const InputDecoration(
          labelText: 'Full Name',
          hintText: 'Engr. Name',
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _username,
        decoration: const InputDecoration(
          labelText: 'Username',
          hintText: 'name',
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _email,
        keyboardType: TextInputType.emailAddress,
        decoration: const InputDecoration(
          labelText: 'Email (LGU)',
          hintText: 'name@urbiztondo.gov.ph',
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _pass,
        obscureText: true,
        decoration: const InputDecoration(labelText: 'Password'),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _confirm,
        obscureText: true,
        decoration: const InputDecoration(labelText: 'Confirm Password'),
      ),
      const SizedBox(height: 18),
      SfPrimaryButton(
        label: 'Next →',
        onPressed: () => setState(() => _step = 1),
      ),
    ];
  }

  List<Widget> _buildWorkplaceStep() {
    if (_loadingOffices) {
      return const [
        SizedBox(height: 24),
        Center(child: CircularProgressIndicator()),
        SizedBox(height: 12),
        Text(
          'Loading offices…',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: SfColors.muted),
        ),
      ];
    }
    if (_officesError != null) {
      return [
        SfErrorBanner(message: _officesError!),
        const SizedBox(height: 12),
        SfSecondaryOutlineButton(
          label: 'Retry',
          onPressed: _loadOffices,
        ),
      ];
    }
    if (_offices.isEmpty) {
      return const [
        SfErrorBanner(
          message:
              'No offices returned from the server. Contact your LGU IT admin.',
        ),
      ];
    }
    return [
      DropdownButtonFormField<int>(
        initialValue: _officeId,
        decoration: const InputDecoration(labelText: 'Office'),
        items: _offices
            .map(
              (o) => DropdownMenuItem(
                value: o['id'] as int,
                child: Text('${o['name']} (${o['code']})'),
              ),
            )
            .toList(),
        onChanged: (v) => setState(() => _officeId = v),
      ),
      const SizedBox(height: 10),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: SfColors.blue.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Text(
          'Pilot offices: ENG · HR · BUD · ACC · TRE · MAY.',
          style: TextStyle(fontSize: 11, color: SfColors.blue),
        ),
      ),
      const SizedBox(height: 14),
      const Text(
        'Requested role',
        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
      ),
      const SizedBox(height: 8),
      SfRoleSelectGrid(
        selected: _role,
        onSelect: (v) => setState(() => _role = v),
      ),
    ];
  }
}

class SignupPendingScreen extends StatefulWidget {
  const SignupPendingScreen({
    super.key,
    required this.requestCode,
    required this.username,
    this.summary,
  });

  final String requestCode;
  final String username;
  final Map<String, dynamic>? summary;

  @override
  State<SignupPendingScreen> createState() => _SignupPendingScreenState();
}

class _SignupPendingScreenState extends State<SignupPendingScreen> {
  Map<String, dynamic>? _req;
  String? _error;
  bool _polling = false;

  @override
  void initState() {
    super.initState();
    _poll();
  }

  Future<void> _poll() async {
    if (_polling) return;
    setState(() => _polling = true);
    try {
      final data = await context.read<AuthProvider>().api.signupStatus(
            code: widget.requestCode,
            username: widget.username,
          );
      final req = data['request'] as Map<String, dynamic>;
      if (!mounted) return;
      setState(() => _req = req);
      if (req['status'] == 'approved') {
        context.go('/signup/approved', extra: req);
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _polling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _req;
    final s = widget.summary ?? {};
    final name = (r?['full_name'] ?? s['full_name'] ?? '—').toString();
    final officeName = r?['office_name'] ?? s['office_name'] ?? '';
    final officeCode = r?['office_code'] ?? s['office_code'] ?? '';
    final office = (officeName.toString().isNotEmpty ||
            officeCode.toString().isNotEmpty)
        ? '$officeName ($officeCode)'
        : '—';
    final role = roleLabel(
      r?['requested_role']?.toString() ??
          s['requested_role']?.toString() ??
          'staff',
    );
    final status = r?['status']?.toString() ?? 'Pending';

    return SfPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SfPageBackButton(
            fallbackRoute: '/login',
            hideOnRoleHome: false,
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ACCOUNT STATUS',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.9,
                        color: SfColors.muted,
                      ),
                    ),
                    SizedBox(height: 4),
                    SfSmartFlowWordmark(),
                  ],
                ),
              ),
              SfUserAvatar(
                initials: SfUserAvatar.fromName(name),
                size: 40,
              ),
            ],
          ),
          const SizedBox(height: 14),
          SfPdfHeroCard(
            strap: 'After submission · Awaiting approval',
            title: 'Pending admin approval',
            body:
                'Your sign-up request was received. A municipal admin must approve your account before you can sign in.',
            centerBody: true,
            leading: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: SfColors.gold.withValues(alpha: 0.15),
              ),
              child: const Icon(
                Icons.hourglass_top_rounded,
                size: 28,
                color: Color(0xFFB45309),
              ),
            ),
          ),
          const SizedBox(height: 14),
          SfSummaryCard(
            title: 'Request summary',
            trailing: Text(
              '#${widget.requestCode}',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: SfColors.muted,
                fontSize: 12,
              ),
            ),
            rows: [
              MapEntry('Name', name),
              MapEntry('Username', widget.username),
              MapEntry('Office', office),
              MapEntry('Role', role),
              MapEntry('Status', status),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: const [
              SfStatusPill(label: 'Awaiting admin', tone: SfPillTone.warning),
              SfStatusPill(label: 'Email sent', tone: SfPillTone.success),
            ],
          ),
          const SizedBox(height: 14),
          const SfInfoBanner(
            text:
                "You'll receive a notification once an admin approves your account. After approval, sign in normally.",
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            SfErrorBanner(message: _error!),
          ],
          const SizedBox(height: 14),
          SfSecondaryOutlineButton(
            label: 'Back to Login',
            onPressed: () => context.go('/login'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _polling ? null : _poll,
            child: Text(
              _polling ? 'Checking…' : 'Refresh status',
              style: const TextStyle(
                color: SfColors.blue,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SignupApprovedScreen extends StatelessWidget {
  const SignupApprovedScreen({super.key, required this.request});

  final Map<String, dynamic> request;

  @override
  Widget build(BuildContext context) {
    final name = request['full_name']?.toString() ?? '';
    final officeName = request['office_name']?.toString() ?? '';
    final officeCode = request['office_code']?.toString() ?? '';
    final role = roleLabel(request['requested_role']?.toString() ?? 'staff');

    return SfPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SfPageBackButton(
            fallbackRoute: '/login',
            hideOnRoleHome: false,
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ACCOUNT APPROVED',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.9,
                        color: SfColors.muted,
                      ),
                    ),
                    SizedBox(height: 4),
                    SfSmartFlowWordmark(),
                  ],
                ),
              ),
              SfUserAvatar(
                initials: SfUserAvatar.fromName(name),
                size: 40,
                color: SfColors.green,
              ),
            ],
          ),
          const SizedBox(height: 14),
          SfPdfHeroCard(
            strap: 'Approved by Admin',
            title: "You're all set!",
            body:
                'Your account is now active. Sign in to start using SmartFlow.',
            centerBody: true,
            leading: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: SfColors.green.withValues(alpha: 0.12),
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                size: 32,
                color: SfColors.green,
              ),
            ),
          ),
          const SizedBox(height: 14),
          SfSummaryCard(
            title: 'Assigned access',
            trailing: const SfStatusPill(
              label: 'Active',
              tone: SfPillTone.success,
            ),
            rows: [
              MapEntry('Username', request['username']?.toString() ?? ''),
              MapEntry('Role', role),
              MapEntry('Office', '$officeName ($officeCode)'),
              if (request['approved_by'] != null)
                MapEntry('Approved by', request['approved_by'].toString()),
              if (request['approved_at'] != null)
                MapEntry('Approved at', request['approved_at'].toString()),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              const SfStatusPill(label: 'Active', tone: SfPillTone.success),
              SfStatusPill(
                label: 'Clerk · $officeCode',
                tone: SfPillTone.warning,
              ),
            ],
          ),
          const SizedBox(height: 20),
          SfPrimaryButton(
            label: 'Sign In Now',
            onPressed: () => context.go('/login'),
          ),
        ],
      ),
    );
  }
}
