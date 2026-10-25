import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/api_client.dart';
import '../../services/smartflow_api.dart';
import '../../theme/smartflow_theme.dart';
import '../../utils/api_error.dart';
import '../../widgets/sf_account_menu.dart';
import '../../widgets/sf_widgets.dart';
import '../staff/clerk_widgets.dart';

/// Shown after signing in with an administrator-issued temporary password.
/// The server refuses every other action until the password is replaced.
class ForcedPasswordChangeScreen extends StatefulWidget {
  const ForcedPasswordChangeScreen({super.key});

  @override
  State<ForcedPasswordChangeScreen> createState() =>
      _ForcedPasswordChangeScreenState();
}

class _ForcedPasswordChangeScreenState
    extends State<ForcedPasswordChangeScreen> {
  late final AuthProvider _auth;
  late final Object _identity;
  late final SmartflowApi _api;
  late final String? _token;
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _show = false;
  bool _loading = false;
  String? _error;

  bool get _current => mounted && _auth.sessionIdentity == _identity;

  @override
  void initState() {
    super.initState();
    _auth = context.read<AuthProvider>();
    _identity = _auth.sessionIdentity;
    _api = _auth.api;
    _token = _auth.token;
  }

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  String? _validate() {
    final current = _currentCtrl.text;
    final next = _newCtrl.text;
    if (current.isEmpty) return 'Enter the temporary password you were given.';
    if (next.length < 8) return 'New password must be at least 8 characters.';
    if (next == current) {
      return 'Choose a new password that is different from the temporary one.';
    }
    if (next != _confirmCtrl.text) {
      return 'New password and confirmation do not match.';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_current || _auth.loggingOut || _loading) return;
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
      await _api.changePassword(
        currentPassword: _currentCtrl.text,
        newPassword: _newCtrl.text,
      );
      // The server ends every session on a password change, so sign in again.
      if (_token != null) {
        await _auth.endSession(
          _token,
          message: 'Password changed. Sign in again with your new password.',
          notice: true,
        );
      }
    } on ApiException catch (e) {
      if (_current) setState(() => _error = e.message);
    } catch (e) {
      if (_current) setState(() => _error = apiErrorMessage(e));
    } finally {
      if (_current) setState(() => _loading = false);
    }
  }

  Future<void> _signOut() async {
    if (!_current || _auth.loggingOut || _loading) return;
    await sfLogout(context);
  }

  @override
  Widget build(BuildContext context) {
    final name = _auth.user?.name ?? '';
    return Scaffold(
      backgroundColor: SfColors.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Choose a new password',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${name.isEmpty ? 'Your' : '$name, your'} administrator issued a temporary password. '
                    'Replace it to continue. You will sign in again with the new password.',
                    style: const TextStyle(
                      fontSize: 13,
                      color: SfColors.muted,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _currentCtrl,
                    obscureText: !_show,
                    autofocus: true,
                    enabled: !_loading,
                    decoration: const InputDecoration(
                      labelText: 'Temporary password',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _newCtrl,
                    obscureText: !_show,
                    enabled: !_loading,
                    decoration: const InputDecoration(
                      labelText: 'New password',
                      helperText: 'At least 8 characters.',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _confirmCtrl,
                    obscureText: !_show,
                    enabled: !_loading,
                    decoration: InputDecoration(
                      labelText: 'Confirm new password',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        tooltip: _show ? 'Hide passwords' : 'Show passwords',
                        icon: Icon(
                          _show
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 18,
                        ),
                        onPressed: () => setState(() => _show = !_show),
                      ),
                    ),
                    onSubmitted: _loading ? null : (_) => _submit(),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    SfErrorBanner(message: _error!),
                  ],
                  const SizedBox(height: 16),
                  SfPrimaryButton(
                    label: _loading ? 'Saving…' : 'Save new password',
                    loading: _loading,
                    onPressed: _loading ? null : _submit,
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _loading ? null : _signOut,
                    child: const Text('Sign out'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
