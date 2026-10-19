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
    this.lightPlate = false,
  });

  static const assetPath = 'assets/brand/urbiztondo_seal.png';

  final double size;

  /// Drop shadow for hero / auth placements.
  final bool elevated;

  /// White plate with a plain border (auth header).
  final bool ring;

  /// Soft white disc behind the seal so colors read on navy headers.
  final bool lightPlate;

  @override
  Widget build(BuildContext context) {
    final seal = ClipOval(
      child: ColoredBox(
        color: Colors.white,
        child: Image.asset(
          assetPath,
          width: size,
          height: size,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          errorBuilder: (_, _, _) => _SealFallback(size: size),
        ),
      ),
    );

    Widget child = seal;
    if (lightPlate || ring) {
      final outer = size + (ring ? 14.0 : 10.0);
      child = Container(
        width: outer,
        height: outer,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: ring ? Border.all(color: const Color(0xFFD5DBE3)) : null,
          boxShadow: elevated
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
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
/// Top-right badge — office code; tap opens the account menu (web ENG parity).
class SfOfficeCodeBadge extends StatelessWidget {
  const SfOfficeCodeBadge({
    super.key,
    required this.code,
    this.size = 40,
    this.onTap,
    this.tooltip = 'Account menu',
    this.active = false,
    this.notificationCount,
    this.onNavy = false,
  });

  final String code;
  final double size;
  final VoidCallback? onTap;
  final String tooltip;

  /// Visual highlight when the profile/account area is open (still tappable).
  final bool active;

  /// Optional count (e.g. alerts) shown as a red pill on the badge.
  final int? notificationCount;

  /// Glass style when sitting on the navy shell top bar.
  final bool onNavy;

  @override
  Widget build(BuildContext context) {
    final tappable = onTap != null;
    final count = notificationCount ?? 0;

    return Semantics(
      button: tappable,
      label: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            child: Center(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: size,
                    height: size,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: onNavy
                          ? Colors.white.withValues(alpha: 0.12)
                          : SfColors.navy,
                      border: Border.all(
                        color: active
                            ? (onNavy ? const Color(0xFFE8D9B5) : SfColors.blue)
                            : Colors.white.withValues(
                                alpha: onNavy ? 0.28 : 0.12,
                              ),
                        width: active ? 2 : 1,
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
                  if (count > 0)
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        decoration: const BoxDecoration(
                          color: SfColors.red,
                          borderRadius: BorderRadius.all(Radius.circular(8)),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 14,
                        ),
                        child: Text(
                          count > 9 ? '9+' : '$count',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                          ),
                        ),
                      ),
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

/// Messenger-style header action (e.g. document requests) beside [SfOfficeCodeBadge].
class SfHeaderIconButton extends StatelessWidget {
  const SfHeaderIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.active = false,
    this.notificationCount,
    this.size = 40,
    this.onNavy = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool active;
  final int? notificationCount;
  final double size;

  /// Light glass control for the navy shell top bar.
  final bool onNavy;

  @override
  Widget build(BuildContext context) {
    final count = notificationCount ?? 0;

    return Semantics(
      button: true,
      label: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            child: Center(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: size,
                    height: size,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: onNavy
                          ? Colors.white.withValues(alpha: active ? 0.18 : 0.10)
                          : active
                          ? SfColors.navy.withValues(alpha: 0.08)
                          : SfColors.paper,
                      border: Border.all(
                        color: onNavy
                            ? Colors.white.withValues(
                                alpha: active ? 0.42 : 0.22,
                              )
                            : active
                            ? SfColors.navy.withValues(alpha: 0.35)
                            : SfColors.navy.withValues(alpha: 0.14),
                      ),
                    ),
                    child: Icon(
                      icon,
                      size: 20,
                      color: onNavy ? Colors.white : SfColors.navy,
                    ),
                  ),
                  if (count > 0)
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        decoration: const BoxDecoration(
                          color: SfColors.gold,
                          borderRadius: BorderRadius.all(Radius.circular(8)),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 14,
                        ),
                        child: Text(
                          count > 9 ? '9+' : '$count',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                          ),
                        ),
                      ),
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

class SfSmartFlowWordmark extends StatelessWidget {
  const SfSmartFlowWordmark({
    super.key,
    this.fontSize = 17,
    this.onDark = false,
  });

  final double fontSize;

  final bool onDark;

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
            color: onDark ? Colors.white : SfColors.navy,
            height: 1.1,
          ),
        ),
        Text(
          'Flow',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            color: onDark ? const Color(0xFF9EC0EA) : SfColors.blue,
            height: 1.1,
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
            ? const Border(bottom: BorderSide(color: Color(0x1A0B1F3A)))
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
              border: Border(top: BorderSide(color: SfColors.navy, width: 3)),
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
                  'Republic of the Philippines',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: SfColors.muted,
                  ),
                ),
                const SizedBox(height: 2),
                Text('Municipality of Urbiztondo', style: titleStyle),
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

class SfAuthShell extends StatelessWidget {
  const SfAuthShell({
    super.key,
    required this.strap,
    required this.headline,
    required this.body,
    this.child,
    this.footer,
    this.leading,
    this.showWordmark = true,
  });

  final String strap;
  final String headline;
  final String body;
  final Widget? child;
  final Widget? footer;
  final Widget? leading;
  final bool showWordmark;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    const hPad = 16.0;

    final panel = _AuthPanel(
      strap: strap,
      headline: headline,
      body: body,
      showWordmark: showWordmark,
      child: child,
    );

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
                child: SafeArea(
                  top: false,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(hPad, 12, hPad, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        panel,
                        if (footer != null) ...[
                          const SizedBox(height: 10),
                          footer!,
                        ],
                        const SizedBox(height: 10),
                        const _AuthGovFoot(),
                      ],
                    ),
                  ),
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
      color: const Color(0xFF0B1F3A),
      child: Column(
        children: [
          SizedBox(height: topInset + (leading != null ? 4 : 10)),
          if (leading != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
              child: leading!,
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(20, leading != null ? 2 : 8, 20, 20),
            child: Column(
              children: [
                const SfLguSeal(
                  size: 72,
                  elevated: true,
                  ring: true,
                  lightPlate: true,
                ),
                const SizedBox(height: 10),
                Text(
                  'Municipality of Urbiztondo',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.15,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Province of Pangasinan',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.78),
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Republic of the Philippines',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.7),
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
    this.showWordmark = true,
    this.child,
  });

  final String strap;
  final String headline;
  final String body;
  final bool showWordmark;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final hasBody = body.trim().isNotEmpty;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: SfColors.paper,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x140B1F3A)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F0B1F3A),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  strap,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: SfColors.muted,
                    height: 1.2,
                  ),
                ),
                if (showWordmark) ...[
                  const SizedBox(height: 14),
                  const SfSmartFlowWordmark(fontSize: 32),
                  const SizedBox(height: 10),
                ] else
                  const SizedBox(height: 14),
                Text(
                  headline,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: SfColors.navy,
                    height: 1.25,
                  ),
                ),
                if (hasBody) ...[
                  const SizedBox(height: 8),
                  Text(
                    body,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: SfColors.muted.withValues(alpha: 0.98),
                      height: 1.5,
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
                border: Border(top: BorderSide(color: Color(0x140B1F3A))),
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
              'Sign in with your office account to receive and release folders.',
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
                _GovChip(label: 'QR on the folder'),
                _GovChip(label: 'ENG → BUD → ACC → TRE → MAY'),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Office accounts only. Sign-in is recorded.',
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
  const _GovChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFE8EDF3),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: const Color(0xFFD3DBE4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: SfColors.navy,
        ),
      ),
    );
  }
}

