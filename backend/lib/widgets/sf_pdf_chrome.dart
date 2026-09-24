import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../theme/smartflow_theme.dart';
import 'sf_widgets.dart';

/// PDF module header — kicker · SMARTFLOW · badge (EN / HS / AL).
class SfModuleScreenHeader extends StatelessWidget {
  const SfModuleScreenHeader({
    super.key,
    required this.kicker,
    this.badgeCode,
    this.showProfileBadge = true,
    this.onProfileTap,
  });

  final String kicker;
  final String? badgeCode;
  final bool showProfileBadge;
  final VoidCallback? onProfileTap;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final code = badgeCode ?? user?.officeCode ?? 'EN';

    return Padding(
      padding: const EdgeInsets.only(top: 8, right: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  kicker.toUpperCase(),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.9,
                    color: SfColors.muted.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 4),
                const SfSmartFlowWordmark(),
              ],
            ),
          ),
          if (showProfileBadge) ...[
            const SizedBox(width: 8),
            SfOfficeCodeBadge(
              code: code,
              onTap: onProfileTap ?? () => context.push('/staff/profile'),
            ),
          ],
        ],
      ),
    );
  }
}

/// White intro card with gold step strap (signup, alerts, profile).
class SfPdfHeroCard extends StatelessWidget {
  const SfPdfHeroCard({
    super.key,
    required this.strap,
    required this.title,
    required this.body,
    this.centerBody = false,
    this.leading,
  });

  final String strap;
  final String title;
  final String body;
  final bool centerBody;
  final Widget? leading;

  static const _strapBg = Color(0xFFF8F4EC);
  static const _strapBorder = Color(0xFFD4C4A0);
  static const _strapInk = Color(0xFF6B5340);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: SfColors.paper,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0x0F0F172A)),
        boxShadow: [
          BoxShadow(
            color: SfColors.ink.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(height: 12),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _strapBg,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: _strapBorder),
              ),
              child: Text(
                strap.toUpperCase(),
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                  color: _strapInk,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: centerBody ? TextAlign.center : TextAlign.start,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              height: 1.2,
              color: SfColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            textAlign: centerBody ? TextAlign.center : TextAlign.start,
            style: const TextStyle(
              fontSize: 13,
              color: SfColors.muted,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Step bar for signup (2 form steps, or 3 including approval wait).
class SfSignupStepProgress extends StatelessWidget {
  const SfSignupStepProgress({
    super.key,
    required this.step,
    this.totalSteps = 3,
  });

  /// Current step (1-based).
  final int step;

  /// Usually 2 for the form; 3 on the pending-approval screen.
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    final total = totalSteps.clamp(2, 3);

    Color segColor(int i) {
      if (i < step) return SfColors.green;
      if (i == step) return SfColors.blue;
      return const Color(0x1A0F172A);
    }

    final segments = <Widget>[
      for (var i = 1; i <= total; i++) ...[
        if (i > 1) const SizedBox(width: 6),
        Expanded(child: _Seg(color: segColor(i))),
      ],
    ];

    return Row(
      children: [
        ...segments,
        const SizedBox(width: 10),
        Text(
          '$step / $total',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: SfColors.muted,
          ),
        ),
      ],
    );
  }
}

class _Seg extends StatelessWidget {
  const _Seg({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 6,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

/// Signup top row — CREATE ACCOUNT · SMARTFLOW · + badge.
class SfSignupTopHeader extends StatelessWidget {
  const SfSignupTopHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CREATE ACCOUNT',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.9,
                  color: SfColors.muted.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(height: 4),
              const SfSmartFlowWordmark(fontSize: 18),
            ],
          ),
        ),
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: SfGradients.brandTitle,
          ),
          child: const Icon(Icons.add, color: Colors.white, size: 22),
        ),
      ],
    );
  }
}

