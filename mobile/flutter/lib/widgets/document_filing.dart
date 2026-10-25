import 'package:flutter/material.dart';

/// Filing ends active processing. Review the same custody snapshot that will be submitted.
Future<bool> showDocumentFilingConfirmation(
  BuildContext context,
  Map<String, dynamic> document,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: const Text('File this folder?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${document['title'] ?? document['id']}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              '${document['id']} · At ${document['current_office_name'] ?? 'your office'}',
            ),
            const SizedBox(height: 12),
            const Text(
              'Confirm the work on this physical folder is complete. Filing ends active processing; its tracking label and custody history remain available.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep active'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Confirm filing'),
          ),
        ],
      ),
    ) ==
    true;
