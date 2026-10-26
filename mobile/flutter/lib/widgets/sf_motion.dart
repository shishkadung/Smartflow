import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Motion used across the app. Every animation here is short, runs once and is skipped for people who turned animations
/// off in their system settings. None of it delays an action: buttons and dialogs stay usable while it plays, and a
/// "saved" cue is only ever drawn after the server has confirmed the save.
class SfMotion {
  SfMotion._();

  /// Tests switch motion off so a single pump shows the final state; motion tests switch it back on.
  static bool enabled = true;

  static bool reduced(BuildContext context) =>
      !enabled || (MediaQuery.maybeDisableAnimationsOf(context) ?? false);
}

/// Fades and lifts [child] into place once. [index] staggers a list (capped, so a long list never makes anyone wait).
class SfEntrance extends StatelessWidget {
  const SfEntrance({super.key, required this.child, this.index = 0});

  final Widget child;
  final int index;

  static const _step = Duration(milliseconds: 45);
  static const _base = Duration(milliseconds: 260);

  @override
  Widget build(BuildContext context) {
    if (SfMotion.reduced(context)) return child;
    final delay = _step * math.min(index, 8);
    final total = delay + _base;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: total,
      curve: Interval(
        delay.inMilliseconds / total.inMilliseconds,
        1,
        curve: Curves.easeOutCubic,
      ),
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 10),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// Scales [child] in with a small overshoot, once. Used for the check that confirms a saved handoff.
class SfPop extends StatelessWidget {
  const SfPop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (SfMotion.reduced(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Opacity(
        opacity: (t * 2).clamp(0.0, 1.0).toDouble(),
        child: Transform.scale(scale: 0.5 + 0.5 * t, child: child),
      ),
      child: child,
    );
  }
}

/// Draws a vertical line from the top down, once, [index] steps after the first. Used for the route between stops.
class SfGrowDown extends StatelessWidget {
  const SfGrowDown({super.key, required this.child, this.index = 0});

  final Widget child;
  final int index;

  @override
  Widget build(BuildContext context) {
    if (SfMotion.reduced(context)) return child;
    final delay = const Duration(milliseconds: 45) * math.min(index, 8);
    final total = delay + const Duration(milliseconds: 320);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: total,
      curve: Interval(
        delay.inMilliseconds / total.inMilliseconds,
        1,
        curve: Curves.easeOutCubic,
      ),
      builder: (context, t, child) => Transform(
        alignment: Alignment.topCenter,
        transform: Matrix4.diagonal3Values(1, t, 1),
        child: child,
      ),
      child: child,
    );
  }
}

/// Grows a bar up from its baseline, once, [index] bars after the first. Only the paint is scaled; the bar keeps its real
/// height in the layout, so the value it stands for is never changed by the animation.
class SfGrowUp extends StatelessWidget {
  const SfGrowUp({super.key, required this.child, this.index = 0});

  final Widget child;
  final int index;

  @override
  Widget build(BuildContext context) {
    if (SfMotion.reduced(context)) return child;
    final delay = const Duration(milliseconds: 40) * math.min(index, 12);
    final total = delay + const Duration(milliseconds: 480);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: total,
      curve: Interval(
        delay.inMilliseconds / total.inMilliseconds,
        1,
        curve: Curves.easeOutCubic,
      ),
      builder: (context, t, child) => Transform(
        alignment: Alignment.bottomCenter,
        transform: Matrix4.diagonal3Values(1, t, 1),
        child: child,
      ),
      child: child,
    );
  }
}

/// A whole number that counts up to [value] the first time it appears and, later, from what it last showed. [id] names
/// the number so reopening a page does not replay the count. Only pass a number that was actually loaded: an
/// unavailable value must stay a dash, never a count that starts at zero.
class SfCountUp extends StatefulWidget {
  const SfCountUp({
    super.key,
    required this.id,
    required this.value,
    required this.style,
  });

  final String id;
  final int value;
  final TextStyle style;

  @override
  State<SfCountUp> createState() => _SfCountUpState();
}

class _SfCountUpState extends State<SfCountUp> {
  static final Map<String, int> _lastShown = {};

  @override
  void dispose() {
    _lastShown[widget.id] = widget.value;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (SfMotion.reduced(context)) {
      _lastShown[widget.id] = widget.value;
      return Text(widget.value.toString(), style: widget.style);
    }
    final from = _lastShown[widget.id] ?? 0;
    return Semantics(
      label: widget.value.toString(),
      excludeSemantics: true,
      child: TweenAnimationBuilder<int>(
        tween: IntTween(begin: from, end: widget.value),
        duration: from == widget.value
            ? Duration.zero
            : const Duration(milliseconds: 650),
        curve: Curves.easeOutCubic,
        onEnd: () => _lastShown[widget.id] = widget.value,
        builder: (context, n, _) => Text(n.toString(), style: widget.style),
      ),
    );
  }
}