/// Login hero: seal, municipality line, and SmartFlow name.
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
          'Municipality of Urbiztondo, Pangasinan',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
            color: SfColors.muted.withValues(alpha: 0.9),
          ),
        ),
        const SizedBox(height: 8),
        const SfSmartFlowWordmark(fontSize: 34),
        const SizedBox(height: 10),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'Folder tracking for the municipal offices.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: SfColors.muted, height: 1.5),
          ),
        ),
      ],
    );
  }
}

/// White rounded card used for forms, summaries, and grouped content.
class SfFormCard extends StatelessWidget {
  const SfFormCard({
    super.key,
    required this.child,
    this.padding,
    this.flat = false,
  });

  final Widget child;
  final EdgeInsets? padding;

  /// List-row surface: border only, no drop shadow (avoids nested “card on card”).
  final bool flat;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: SfColors.paper,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SfColors.border),
      ),
      child: Material(color: Colors.transparent, child: child),
    );
  }
}

/// Screen heading, shared by operational and oversight pages.
class SfPageTitle extends StatelessWidget {
  const SfPageTitle({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.headlineSmall?.copyWith(color: SfColors.navy),
      ),
      if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
        const SizedBox(height: 5),
        Text(
          subtitle!,
          style: const TextStyle(
            fontSize: 14,
            color: SfColors.muted,
            height: 1.4,
          ),
        ),
      ],
    ],
  );
}

