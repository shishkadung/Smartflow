import 'package:flutter/material.dart';
import '../utils/document_queue.dart';
import '../utils/format_time.dart';
import '../theme/smartflow_theme.dart';
import '../screens/staff/clerk_widgets.dart';
import 'sf_motion.dart';
import 'sf_widgets.dart';
import 'destination_correction.dart';
import 'folder_contents.dart';

class DocumentJourney extends StatelessWidget {
  const DocumentJourney({super.key, required this.document});
  final Map<String, dynamic> document;
  @override
  Widget build(BuildContext context) {
    final doc = document;
    final steps = List<Map<String, dynamic>>.from(
      doc['journey'] as List? ?? [],
    );
    return SfFormCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Document journey',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            doc['tray'] == 'completed'
                ? 'Completed at ${doc['current_office_name']}.'
                : doc['current_status'] == 'OUT'
                ? 'Awaiting receipt at ${doc['destination_office_name'] ?? 'the receiving office'}. Last sent by ${doc['current_office_name']}.'
                : 'Currently held by ${doc['current_office_name']}.',
          ),
          const SizedBox(height: 16),
          if (steps.isEmpty) const Text('No custody events recorded.'),
          for (var i = 0; i < steps.length; i++)
            _JourneyStep(
              step: steps[i],
              doc: doc,
              index: i,
              isLast: i == steps.length - 1,
            ),
        ],
      ),
    );
  }
}

/// One stop on the journey. The line below the icon is the route to the next stop; stops appear one after another.
class _JourneyStep extends StatelessWidget {
  const _JourneyStep({
    required this.step,
    required this.doc,
    required this.index,
    required this.isLast,
  });

  final Map<String, dynamic> step;
  final Map<String, dynamic> doc;
  final int index;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return SfEntrance(
      index: index,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 20,
              child: Column(
                children: [
                  Icon(
                    step['status'] == 'IN'
                        ? Icons.move_to_inbox_outlined
                        : Icons.forward_to_inbox_outlined,
                    color: step['is_current'] == true
                        ? SfColors.blue
                        : SfColors.muted,
                    size: 20,
                  ),
                  if (!isLast)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: SfGrowDown(
                          index: index,
                          child: Container(
                            width: 2,
                            color: const Color(0xFFD5DCE6),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${step['status'] == 'IN' ? 'Received at' : 'Sent from'} ${step['office_name']}${step['is_current'] == true ? ' · latest' : ''}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    if (step['status'] == 'OUT')
                      Text(
                        'To ${step['destination_office_name'] ?? 'Unspecified office'}',
                      ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        SfPersonAvatar(
                          name: '${step['user_name'] ?? ''}',
                          avatarUrl: step['avatar_url']?.toString(),
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${step['user_name'] ?? ''} · ${formatMovementListTime('${step['scanned_at']}')}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: SfColors.muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      step['is_current'] == true && doc['tray'] == 'completed'
                          ? 'Journey complete'
                          : '${step['duration_kind'] == 'at_office' ? 'Time at office' : 'Time in transit'}: ${elapsedLabel(step['elapsed_hours'])}${step['is_current'] == true ? ' · ongoing' : ''}',
                      style: const TextStyle(fontSize: 13),
                    ),
                    if ('${step['remarks'] ?? ''}'.isNotEmpty)
                      Text(
                        '${step['remarks']}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: SfColors.muted,
                        ),
                      ),
                    if (step['status'] == 'IN') ...[
                      const SizedBox(height: 6),
                      FolderReceiptSummary(
                        receipt:
                            step['contents_receipt'] as Map<String, dynamic>?,
                      ),
                    ],
                    DestinationCorrectionHistory(
                      corrections:
                          step['destination_corrections'] as List? ?? [],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
