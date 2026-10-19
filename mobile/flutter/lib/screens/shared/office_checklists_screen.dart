import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/office_document_types.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/folder_checklists.dart';
import '../../widgets/folder_contents.dart';
import '../../widgets/sf_widgets.dart';

/// Own-office definitions only. Publishing does not register a physical folder.
class OfficeChecklistsScreen extends StatefulWidget {
  const OfficeChecklistsScreen({super.key});

  @override
  State<OfficeChecklistsScreen> createState() => _OfficeChecklistsScreenState();
}

class _OfficeChecklistsScreenState extends State<OfficeChecklistsScreen> {
  final _editor = GlobalKey<FolderInventoryEditorState>();
  String? _type;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final manager = user != null && ['head', 'admin'].contains(user.role);
    if (!manager) {
      return const Center(
        child: Text('Office heads and administrators manage checklists.'),
      );
    }
    final types = documentTypesForOffice(user.officeCode);
    final type = types.contains(_type) ? _type! : types.first;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
      children: [
        const SfPageTitle(
          title: 'Office checklists',
          subtitle: 'Publish attachment requirements for staff in your office.',
        ),
        const SizedBox(height: 16),
        SfFormCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Applies to ${user.officeName}'),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: type,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Document type'),
                items: [
                  for (final item in types)
                    DropdownMenuItem(value: item, child: Text(item)),
                ],
                onChanged: (value) => setState(() => _type = value),
              ),
              const SizedBox(height: 16),
              FolderChecklists(
                editor: _editor,
                type: type,
                management: true,
                onChanged: () {},
              ),
              FolderInventoryEditor(key: _editor, checklistOnly: true),
            ],
          ),
        ),
      ],
    );
  }
}
