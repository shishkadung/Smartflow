import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/api_client.dart';
import '../../utils/api_error.dart';
import '../../theme/smartflow_theme.dart';
import '../../widgets/sf_widgets.dart';

/// Twin of web LoginPage form column — same strap, fields, links, notes.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _obscure = true;
  AuthProvider? _auth;
  int? _attempt;

  @override
  void dispose() {
    if (_attempt case final attempt?) _auth?.cancelLoginAttempt(attempt);
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    final auth = _auth = context.read<AuthProvider>();
    final attempt = _attempt = auth.beginLoginAttempt();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final installed = await auth.login(
        _userCtrl.text.trim(),
        _passCtrl.text,
        attempt: attempt,
      );
      if (!mounted || !installed || _attempt != attempt) return;
      context.go('/home');
    } on ApiException catch (e) {
      if (mounted && _attempt == attempt) setState(() => _error = e.message);
    } catch (e) {
      if (mounted && _attempt == attempt) {
        setState(() => _error = apiErrorMessage(e));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SfAuthShell(
      strap: 'Office account',
      headline: 'Sign in',
      body: '',
      showWordmark: false,
      leading: Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => context.go('/'),
          style: TextButton.styleFrom(
            foregroundColor: Colors.white.withValues(alpha: 0.85),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          ),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 14),
          label: const Text(
            'Back to welcome',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error == null &&
              context.watch<AuthProvider>().sessionMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                context.read<AuthProvider>().sessionMessage!,
                style: TextStyle(
                  color: context.read<AuthProvider>().sessionMessageIsNotice
                      ? SfColors.green
                      : SfColors.red,
                ),
              ),
            ),
          TextField(
            controller: _userCtrl,
            autocorrect: false,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Username',
              prefixIcon: Icon(Icons.person_outline, size: 20),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _passCtrl,
            obscureText: _obscure,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _loading ? null : _submit(),
            decoration: InputDecoration(
              labelText: 'Password',
              hintText: 'Enter your password',
              suffixIcon: IconButton(
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(
                  _obscure
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: SfColors.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: SfColors.red.withValues(alpha: 0.25)),
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
          const SizedBox(height: 18),
          SfPrimaryButton(
            label: 'Sign in',
            navy: true,
            loading: _loading,
            onPressed: _loading ? null : _submit,
          ),
          const SizedBox(height: 12),
          Text(
            'This sign-in is recorded.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.5,
              color: SfColors.muted.withValues(alpha: 0.9),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 14,
            runSpacing: 8,
            children: [
              GestureDetector(
                onTap: () {
                  // A previous sign-in error does not belong on the screen we come back to.
                  setState(() => _error = null);
                  context.push('/forgot-password');
                },
                child: const Text(
                  'Forgot password?',
                  style: TextStyle(
                    color: SfColors.blue,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  setState(() => _error = null);
                  context.push('/signup');
                },
                child: const Text(
                  'Request access',
                  style: TextStyle(
                    color: SfColors.blue,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() => _error = null);
                  context.push('/signup/pending');
                },
                child: const Text('Check access request'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
