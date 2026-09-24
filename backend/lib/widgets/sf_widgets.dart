import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/smartflow_theme.dart';

/// Official Bayan ng Urbiztondo seal — use on auth, masthead, brand lockups.
class SfLguSeal extends StatelessWidget {
  const SfLguSeal({
    super.key,
    this.size = 56,
    this.elevated = true,
    this.ring = false,
  });

  static const assetPath = 'assets/brand/urbiztondo_seal.png';

  final double size;

  /// Drop shadow for hero / auth placements.
  final bool elevated;

  /// Thin gold ceremonial ring (auth header).
  final bool ring;

  @override
  Widget build(BuildContext context) {
    final seal = ClipOval(
      child: Image.asset(
        assetPath,
        width: size,
        height: size,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, __, ___) => _SealFallback(size: size),
      ),
    );

    Widget child = seal;
    if (ring) {
      child = Container(
        width: size + 8,
        height: size + 8,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: SfColors.rule, width: 1.5),
          boxShadow: elevated
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.28),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ]
              : null,
        ),
        child: seal,
      );
    } else if (elevated) {
      child = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: SfColors.ink.withValues(alpha: 0.16),
              blurRadius: 18,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: seal,
      );
    }

    return Semantics(
      label: 'Official seal of the Municipality of Urbiztondo',
      image: true,
      child: child,
    );
  }
}