/// 2×2 role picker (signup step 2).
class SfRoleSelectGrid extends StatelessWidget {
  const SfRoleSelectGrid({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _RoleTile(
                value: 'staff',
                title: 'Employee',
                subtitle: 'Scan QR · history',
                selected: selected == 'staff',
                onTap: () => onSelect('staff'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _RoleTile(
                value: 'head',
                title: 'Head',
                subtitle: 'Monitor 1 office',
                selected: selected == 'head',
                onTap: () => onSelect('head'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _RoleTile(
                value: 'admin',
                title: 'Accountant',
                subtitle: 'All offices · COA',
                selected: selected == 'admin',
                onTap: () => onSelect('admin'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _RoleTile(
                value: 'admin',
                title: 'Admin',
                subtitle: 'System config',
                selected: selected == 'admin',
                onTap: () => onSelect('admin'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _RoleTile extends StatelessWidget {
  const _RoleTile({
    required this.value,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String value;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SfColors.paper,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? SfColors.blue : const Color(0x140F172A),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: SfColors.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 10,
                  color: SfColors.muted,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// PDF alert document row.
class SfPdfAlertCard extends StatelessWidget {
  const SfPdfAlertCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.pill1,
    required this.pill2,
    this.rule,
    this.showChevron = false,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final Color accent;
  final String pill1;
  final String pill2;
  final String? rule;
  final bool showChevron;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: SfColors.paper,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border(
                left: BorderSide(color: accent, width: 4),
                top: const BorderSide(color: Color(0x140F172A)),
                right: const BorderSide(color: Color(0x140F172A)),
                bottom: const BorderSide(color: Color(0x140F172A)),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color: SfColors.ink,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            subtitle,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: SfColors.muted,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (showChevron)
                      const Padding(
                        padding: EdgeInsets.only(left: 6, top: 2),
                        child: Icon(
                          Icons.chevron_right,
                          size: 20,
                          color: SfColors.muted,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    SfStatusPill(
                      label: pill1,
                      tone: SfPillTone.danger,
                    ),
                    SfStatusPill(
                      label: pill2,
                      tone: SfPillTone.warning,
                    ),
                  ],
                ),
                if (rule != null && rule!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    rule!,
                    style: TextStyle(
                      fontSize: 10,
                      color: SfColors.muted.withValues(alpha: 0.9),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Grey outline button (Look up, Back to Login).
class SfSecondaryOutlineButton extends StatelessWidget {
  const SfSecondaryOutlineButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: SfColors.ink,
        padding: const EdgeInsets.symmetric(vertical: 14),
        side: const BorderSide(color: Color(0x330F172A)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

/// PDF logout row — red left accent.
class SfLogoutCard extends StatelessWidget {
  const SfLogoutCard({super.key, required this.onLogout});

  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SfColors.red.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onLogout,
        borderRadius: BorderRadius.circular(14),
        splashColor: SfColors.red.withValues(alpha: 0.12),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: SfColors.red.withValues(alpha: 0.35)),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Log out',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: SfColors.red,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Sign out and clear local session on this device.',
                style: TextStyle(
                  fontSize: 11,
                  color: SfColors.muted,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lavender scanner preview frame (PDF).
class SfScannerPreviewCard extends StatelessWidget {
  const SfScannerPreviewCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE8EEFF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: SfColors.blue.withValues(alpha: 0.12)),
      ),
      child: child,
    );
  }
}

/// Square gradient avatar (profile card).
class SfSquareGradientAvatar extends StatelessWidget {
  const SfSquareGradientAvatar({
    super.key,
    required this.initials,
    this.size = 52,
  });

  final String initials;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: SfGradients.brandTitle,
      ),
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.32,
        ),
      ),
    );
  }
}

/// Light info banner (pending signup).
class SfInfoBanner extends StatelessWidget {
  const SfInfoBanner({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SfColors.blue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SfColors.blue.withValues(alpha: 0.15)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12.5,
          color: SfColors.ink,
          height: 1.5,
        ),
      ),
    );
  }
}
