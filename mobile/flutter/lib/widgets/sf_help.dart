import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/help_guides.dart';
import '../providers/auth_provider.dart';
import '../theme/smartflow_theme.dart';
import '../utils/help_tips_store.dart';

/// Compact ? control for page headers / overview cards.
class SfHelpIconButton extends StatelessWidget {
  const SfHelpIconButton({
    super.key,
    required this.page,
    this.tooltip = 'How to use this page',
  });

  final SfHelpPage page;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: () => showSfHelpSheet(context, page),
      style: IconButton.styleFrom(
        backgroundColor: SfColors.blue.withValues(alpha: 0.10),
        foregroundColor: SfColors.blue,
        minimumSize: const Size(40, 40),
        maximumSize: const Size(40, 40),
        padding: EdgeInsets.zero,
      ),
      icon: const Icon(Icons.help_outline_rounded, size: 22),
    );
  }
}

Future<void> showSfHelpSheet(BuildContext context, SfHelpPage page) {
  final guide = sfHelpGuide(page);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: SfColors.paper,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(ctx).height * 0.85,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: SfColors.rule,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: SfColors.blue.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.menu_book_rounded,
                          color: SfColors.blue,
                          size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        guide.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: SfColors.navy,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  guide.purpose,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: SfColors.ink,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Steps',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    color: SfColors.muted,
                  ),
                ),
                const SizedBox(height: 8),
                ...guide.steps.asMap().entries.map((e) {
                  final n = e.key + 1;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: SfColors.navy.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$n',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: SfColors.navy,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            e.value,
                            style: const TextStyle(
                              fontSize: 13.5,
                              height: 1.4,
                              color: SfColors.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Got it'),
                ),
              ],
            ),
          ),
          ),
        ),
      );
    },
  );
}

Future<void> showSfRoleTipDialog(
  BuildContext context, {
  required SfRoleTip tip,
  bool markSeen = true,
}) async {
  final user = context.read<AuthProvider>().user;
  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          tip.title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: SfColors.navy,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                tip.purpose,
                style: const TextStyle(fontSize: 14, height: 1.45),
              ),
              const SizedBox(height: 12),
              ...tip.bullets.map(
                (b) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('•  ', style: TextStyle(fontSize: 14)),
                      Expanded(
                        child: Text(
                          b,
                          style: const TextStyle(fontSize: 13.5, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Tip: tap the top-bar ? for page help anytime.',
                style: TextStyle(
                  fontSize: 12,
                  color: SfColors.muted.withValues(alpha: 0.95),
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it'),
          ),
        ],
      );
    },
  );
  if (markSeen && user != null) {
    await HelpTipsStore.markRoleTipSeen(user.username);
  }
}

/// Show once per username after first home load.
Future<void> maybeShowSfRoleTip(BuildContext context) async {
  final user = context.read<AuthProvider>().user;
  if (user == null || !context.mounted) return;
  if (await HelpTipsStore.hasSeenRoleTip(user.username)) return;
  if (!context.mounted) return;
  final tip = sfRoleTip(
    role: user.role,
    officeCode: user.officeCode,
    officeName: user.officeName,
  );
  await showSfRoleTipDialog(context, tip: tip);
}

/// Profile action — reset flag and show tip again.
Future<void> showSfRoleTipAgain(BuildContext context) async {
  final user = context.read<AuthProvider>().user;
  if (user == null) return;
  await HelpTipsStore.resetRoleTip(user.username);
  if (!context.mounted) return;
  final tip = sfRoleTip(
    role: user.role,
    officeCode: user.officeCode,
    officeName: user.officeName,
  );
  await showSfRoleTipDialog(context, tip: tip, markSeen: true);
}