/// Navigation surfaces use the same leading icon, title and trailing chevron.
class SfNavigationRow extends StatelessWidget {
  const SfNavigationRow({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.subtitleColor = SfColors.muted,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final String? subtitle;
  final Color subtitleColor;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: Material(
      color: SfColors.paper,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: SfColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 68),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(icon, size: 22, color: SfColors.blue),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                          color: SfColors.navy,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitle!,
                          style: TextStyle(
                            fontSize: 13,
                            color: subtitleColor,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: SfColors.muted,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// Equal-width metric cells share one quiet surface and separators.
/// Each child supplies its own [Expanded] to keep all role strips aligned.
class SfStatStrip extends StatelessWidget {
  const SfStatStrip({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Material(
    color: SfColors.bg2,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: const BorderSide(color: SfColors.border),
    ),
    clipBehavior: Clip.antiAlias,
    child: IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < children.length; index++) ...[
            if (index > 0)
              const VerticalDivider(
                width: 1,
                thickness: 1,
                indent: 16,
                endIndent: 16,
                color: SfColors.border,
              ),
            children[index],
          ],
        ],
      ),
    ),
  );
}

/// Filled button. Use [navy] on the sign-in screen.
class SfPrimaryButton extends StatefulWidget {
  const SfPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.navy = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final bool navy;

  @override
  State<SfPrimaryButton> createState() => _SfPrimaryButtonState();
}

class _SfPrimaryButtonState extends State<SfPrimaryButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onPressed == null && !widget.loading;
    final radius = BorderRadius.circular(10);
    return AnimatedScale(
      scale: _pressed && !disabled && !widget.loading ? 0.985 : 1,
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeOut,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.loading ? null : widget.onPressed,
          onHighlightChanged: (v) {
            if (!disabled && !widget.loading) {
              setState(() => _pressed = v);
            }
          },
          borderRadius: radius,
          child: Ink(
            decoration: BoxDecoration(
              color: disabled
                  ? const Color(0xFFCBD5E1)
                  : widget.navy
                  ? SfColors.navy
                  : SfColors.blue,
              borderRadius: radius,
            ),
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              alignment: Alignment.center,
              child: widget.loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      widget.label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Low-emphasis text action (Clear form, Back to Home) — never competes with [SfPrimaryButton].
class SfGhostTextButton extends StatelessWidget {
  const SfGhostTextButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: SfColors.muted,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
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
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
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
        if (trailing != null) ...[const SizedBox(width: 12), trailing!],
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
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: SfColors.paper,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x140F172A)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              fontFamily: 'monospace',
              color: color ?? SfColors.navy,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label.toUpperCase(),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: SfColors.muted,
              letterSpacing: 0.4,
            ),
          ),
        ],
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
                        fontSize: 13,
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

/// White list row with an optional trailing widget.
class SfListTile extends StatelessWidget {
  const SfListTile({
    super.key,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    Widget card = SfFormCard(
      padding: EdgeInsets.zero,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
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
                      fontSize: 13,
                      color: SfColors.muted,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
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

    return Padding(padding: const EdgeInsets.only(bottom: 8), child: card);
  }
}

/// Department identity uses one neutral color across offices.
class SfDeptBadge extends StatelessWidget {
  const SfDeptBadge({super.key, required this.label, required this.officeCode});

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
    this.imageUrl,
  });

