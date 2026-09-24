import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/smartflow_theme.dart';
import '../../widgets/sf_widgets.dart';

/// First screen for signed-out users — ceremonial LGU portal entry.
class GetStartedScreen extends StatelessWidget {
  const GetStartedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SfAuthShell(
      strap: 'Official portal · Authorized users',
      headline: 'Inter-office document tracking',
      body:
          'Secure QR handoffs and custody records for the Municipality of Urbiztondo — for accountability and COA preparation.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _AuthTrustStrip(),
          const SizedBox(height: 18),
          SfPrimaryButton(
            label: 'Sign in',
            navy: true,
            onPressed: () => context.go('/login'),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Need an account? ',
                style: TextStyle(
                  fontSize: 13,
                  color: SfColors.muted.withValues(alpha: 0.95),
                ),
              ),
              GestureDetector(
                onTap: () => context.push('/signup'),
                child: const Text(
                  'Request access',
                  style: TextStyle(
                    color: SfColors.blue,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Three quiet trust signals — hero Get Started only.
class _AuthTrustStrip extends StatelessWidget {
  const _AuthTrustStrip();

  @override
  Widget build(BuildContext context) {
    Widget cell(IconData icon, String label) {
      return Expanded(
        child: Column(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: SfColors.strapBg,
                shape: BoxShape.circle,
                border: Border.all(
                  color: SfColors.strapBorder.withValues(alpha: 0.7),
                ),
              ),
              child: Icon(icon, size: 18, color: SfColors.navy),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: SfColors.ink,
                height: 1.25,
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        cell(Icons.qr_code_2_rounded, 'QR handoffs'),
        cell(Icons.history_edu_rounded, 'Custody log'),
        cell(Icons.verified_outlined, 'COA preparation'),
      ],
    );
  }
}
