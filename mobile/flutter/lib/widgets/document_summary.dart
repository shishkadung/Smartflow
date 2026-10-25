import 'package:flutter/material.dart';
import '../theme/smartflow_theme.dart';
import '../utils/format_time.dart';
import 'sf_widgets.dart';
import 'folder_contents.dart';

class DocumentStatus extends StatelessWidget {
  const DocumentStatus({super.key, required this.document});
  final Map<String, dynamic> document;

  @override
  Widget build(BuildContext context) {
    final completed = document['tray'] == 'completed';
    final status = document['current_status'];
    return SfStatusPill(
      label: completed
          ? 'Completed'
          : document['tray'] == 'incoming'
          ? 'Awaiting receipt'
          : status == 'OUT'
          ? 'Forwarded'
          : status == 'IN'
          ? 'In office'
          : 'Registered',
      tone: completed || status == 'IN'
          ? SfPillTone.success
          : status == 'OUT'
          ? SfPillTone.warning
          : SfPillTone.neutral,
    );
  }
}

/// Consistent identity, custody and metadata for details and registration.
class DocumentSummary extends StatelessWidget {
  const DocumentSummary({
    super.key,
    required this.document,
    this.showCustody = true,
  });
  final Map<String, dynamic> document;
  final bool showCustody;

  @override
  Widget build(BuildContext context) {
    final doc = document;
    final metadata = <String, String>{
      'Type': '${doc['type'] ?? '—'}',
      'Reference': '${doc['reference_no'] ?? '—'}',
      'Origin': '${doc['origin_office_name'] ?? '—'}',
      if (showCustody && doc['last_scanned_at'] != null)
        'Last movement': formatMovementListTime(
          doc['last_scanned_at'].toString(),
        ),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${doc['title']}',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontSize: 22, height: 1.3),
        ),
        const SizedBox(height: 8),
        Text(
          '${doc['id']}',
          style: const TextStyle(fontSize: 13, color: SfColors.muted),
        ),
        const SizedBox(height: 14),
        if (showCustody) ...[
          Text(
            doc['current_status'] == 'OUT'
                ? 'Sent from ${doc['current_office_name'] ?? 'an office'} to ${doc['destination_office_name'] ?? 'the receiving office'} · receipt not recorded'
                : 'At ${doc['current_office_name'] ?? 'an unrecorded office'}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              DocumentStatus(document: doc),
              if (doc['is_overdue'] == true && doc['tray'] != 'completed')
                const SfStatusPill(label: 'Overdue', tone: SfPillTone.danger),
            ],
          ),
        ],
        if (doc['due_at_display'] != null) ...[
          const SizedBox(height: 8),
          Text(
            'Deadline: ${doc['due_at_display']}',
            style: TextStyle(
              fontSize: 14,
              color:
                  showCustody &&
                      doc['is_overdue'] == true &&
                      doc['tray'] != 'completed'
                  ? SfColors.red
                  : SfColors.ink,
            ),
          ),
        ],
        const SizedBox(height: 18),
        for (final entry in metadata.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 104,
                  child: Text(
                    entry.key,
                    style: const TextStyle(fontSize: 14, color: SfColors.muted),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    entry.value,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        FolderContentsSummary(document: doc),
      ],
    );
  }
}
