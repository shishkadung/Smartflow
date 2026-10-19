import 'package:flutter/material.dart';

import '../screens/staff/clerk_widgets.dart' show SfErrorBanner;
import '../theme/smartflow_theme.dart';
import '../utils/format_time.dart';

/// Snapshot reads are independent of the account and security controls.
class ProfileSnapshotFeedback extends StatelessWidget {
  const ProfileSnapshotFeedback({
    super.key,
    required this.updatedAt,
    required this.error,
    required this.loading,
    required this.onRetry,
    this.label = 'Office snapshot',
  });

  final DateTime? updatedAt;
  final String? error;
  final bool loading;
  final VoidCallback onRetry;
  final String label;

  @override
  Widget build(BuildContext context) {
    if (updatedAt == null && error == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (error != null) ...[
            SfErrorBanner(
              message: updatedAt == null
                  ? '$label unavailable. $error'
                  : 'Refresh failed. Previously loaded snapshot may be stale. $error',
            ),
            TextButton(
              onPressed: loading ? null : onRetry,
              child: const Text('Retry snapshot'),
            ),
          ],
          if (updatedAt != null)
            Text(
              '${error == null ? 'Updated' : 'Last successful update'} ${formatSmartflowTime(updatedAt!.toIso8601String())}',
              style: const TextStyle(fontSize: 11, color: SfColors.muted),
            ),
          if (loading && updatedAt != null) ...[
            const SizedBox(height: 6),
            const LinearProgressIndicator(minHeight: 2),
            const SizedBox(height: 6),
            const Text(
              'Updating snapshot…',
              style: TextStyle(fontSize: 13, color: SfColors.muted),
            ),
          ],
        ],
      ),
    );
  }
}
