import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_client.dart';
import '../../theme/smartflow_theme.dart';
import '../../widgets/sf_widgets.dart';
import '../staff/clerk_widgets.dart';

/// Bottom sheet to update display name, username, and email.
/// Hits POST /users-profile-update.php.
class EditProfileSheet extends StatefulWidget {
  const EditProfileSheet({super.key});

  static Future<bool> show(BuildContext context) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const EditProfileSheet(),
    );
    return result == true;
  }

  @override
  State<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<EditProfileSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _userCtrl;
  late final TextEditingController _emailCtrl;
  late final AppUser _user;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _user = context.read<AuthProvider>().user!;
    _nameCtrl = TextEditingController(text: _user.name);
    _userCtrl = TextEditingController(text: _user.username);
    _emailCtrl = TextEditingController(text: _user.email ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _userCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  String? _validate() {
    final name = _nameCtrl.text.trim();
    final username = _userCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    if (name.isEmpty) return 'Full name is required.';
    if (username.length < 3) return 'Username must be at least 3 characters.';
    if (!RegExp(r'^[a-zA-Z0-9._-]+$').hasMatch(username)) {
      return 'Username may only use letters, numbers, dots, dashes, and underscores.';
    }
    if (email.isEmpty) return 'Email is required.';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  Future<void> _submit() async {
    final problem = _validate();
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final auth = context.read<AuthProvider>();
      final data = await auth.api.updateProfile(
        name: _nameCtrl.text.trim(),
        username: _userCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
      );
      final raw = data['user'];
      if (raw is Map<String, dynamic>) {
        await auth.refreshUser(AppUser.fromJson(raw));
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated'),
          backgroundColor: SfColors.green,
        ),
      );
      Navigator.of(context).pop(true);
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
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  String get _roleLine {
    switch (_user.role) {
      case 'head':
        return 'Department Head';
      case 'admin':
        return 'Municipal Accountant';
      default:
        return 'Clerk';
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final inset = media.viewInsets.bottom;
    final maxH = media.size.height * 0.9;

    return SafeArea(
      top: false,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: inset),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxH),
          child: Container(
            decoration: const BoxDecoration(
              color: SfColors.bg2,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: SfColors.muted.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Edit profile',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: SfColors.navy,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Name, username, and email appear on custody records. Email is used for password reset.',
                    style: TextStyle(
                      fontSize: 12,
                    color: SfColors.muted,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                _label('Full name'),
                const SizedBox(height: 6),
                TextField(
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                _label('Username'),
                const SizedBox(height: 6),
                TextField(
                  controller: _userCtrl,
                  autocorrect: false,
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                _label('Email'),
                const SizedBox(height: 6),
                TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'you@urbiztondo.gov.ph',
                  ),
                  onSubmitted: _loading ? null : (_) => _submit(),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  decoration: BoxDecoration(
                    color: SfColors.navy.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: SfColors.navy.withValues(alpha: 0.08)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _readonlyRow('Role', _roleLine),
                      const SizedBox(height: 6),
                      _readonlyRow(
                        _user.role == 'admin' ? 'Home office' : 'Office',
                        '${_user.officeName} (${_user.officeCode})',
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _user.role == 'admin'
                            ? 'Role and home office are fixed for this municipal account.'
                            : 'Assigned by admin — cannot change here.',
                        style: const TextStyle(fontSize: 11, color: SfColors.muted),
                      ),
                    ],
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  SfErrorBanner(message: _error!),
                ],
                const SizedBox(height: 16),
                SfPrimaryButton(
                  label: _loading ? 'Saving…' : 'Save profile',
                  loading: _loading,
                  onPressed: _loading ? null : _submit,
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _loading ? null : () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: SfColors.muted,
        ),
      );

  Widget _readonlyRow(String label, String value) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 56,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: SfColors.muted, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: SfColors.ink),
            ),
          ),
        ],
      );
}
