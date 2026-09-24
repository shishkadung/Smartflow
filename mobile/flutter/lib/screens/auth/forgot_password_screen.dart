import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/api_client.dart';
import '../../services/smartflow_api.dart';
import '../../utils/api_error.dart';
import '../../theme/smartflow_theme.dart';
import '../../widgets/sf_widgets.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _usernameCtrl = TextEditingController();
  final _resetCodeCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  String? _successMessage;
  String? _devResetCode;
  String? _username;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _resetCodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
      _successMessage = null;
      _devResetCode = null;
    });

    try {
      final api = SmartflowApi(ApiClient());
      final result = await api.forgotPassword(_usernameCtrl.text.trim());

      if (!mounted) return;

      setState(() {
        _successMessage = result['message']?.toString();
        _devResetCode = result['dev_reset_code']?.toString();
        _username = _usernameCtrl.text.trim();
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
      headline: 'Forgot password',
      body:
          'Enter your username and we will send a reset code to your registered email.',
      leading: Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => context.go('/login'),
          style: TextButton.styleFrom(
            foregroundColor: Colors.white.withValues(alpha: 0.85),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          ),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 14),
          label: const Text(
            'Back to sign in',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _usernameCtrl,
            autocorrect: false,
            enabled: _successMessage == null,
            decoration: const InputDecoration(
              labelText: 'Username',
              hintText: 'Enter your username',
              prefixIcon: Icon(Icons.person_outline, size: 20),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                  const Icon(Icons.error_outline, size: 16, color: SfColors.red),
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
          if (_successMessage != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: SfColors.green.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: SfColors.green.withValues(alpha: 0.25),
                ),
              ),
              child: const Column(
                children: [
                  Icon(Icons.email_outlined, color: SfColors.green, size: 32),
                  SizedBox(height: 8),
                  Text(
                    'Check your email',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: SfColors.green,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'We sent a reset code to your registered email address.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: SfColors.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
          if (_devResetCode != null) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _resetCodeCtrl,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: 'Enter reset code',
                hintText: '000000',
                prefixIcon: Icon(Icons.lock_outline, size: 20),
                counterText: '',
              ),
            ),
            const SizedBox(height: 12),
            SfPrimaryButton(
              label: 'Verify & reset password',
              navy: true,
              onPressed: () {
                if (_resetCodeCtrl.text.length == 6) {
                  context.push('/reset-password', extra: {
                    'username': _username,
                    'code': _resetCodeCtrl.text,
                  });
                } else {
                  setState(() => _error = 'Please enter 6-digit code');
                }
              },
            ),
          ],
          if (_successMessage == null) ...[
            const SizedBox(height: 18),
            SfPrimaryButton(
              label: 'Send reset code',
              navy: true,
              loading: _loading,
              onPressed: _loading ? null : _submit,
            ),
          ],
        ],
      ),
    );
  }
}
