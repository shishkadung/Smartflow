import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/api_client.dart';
import '../../services/smartflow_api.dart';
import '../../utils/api_error.dart';
import '../../theme/smartflow_theme.dart';
import '../../widgets/sf_widgets.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key, this.username, this.code});

  final String? username;
  final String? code;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  late final _usernameCtrl = TextEditingController(text: widget.username ?? '');
  late final _codeCtrl = TextEditingController(text: widget.code ?? '');
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  String? _successMessage;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _codeCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
      _successMessage = null;
    });

    final username = _usernameCtrl.text.trim();
    final code = _codeCtrl.text.trim();
    final password = _passwordCtrl.text;
    final confirmPassword = _confirmPasswordCtrl.text;

    if (username.isEmpty || code.isEmpty || password.isEmpty) {
      setState(() {
        _error = 'All fields are required';
        _loading = false;
      });
      return;
    }

    if (password.length < 8) {
      setState(() {
        _error = 'Password must be at least 8 characters';
        _loading = false;
      });
      return;
    }

    if (password != confirmPassword) {
      setState(() {
        _error = 'Passwords do not match';
        _loading = false;
      });
      return;
    }

    try {
      final api = SmartflowApi(ApiClient());
      final result = await api.resetPassword(
        username: username,
        code: code,
        newPassword: password,
      );

      if (!mounted) return;

      setState(() {
        _successMessage = result['message']?.toString() ??
            'Password updated. You can sign in now.';
      });

      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) context.go('/login');
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SfAuthShell(
      strap: 'Account recovery · Official portal',
      headline: 'Set a new password',
      body:
          'Enter the reset code from your email, then choose a new password for your municipal account.',
      leading: Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => context.go('/forgot-password'),
          style: TextButton.styleFrom(
            foregroundColor: Colors.white.withValues(alpha: 0.85),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          ),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 14),
          label: const Text(
            'Back',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ),
      ),
      footer: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: TextButton(
          onPressed: () => context.go('/login'),
          child: const Text(
            'Back to sign in',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_successMessage != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: SfColors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: SfColors.green.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline,
                      color: SfColors.green, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _successMessage!,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: SfColors.ink,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Redirecting to sign in…',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: SfColors.muted),
            ),
          ] else ...[
            TextField(
              controller: _usernameCtrl,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Username',
                hintText: 'Enter your username',
                prefixIcon: Icon(Icons.person_outline, size: 20),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _codeCtrl,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Reset code',
                hintText: 'From your email',
                prefixIcon: Icon(Icons.pin_outlined, size: 20),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordCtrl,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: 'New password',
                hintText: 'At least 8 characters',
                prefixIcon: const Icon(Icons.lock_outline, size: 20),
                suffixIcon: IconButton(
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 20,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmPasswordCtrl,
              obscureText: _obscureConfirm,
              decoration: InputDecoration(
                labelText: 'Confirm password',
                hintText: 'Re-enter your new password',
                prefixIcon: const Icon(Icons.lock_outline, size: 20),
                suffixIcon: IconButton(
                  onPressed: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                  icon: Icon(
                    _obscureConfirm
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 20,
                  ),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: SfColors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: SfColors.red.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 16, color: SfColors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          color: SfColors.red,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),
            SfPrimaryButton(
              label: _loading ? 'Saving…' : 'Save new password',
              loading: _loading,
              onPressed: _loading ? null : _submit,
            ),
          ],
        ],
      ),
    );
  }
}
