import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/api_client.dart';
import '../../services/smartflow_api.dart';
import '../../utils/api_error.dart';
import '../../theme/smartflow_theme.dart';
import '../../widgets/sf_page.dart';
import '../../widgets/sf_widgets.dart';
import '../staff/clerk_widgets.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _usernameCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  String? _successMessage;
  String? _devResetCode;
  String? _username;

  @override
  void dispose() {
    _usernameCtrl.dispose();
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

  void _goToReset() {
    if (_username == null) return;
    context.push('/reset-password', extra: {
      'username': _username,
    });
  }

  @override
  Widget build(BuildContext context) {
    return SfPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SfPageBackButton(
            fallbackRoute: '/login',
            hideOnRoleHome: false,
            label: 'Back to Login',
          ),
          const SizedBox(height: 8),
          const SfBrandHeroCard(),
          const SizedBox(height: 24),
          SfFormCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Forgot Password?',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: SfColors.ink,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Enter your username and we\'ll generate a reset code for you.',
                  style: TextStyle(color: SfColors.muted, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _usernameCtrl,
                  autocorrect: false,
                  enabled: _successMessage == null,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    hintText: 'e.g. engineering.staff',
                    prefixIcon: Icon(Icons.person_outline, size: 20),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
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
                        const Icon(
                          Icons.error_outline,
                          size: 16,
                          color: SfColors.red,
                        ),
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
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: SfColors.green.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: SfColors.green.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.check_circle_outline,
                          size: 16,
                          color: SfColors.green,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _successMessage!,
                            style: const TextStyle(
                              color: SfColors.green,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_devResetCode != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: SfColors.blue.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: SfColors.blue.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Your Reset Code (DEV MODE):',
                            style: TextStyle(
                              color: SfColors.muted,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _devResetCode!,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: SfColors.blue,
                              letterSpacing: 4,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Code expires in 1 hour',
                            style: TextStyle(
                              color: SfColors.muted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SfPrimaryButton(
                      label: 'Enter Reset Code',
                      onPressed: _goToReset,
                    ),
                  ],
                ],
                if (_successMessage == null) ...[
                  const SizedBox(height: 18),
                  SfPrimaryButton(
                    label: 'Send Reset Code',
                    loading: _loading,
                    onPressed: _loading ? null : _submit,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