  final String initials;
  final double size;
  final Color? color;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final c = color ?? SfColors.navy;
    final url = imageUrl?.trim();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: c,
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: url != null && url.isNotEmpty
          ? Image.network(
              url,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _letters(),
            )
          : _letters(),
    );
  }

  Widget _letters() => Center(
    child: Text(
      initials.length > 2 ? initials.substring(0, 2) : initials,
      style: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w800,
        fontSize: size * 0.34,
      ),
    ),
  );

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
          Icon(icon ?? Icons.badge_outlined, size: 16, color: SfColors.blue),
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
              color: SfColors.blue,
              borderRadius: BorderRadius.circular(6),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
        bg = SfColors.blueSoft;
        fg = SfColors.blue;
      case SfPillTone.muted:
        bg = SfColors.bg2;
        fg = SfColors.muted;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}

enum SfPillTone { success, warning, danger, neutral, muted }

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
              ?trailing,
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
    this.onTimeFolders,
    this.unforwardedFolders,
    this.delayedFolders,
  });

  final int onTime;
  final int unforwarded;
  final int delayed;
  final String? monthLabel;

  /// Folder counts shown under each rate when the caller has them.
  final int? onTimeFolders;
  final int? unforwardedFolders;
  final int? delayedFolders;

  static String? _folders(int? count) =>
      count == null ? null : '$count folder${count == 1 ? '' : 's'}';

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
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
            ),
            if (monthLabel != null)
              Text(
                monthLabel!,
                style: const TextStyle(fontSize: 13, color: SfColors.muted),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _rateBox(
              'On time',
              '$onTime%',
              SfColors.green,
              _folders(onTimeFolders),
            ),
            const SizedBox(width: 8),
            _rateBox(
              'Unforwarded',
              '$unforwarded%',
              SfColors.gold,
              _folders(unforwardedFolders),
            ),
            const SizedBox(width: 8),
            _rateBox(
              'Delayed',
              '$delayed%',
              SfColors.red,
              _folders(delayedFolders),
            ),
          ],
        ),
      ],
    );
  }

  Widget _rateBox(String label, String value, Color color, [String? folders]) {
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
                fontSize: 12,
                color: SfColors.muted,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
            if (folders != null) ...[
              const SizedBox(height: 2),
              Text(
                folders,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, color: SfColors.muted),
              ),
            ],
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
                      onPressed:
                          onBack ?? () => Navigator.of(context).maybePop(),
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
/// Optional [actionLabel] + [onAction] = one clear next step (don't stack CTAs).
class SfEmptyState extends StatelessWidget {
  const SfEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;

  @override
  Widget build(BuildContext context) {
    final hasAction = actionLabel != null && onAction != null;
    final hasSecondary =
        secondaryActionLabel != null && onSecondaryAction != null;
    return SfFormCard(
      flat: true,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: SfColors.bg2,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: SfColors.muted, size: 22),
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
                        fontSize: 15,
                        height: 1.3,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 5),
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: SfColors.muted,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (hasAction) ...[
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.start,
              spacing: 8,
              runSpacing: 8,
              children: [
                _EmptyStateButton(label: actionLabel!, onPressed: onAction!),
                if (hasSecondary)
                  _EmptyStateButton(
                    label: secondaryActionLabel!,
                    onPressed: onSecondaryAction!,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyStateButton extends StatelessWidget {
  const _EmptyStateButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: SfColors.blue,
        minimumSize: const Size(48, 44),
        side: BorderSide(color: SfColors.blue.withValues(alpha: 0.35)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

/// Short success toast — Mark IN/OUT, register, approve.
void sfShowSuccessSnack(
  BuildContext context, {
  required String message,
  Color? backgroundColor,
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        message,
        style: const TextStyle(fontWeight: FontWeight.w600, height: 1.3),
      ),
      backgroundColor: backgroundColor ?? SfColors.green,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 3),
      action: actionLabel != null && onAction != null
          ? SnackBarAction(
              label: actionLabel,
              textColor: Colors.white,
              onPressed: onAction,
            )
          : null,
    ),
  );
}