class _SealFallback extends StatelessWidget {
  const _SealFallback({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: SfGradients.seal,
      ),
      child: Text(
        'LGU',
        style: TextStyle(
          fontSize: size * 0.18,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// White hero card — municipality pill, SmartFlow title, COA blurb (Figma/PDF).
/// Gradient square badge — office code (PDF shows "EN" top-right).
/// Top-right badge — office code label; tap opens Profile (PDF).
class SfOfficeCodeBadge extends StatelessWidget {
  const SfOfficeCodeBadge({
    super.key,
    required this.code,
    this.size = 40,
    this.onTap,
    this.tooltip = 'Profile',
    this.active = false,
  });

  final String code;
  final double size;
  final VoidCallback? onTap;
  final String tooltip;
  /// True when already on Profile — badge is not tappable and looks inactive.
  final bool active;

  @override
  Widget build(BuildContext context) {
    final tappable = onTap != null && !active;

    return Semantics(
      button: tappable,
      label: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: tappable ? onTap : null,
          borderRadius: BorderRadius.circular(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            child: Center(
              child: Opacity(
                opacity: active ? 0.55 : 1,
                child: Container(
                  width: size,
                  height: size,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: active ? SfColors.muted.withValues(alpha: 0.45) : SfColors.navy,
                    border: Border.all(
                      color: active
                          ? Colors.transparent
                          : Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Text(
                    code.toUpperCase(),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: size * 0.32,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// SMART + FLOW wordmark — institutional navy/blue (government portal).
class SfSmartFlowWordmark extends StatelessWidget {
  const SfSmartFlowWordmark({super.key, this.fontSize = 17});

  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          'Smart',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            color: SfColors.navy,
            height: 1.1,
            fontFamily: 'Source Serif 4',
          ),
        ),
        Text(
          'Flow',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            color: SfColors.blue,
            height: 1.1,
            fontFamily: 'Source Serif 4',
          ),
        ),
      ],
    );
  }
}

/// Official LGU masthead — Republic / Municipality / province line.
class SfMunicipalMasthead extends StatelessWidget {
  const SfMunicipalMasthead({
    super.key,
    this.compact = false,
    this.embedded = false,
  });

  final bool compact;

  /// Flat strip for use inside an auth panel (no floating card chrome).
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final sealSize = compact ? 44.0 : 52.0;
    final titleStyle = Theme.of(context).textTheme.titleLarge?.copyWith(
          fontSize: compact ? 15 : 16,
          fontWeight: FontWeight.w700,
          color: SfColors.navy,
          height: 1.15,
        );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: embedded ? 16 : 14,
        vertical: compact ? 10 : 12,
      ),
      decoration: BoxDecoration(
        color: embedded ? SfColors.bg2 : SfColors.paper,
        borderRadius: embedded
            ? BorderRadius.zero
            : const BorderRadius.vertical(bottom: Radius.circular(12)),
        border: embedded
            ? const Border(
                bottom: BorderSide(color: Color(0x1A0B1F3A)),
              )
            : Border.all(color: const Color(0x1A0B1F3A)),
        boxShadow: embedded
            ? null
            : [
                BoxShadow(
                  color: SfColors.ink.withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      foregroundDecoration: embedded
          ? null
          : const BoxDecoration(
              border: Border(
                top: BorderSide(color: SfColors.navy, width: 3),
              ),
            ),
      child: Row(
        children: [
          SfLguSeal(size: sealSize, elevated: !embedded),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'REPUBLIC OF THE PHILIPPINES',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                    color: SfColors.strapInk,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Municipality of Urbiztondo',
                  style: titleStyle,
                ),
                const SizedBox(height: 2),
                Text(
                  'Province of Pangasinan · Document flow & COA support',
                  style: TextStyle(
                    fontSize: 11,
                    color: SfColors.muted.withValues(alpha: 0.95),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Polished mobile auth chrome — ceremonial navy header + single overlapping panel.
class SfAuthShell extends StatelessWidget {
  const SfAuthShell({
    super.key,
    required this.strap,
    required this.headline,
    required this.body,
    this.child,
    this.footer,
    this.leading,
    this.showRouteLine = true,
  });

  final String strap;
  final String headline;
  final String body;
  final Widget? child;
  final Widget? footer;
  final Widget? leading;
  final bool showRouteLine;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: SfColors.bg,
      ),
      child: Scaffold(
        backgroundColor: SfColors.bg,
        resizeToAvoidBottomInset: true,
        body: Column(
          children: [
            _AuthCeremonialHeader(topInset: topInset, leading: leading),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(gradient: SfGradients.pageSky),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight - 20,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Transform.translate(
                              offset: const Offset(0, -22),
                              child: _AuthPanel(
                                strap: strap,
                                headline: headline,
                                body: body,
                                showRouteLine: showRouteLine,
                                child: child,
                              ),
                            ),
                            if (footer != null) ...[
                              const SizedBox(height: 4),
                              footer!,
                            ],
                            const SizedBox(height: 8),
                            const _AuthGovFoot(),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthCeremonialHeader extends StatelessWidget {
  const _AuthCeremonialHeader({required this.topInset, this.leading});

  final double topInset;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(gradient: SfGradients.navyBand),
      child: Column(
        children: [
          SizedBox(height: topInset + (leading != null ? 4 : 10)),
          if (leading != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
              child: leading!,
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(20, leading != null ? 2 : 8, 20, 34),
            child: Column(
              children: [
                const SfLguSeal(size: 78, elevated: true, ring: true),
                const SizedBox(height: 14),
                const Text(
                  'REPUBLIC OF THE PHILIPPINES',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.35,
                    color: Color(0xFFD4C4A0),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Municipality of Urbiztondo',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.15,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Province of Pangasinan',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Colors.white.withValues(alpha: 0.74),
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  width: 56,
                  height: 2.5,
                  decoration: BoxDecoration(
                    color: SfColors.rule.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthPanel extends StatelessWidget {
  const _AuthPanel({
    required this.strap,
    required this.headline,
    required this.body,
    required this.showRouteLine,
    this.child,
  });

  final String strap;
  final String headline;
  final String body;
  final bool showRouteLine;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: SfColors.paper,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x140B1F3A)),
        boxShadow: [
          BoxShadow(
            color: SfColors.ink.withValues(alpha: 0.12),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(height: 3, color: SfColors.rule),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  strap.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    color: SfColors.strapInk,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: 36,
                  height: 2,
                  color: SfColors.rule,
                ),
                const SizedBox(height: 14),
                const SfSmartFlowWordmark(fontSize: 30),
                const SizedBox(height: 8),
                Text(
                  headline,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: SfColors.navy,
                        height: 1.25,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: SfColors.muted.withValues(alpha: 0.98),
                    height: 1.5,
                  ),
                ),
                if (showRouteLine) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: SfColors.strapBg.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: SfColors.strapBorder.withValues(alpha: 0.65),
                      ),
                    ),
                    child: const Text(
                      'ENG  ·  HR  ·  BUD  ·  ACC  ·  TRE  ·  MAY',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                        color: SfColors.strapInk,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
              ],
            ),
          ),
          if (child != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              decoration: const BoxDecoration(
                color: Color(0xFFF7F9FC),
                border: Border(
                  top: BorderSide(color: Color(0x140B1F3A)),
                ),
              ),
              child: child,
            ),
        ],
      ),
    );
  }
}

class _AuthGovFoot extends StatelessWidget {
  const _AuthGovFoot();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text.rich(
        TextSpan(
          style: TextStyle(
            fontSize: 11.5,
            height: 1.45,
            color: SfColors.muted.withValues(alpha: 0.88),
          ),
          children: const [
            TextSpan(
              text: 'SmartFlow',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: SfColors.navy,
              ),
            ),
            TextSpan(
              text:
                  ' records custody events for municipal audit support. It does not approve disbursements or payments.',
            ),
          ],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class SfDottedDivider extends StatelessWidget {
  const SfDottedDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        const dash = 4.0;
        const gap = 5.0;
        final n = (c.maxWidth / (dash + gap)).floor();
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(n, (_) {
            return Container(
              width: dash,
              height: 1,
              margin: const EdgeInsets.only(right: gap),
              color: SfColors.muted.withValues(alpha: 0.35),
            );
          }),
        );
      },
    );
  }
}

class SfBrandHeroCard extends StatelessWidget {
  const SfBrandHeroCard({super.key, this.trailingInset = 0});

  /// Extra right padding when an avatar overlaps the card (dashboard).
  final double trailingInset;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: SfColors.paper,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x1A0B1F3A)),
        boxShadow: [
          BoxShadow(
            color: SfColors.ink.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      foregroundDecoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
        border: Border(top: BorderSide(color: SfColors.navy, width: 3)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.fromLTRB(18, 16, 18 + trailingInset, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: SfColors.strapBg,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: SfColors.strapBorder),
              ),
              child: const Text(
                'OFFICIAL PORTAL · AUTHORIZED USERS',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.7,
                  color: SfColors.strapInk,
                  height: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const SfSmartFlowWordmark(fontSize: 28),
            const SizedBox(height: 8),
            Text(
              'Secure sign-in',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: SfColors.navy,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Inter-office document tracking and custody records for the Municipality of Urbiztondo. Same secured QR verification across offices.',
              style: TextStyle(
                fontSize: 13,
                color: SfColors.muted.withValues(alpha: 0.95),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: const [
                _GovChip(label: 'HMAC-signed QR', gold: true),
                _GovChip(label: 'ENG → BUD → ACC → TRE → MAY'),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Authorized personnel only. Access is logged for accountability and COA review.',
              style: TextStyle(
                fontSize: 11,
                color: SfColors.muted.withValues(alpha: 0.9),
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GovChip extends StatelessWidget {
  const _GovChip({required this.label, this.gold = false});

  final String label;
  final bool gold;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: gold ? SfColors.strapBg : const Color(0xFFE8EEF8),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: gold ? SfColors.strapBorder : const Color(0x332564EB),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: gold ? SfColors.strapInk : SfColors.navy,
        ),
      ),
    );
  }
}

/// Login hero with SmartFlow gradient title and municipality strap line.
class SfBrandLockup extends StatelessWidget {
  const SfBrandLockup({super.key, this.showSeal = true});

  final bool showSeal;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (showSeal) const SfLguSeal(size: 72, elevated: true, ring: true),
        const SizedBox(height: 18),
        Text(
          'MUNICIPALITY OF URBIZTONDO · PANGASINAN',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: SfColors.muted.withValues(alpha: 0.9),
          ),
        ),
        const SizedBox(height: 8),
        const SfSmartFlowWordmark(fontSize: 34),
        const SizedBox(height: 10),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'Internal document tracking and COA compliance support for municipal offices.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: SfColors.muted,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

/// White rounded card used for forms, summaries, and grouped content.
class SfFormCard extends StatelessWidget {
  const SfFormCard({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: SfColors.paper,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x1A0B1F3A)),
        boxShadow: [
          BoxShadow(
            color: SfColors.ink.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Gradient primary CTA. Use [navy] on auth screens for a calmer LGU look.
class SfPrimaryButton extends StatelessWidget {
  const SfPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.navy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final bool navy;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null && !loading;
    final radius = BorderRadius.circular(12);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: loading ? null : onPressed,
        borderRadius: radius,
        child: Ink(
          decoration: BoxDecoration(
            gradient: disabled || navy ? null : SfGradients.primaryBtn,
            color: disabled
                ? const Color(0xFFCBD5E1)
                : navy
                    ? SfColors.navy
                    : null,
            borderRadius: radius,
            boxShadow: disabled
                ? null
                : [
                    BoxShadow(
                      color: (navy ? SfColors.navy : SfColors.blue)
                          .withValues(alpha: navy ? 0.22 : 0.28),
                      blurRadius: navy ? 12 : 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
          ),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 15),
            alignment: Alignment.center,
            child: loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// "SMARTFLOW" eyebrow + big title + optional subtitle/trailing.
class SfHeader extends StatelessWidget {
  const SfHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.eyebrow = 'SMARTFLOW',
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final String eyebrow;

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
                eyebrow.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                  color: SfColors.muted.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: SfColors.ink,
                  height: 1.2,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle!,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: SfColors.muted,
                    height: 1.45,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 12),
          trailing!,
        ],
      ],
    );
  }
}

/// Compact stat card (number on top, label below). Used in dashboards.
class SfStatCard extends StatelessWidget {
  const SfStatCard({
    super.key,
    required this.value,
    required this.label,
    this.color,
  });

  final String value;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: SfColors.paper,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0x140F172A)),
          boxShadow: [
            BoxShadow(
              color: SfColors.ink.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                fontFamily: 'monospace',
                color: color ?? SfColors.blue,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label.toUpperCase(),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: SfColors.muted,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tap card with icon tile + title + sublabel + chevron. Used in dashboards.
class SfQuickAction extends StatelessWidget {
  const SfQuickAction({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.iconColor,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SfColors.paper,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0x140F172A)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: (iconColor ?? SfColors.blue).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor ?? SfColors.blue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: SfColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
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
              Icon(
                Icons.chevron_right,
                color: SfColors.muted.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// White list row with optional left accent stripe + trailing widget.
class SfListTile extends StatelessWidget {
  const SfListTile({
    super.key,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.accent,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;
  final Color? accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final stripe = accent ?? const Color(0x140F172A);
    final stripeWidth = accent != null ? 4.0 : 1.0;

    Widget card = SfFormCard(
      padding: EdgeInsets.zero,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border(
            left: BorderSide(color: stripe, width: stripeWidth),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.isNotEmpty ? title : '—',
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
                      fontSize: 11.5,
                      color: SfColors.muted,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing!,
            ],
          ],
        ),
      ),
    );

    if (onTap != null) {
      card = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: card,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: card,
    );
  }
}

/// Department code pill (ENG / HR / BUD / ACC) coloured per office.
class SfDeptBadge extends StatelessWidget {
  const SfDeptBadge({
    super.key,
    required this.label,
    required this.officeCode,
  });

  final String label;
  final String officeCode;

  @override
  Widget build(BuildContext context) {
    final c = SfColors.dept(officeCode);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: c,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          '${officeCode.toUpperCase()} · $label',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

/// Circular avatar with initials. Used on signup pending/approved + profile.
class SfUserAvatar extends StatelessWidget {
  const SfUserAvatar({
    super.key,
    required this.initials,
    this.size = 56,
    this.color,
  });

  final String initials;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? SfColors.blue;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: c,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: c.withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Center(
        child: Text(
          initials.length > 2 ? initials.substring(0, 2) : initials,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: size * 0.34,
          ),
        ),
      ),
    );
  }

  static String fromName(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}

/// Session strip ("Clerk session · Engineering").
class SfSessionChip extends StatelessWidget {
  const SfSessionChip({super.key, required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: SfColors.paper,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x140F172A)),
      ),
      child: Row(
        children: [
          Icon(
            icon ?? Icons.badge_outlined,
            size: 16,
            color: SfColors.blue,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: SfColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Two horizontally-aligned shortcut buttons (e.g., "Open Scanner / View Alerts").
class SfShortcutRow extends StatelessWidget {
  const SfShortcutRow({super.key, required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: left),
        const SizedBox(width: 10),
        Expanded(child: right),
      ],
    );
  }
}

/// Compact filled/outline button used inside [SfShortcutRow].
class SfShortcutButton extends StatelessWidget {
  const SfShortcutButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.filled = true,
  });

  final String label;
  final VoidCallback onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    if (filled) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Ink(
            decoration: BoxDecoration(
              gradient: SfGradients.primaryBtn,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: SfColors.blue.withValues(alpha: 0.28),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 13),
              child: Center(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: SfColors.blue,
        side: const BorderSide(color: Color(0x331D4ED8)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(vertical: 13),
      ),
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }
}

/// Small status pill (Pending / Active / Overdue / Unconfirmed).
class SfStatusPill extends StatelessWidget {
  const SfStatusPill({
    super.key,
    required this.label,
    this.tone = SfPillTone.neutral,
  });

  final String label;
  final SfPillTone tone;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    switch (tone) {
      case SfPillTone.success:
        bg = SfColors.green.withValues(alpha: 0.14);
        fg = const Color(0xFF15803D);
      case SfPillTone.warning:
        bg = SfColors.gold.withValues(alpha: 0.2);
        fg = const Color(0xFFB45309);
      case SfPillTone.danger:
        bg = SfColors.red.withValues(alpha: 0.12);
        fg = SfColors.red;
      case SfPillTone.neutral:
        bg = SfColors.blue.withValues(alpha: 0.1);
        fg = SfColors.blue;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}

enum SfPillTone { success, warning, danger, neutral }

/// Key/value summary card (Name / Username / Office / Role table).
class SfSummaryCard extends StatelessWidget {
  const SfSummaryCard({
    super.key,
    required this.title,
    required this.rows,
    this.trailing,
  });

  final String title;
  final List<MapEntry<String, String>> rows;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return SfFormCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 12),
          ...rows.map(
            (e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      e.key,
                      style: const TextStyle(
                        fontSize: 12,
                        color: SfColors.muted,
                      ),
                    ),
                  ),
                  Flexible(
                    child: Text(
                      e.value,
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compliance percentage tiles (On time / Unforwarded / Delayed).
class SfComplianceRates extends StatelessWidget {
  const SfComplianceRates({
    super.key,
    required this.onTime,
    required this.unforwarded,
    required this.delayed,
    this.monthLabel,
  });

  final int onTime;
  final int unforwarded;
  final int delayed;
  final String? monthLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Compliance rates',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
            if (monthLabel != null)
              Text(
                monthLabel!,
                style: const TextStyle(
                  fontSize: 11,
                  color: SfColors.muted,
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _rateBox('On time', '$onTime%', SfColors.green),
            const SizedBox(width: 8),
            _rateBox('Unforwarded', '$unforwarded%', SfColors.gold),
            const SizedBox(width: 8),
            _rateBox('Delayed', '$delayed%', SfColors.red),
          ],
        ),
      ],
    );
  }

  Widget _rateBox(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: SfColors.paper,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0x140F172A)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10,
                color: SfColors.muted,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Detail/sub-page chrome with back button and big header.
class SfSubPage extends StatelessWidget {
  const SfSubPage({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.onBack,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SfColors.bg,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: SfGradients.pageSky),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 20, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                      onPressed: onBack ??
                          () => Navigator.of(context).maybePop(),
                    ),
                    Expanded(
                      child: SfHeader(title: title, subtitle: subtitle),
                    ),
                  ],
                ),
              ),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

/// Empty-state placeholder for empty queues / no alerts.
class SfEmptyState extends StatelessWidget {
  const SfEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: SfColors.blue.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: SfColors.blue, size: 28),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: SfColors.muted,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
