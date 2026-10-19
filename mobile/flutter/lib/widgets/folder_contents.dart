import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/smartflow_theme.dart';
import '../utils/format_time.dart';

List<Map<String, dynamic>> folderItems(Map<String, dynamic>? inventory) =>
    List<Map<String, dynamic>>.from(inventory?['items'] as List? ?? []);

String _differenceLabel(Map<String, dynamic> item) {
  final registered = item['registered_pages'] as num?;
  if (registered == null) return '';
  final difference = (item['pages'] as num) - registered;
  if (difference == 0) return '';
  return ' · ${difference.abs().toInt()} ${difference < 0 ? 'pages missing' : 'extra pages'}';
}

class FolderContentsSummary extends StatelessWidget {
  const FolderContentsSummary({super.key, required this.document});
  final Map<String, dynamic> document;
  @override
  Widget build(BuildContext context) {
    final inventory = document['folder_inventory'] as Map<String, dynamic>?;
    if (inventory == null) {
      return const Text(
        'Contents not recorded for this folder.',
        style: TextStyle(fontSize: 13, color: SfColors.muted),
      );
    }
    final receipt =
        document['current_contents_receipt'] as Map<String, dynamic>?;
    final status = document['contents_status'] ?? inventory['status'];
    final checked = receipt ?? inventory;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        Text(
          status == 'incomplete'
              ? 'Incomplete contents'
              : status == 'discrepancy'
              ? 'Contents discrepancy recorded'
              : receipt == null
              ? 'Contents declared complete'
              : 'Contents checked complete',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: status == 'complete' ? SfColors.green : SfColors.red,
          ),
        ),
        Text(
          '${inventory['total_pages']} registered pages${receipt == null ? '' : ' · ${receipt['total_pages']} last received'}',
        ),
        for (final item in folderItems(checked))
          Text(
            '${item['name']}: ${receipt == null ? '${item['pages']} pages' : '${item['registered_pages']} registered → ${item['pages']} received'}${_differenceLabel(item)}${item['required'] == true && item['pages'] == 0 ? ' · required item missing' : ''}',
            style: const TextStyle(fontSize: 13),
          ),
        if ('${receipt?['reason'] ?? ''}'.isNotEmpty)
          Text('${receipt!['reason']}', style: const TextStyle(fontSize: 13)),
        if (receipt?['checked_at'] != null)
          Text(
            'Checked by ${receipt?['checked_by'] ?? 'Recorded receiver'} · ${receipt?['office_name'] ?? ''}\n${formatMovementListTime(receipt!['checked_at'].toString())}',
            style: const TextStyle(fontSize: 13, color: SfColors.muted),
          ),
      ],
    );
  }
}

/// Counts recorded for this particular receipt, rather than the latest receipt.
class FolderReceiptSummary extends StatelessWidget {
  const FolderReceiptSummary({super.key, required this.receipt});
  final Map<String, dynamic>? receipt;

  @override
  Widget build(BuildContext context) {
    final recorded = receipt;
    if (recorded == null) {
      return const Text(
        'Contents not recorded for this receipt.',
        style: TextStyle(fontSize: 13, color: SfColors.muted),
      );
    }
    final status = recorded['status'];
    final registered = recorded['registered_total_pages'];
    final received = recorded['total_pages'];
    final reason = '${recorded['reason'] ?? ''}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          status == 'complete'
              ? 'Receipt contents checked complete'
              : status == 'incomplete'
              ? 'Receipt contents incomplete'
              : status == 'discrepancy'
              ? 'Receipt contents discrepancy recorded'
              : 'Recorded receipt contents',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: status == 'complete'
                ? SfColors.green
                : status == 'incomplete' || status == 'discrepancy'
                ? SfColors.red
                : SfColors.muted,
          ),
        ),
        Text(
          [
            if (registered is num) '$registered registered pages',
            if (received is num) '$received received pages',
            if (registered is! num && received is! num)
              'Page totals not recorded for this receipt.',
          ].join(' · '),
          style: const TextStyle(fontSize: 13),
        ),
        for (final item in folderItems(recorded))
          Text(
            '${item['name'] ?? 'Recorded item'}: ${item['registered_pages'] is num ? '${item['registered_pages']} registered → ' : ''}${item['pages'] is num ? '${item['pages']} received' : 'received count not recorded'}${item['pages'] is num ? _differenceLabel(item) : ''}${item['required'] == true && item['pages'] == 0 ? ' · required item missing' : ''}',
            style: const TextStyle(fontSize: 13),
          ),
        if (reason.trim().isNotEmpty)
          Text(reason, style: const TextStyle(fontSize: 13)),
      ],
    );
  }
}

class FolderInventoryEditor extends StatefulWidget {
  const FolderInventoryEditor({
    super.key,
    this.enabled = true,
    this.onChanged,
    this.checklistOnly = false,
    this.showIntroduction = true,
  });
  final bool enabled;
  final VoidCallback? onChanged;

  /// Definition editing never asks a manager to attest to physical custody.
  final bool checklistOnly;

  /// A surrounding section can supply the heading and counting guidance.
  final bool showIntroduction;
  @override
  State<FolderInventoryEditor> createState() => FolderInventoryEditorState();
}

class _Attachment {
  final name = TextEditingController();
  final pages = TextEditingController();
  bool required = true;
  void dispose() {
    name.dispose();
    pages.dispose();
  }
}

class FolderInventoryEditorState extends State<FolderInventoryEditor> {
  final _main = TextEditingController();
  final _attachments = <_Attachment>[];
  bool _confirmed = false;
  String? _error;
  int? _pages(String value) {
    final count = int.tryParse(value.trim());
    return count != null && count >= 0 && count <= 999 ? count : null;
  }

  bool get dirty =>
      _main.text.isNotEmpty || _attachments.isNotEmpty || _confirmed;
  Map<String, dynamic> get draft => {
    'items': [
      {'name': 'Main document', 'pages': _main.text, 'required': true},
      for (final row in _attachments)
        {
          'name': row.name.text,
          'pages': row.pages.text,
          'required': row.required,
        },
    ],
  };
  void restore(Map<String, dynamic> value) {
    clear();
    final items = folderItems(value);
    if (items.isEmpty) return;
    _main.text = '${items.first['pages'] ?? ''}';
    for (final item in items.skip(1).take(20)) {
      final row = _Attachment();
      row.name.text = '${item['name'] ?? ''}';
      row.pages.text = '${item['pages'] ?? ''}';
      row.required = item['required'] == true;
      _attachments.add(row);
    }
    setState(() => _confirmed = false);
  }

  void clear() {
    _main.clear();
    for (final row in _attachments) {
      row.dispose();
    }
    setState(() {
      _attachments.clear();
      _confirmed = false;
      _error = null;
    });
  }

  Map<String, dynamic>? validateAndRead() {
    final main = _pages(_main.text);
    final names = <String>{'main document'};
    String? message;
    if (main == null || main < 1) {
      message = 'Enter the actual main-document pages (1–999).';
    }
    for (final row in _attachments) {
      final name = row.name.text.trim();
      if (name.isEmpty || name.length > 100 || !names.add(name.toLowerCase())) {
        message ??=
            'Give each attachment a distinct name (up to 100 characters).';
      }
      if (_pages(row.pages.text) == null) {
        message ??=
            'Enter 0–999 pages for each attachment. Use 0 when it is missing.';
      }
    }
    if (!_confirmed) {
      message ??= 'Confirm you hold the folder and counted its contents.';
    }
    final items = <Map<String, dynamic>>[
      {'name': 'Main document', 'pages': main, 'required': true},
      for (final row in _attachments)
        {
          'name': row.name.text.trim(),
          'pages': _pages(row.pages.text),
          'required': row.required,
        },
    ];
    if (message == null &&
        items.fold<int>(0, (sum, item) => sum + (item['pages'] as int)) >
            9999) {
      message = 'The total may not exceed 9999 pages.';
    }
    setState(() => _error = message);
    if (message != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 200),
        alignment: 0.2,
      );
      return null;
    }
    return {'items': items, 'count_confirmed': true};
  }

  List<Map<String, dynamic>>? validateChecklistAndRead() {
    final names = <String>{'main document'};
    String? message;
    if (_attachments.isEmpty) {
      message = 'Add at least one attachment before publishing.';
    }
    for (final row in _attachments) {
      final name = row.name.text.trim();
      if (name.isEmpty || name.length > 100 || !names.add(name.toLowerCase())) {
        message ??=
            'Give each attachment a distinct name (up to 100 characters).';
      }
    }
    setState(() => _error = message);
    if (message != null) return null;
    return [
      for (final row in _attachments)
        {'name': row.name.text.trim(), 'required': row.required},
    ];
  }

  @override
  void dispose() {
    _main.dispose();
    for (final row in _attachments) {
      row.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (widget.showIntroduction) ...[
        Text(
          widget.checklistOnly ? 'Checklist attachments' : 'Folder contents',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          widget.checklistOnly
              ? 'Define attachment names and which are required. Staff enter actual page counts when registering a physical folder.'
              : 'Count all physical pages, including attachments. List required items even when missing; enter 0 pages. Your office decides which items are required.',
          style: const TextStyle(fontSize: 13),
        ),
        const SizedBox(height: 12),
      ],
      if (!widget.checklistOnly)
        TextField(
          controller: _main,
          enabled: widget.enabled,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: 'Main document pages',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) {
            setState(() => _error = null);
            widget.onChanged?.call();
          },
        ),
      for (final row in _attachments)
        Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: row.name,
                onChanged: (_) => widget.onChanged?.call(),
                enabled: widget.enabled,
                maxLength: 100,
                decoration: const InputDecoration(
                  labelText: 'Attachment name',
                  hintText: 'Name from your office checklist',
                  border: OutlineInputBorder(),
                ),
              ),
              if (!widget.checklistOnly) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: row.pages,
                  onChanged: (_) => widget.onChanged?.call(),
                  enabled: widget.enabled,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Attachment pages',
                    helperText: '0 = missing',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Required attachment'),
                value: row.required,
                onChanged: widget.enabled
                    ? (value) {
                        setState(() => row.required = value ?? true);
                        widget.onChanged?.call();
                      }
                    : null,
              ),
              TextButton.icon(
                onPressed: widget.enabled
                    ? () {
                        setState(() => _attachments.remove(row));
                        row.dispose();
                        widget.onChanged?.call();
                      }
                    : null,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Remove attachment'),
              ),
            ],
          ),
        ),
      if (_attachments.length < 20)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: widget.enabled
                ? () {
                    setState(() => _attachments.add(_Attachment()));
                    widget.onChanged?.call();
                  }
                : null,
            icon: const Icon(Icons.add),
            label: const Text('Add attachment'),
          ),
        ),
      if (!widget.checklistOnly)
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: _confirmed,
          onChanged: widget.enabled
              ? (value) => setState(() {
                  _confirmed = value ?? false;
                  _error = null;
                })
              : null,
          title: const Text(
            'I physically hold this folder and counted its contents.',
          ),
        ),
      if (_error != null)
        Text(_error!, style: const TextStyle(color: SfColors.red)),
    ],
  );
}

Future<Map<String, dynamic>?> showFolderReceiptDialog(
  BuildContext context,
  Map<String, dynamic> document,
) => showDialog<Map<String, dynamic>>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _FolderReceiptDialog(document: document),
);

class _FolderReceiptDialog extends StatefulWidget {
  const _FolderReceiptDialog({required this.document});
  final Map<String, dynamic> document;
  @override
  State<_FolderReceiptDialog> createState() => _FolderReceiptDialogState();
}

class _FolderReceiptDialogState extends State<_FolderReceiptDialog> {
  late final _inventory =
      widget.document['folder_inventory'] as Map<String, dynamic>?;
  late final _items = folderItems(_inventory);
  late final _counts = [for (final _ in _items) TextEditingController()];
  final _reason = TextEditingController();
  bool _confirmed = false;
  String? _error;
  List<int?> get _values => [
    for (final controller in _counts) int.tryParse(controller.text.trim()),
  ];
  bool get _different => List.generate(
    _items.length,
    (i) => _values[i] != _items[i]['pages'],
  ).any((v) => v);
  bool get _incomplete => List.generate(
    _items.length,
    (i) =>
        _items[i]['required'] == true &&
        _values[i] != null &&
        (_values[i] == 0 || _values[i]! < (_items[i]['pages'] as int)),
  ).any((v) => v);
  @override
  void dispose() {
    for (final controller in _counts) {
      controller.dispose();
    }
    _reason.dispose();
    super.dispose();
  }

  void _save() {
    final counts = _values;
    if (counts.any((value) => value == null || value < 0 || value > 999) ||
        counts.fold<int>(0, (sum, n) => sum + (n ?? 0)) > 9999) {
      setState(
        () => _error =
            'Enter actual whole page counts from 0–999 (total up to 9999).',
      );
      return;
    }
    if (_different && _reason.text.trim().length < 5) {
      setState(
        () => _error = 'Describe the discrepancy (at least 5 characters).',
      );
      return;
    }
    Navigator.pop(context, {
      'confirmed': true,
      'items': [
        for (var i = 0; i < _items.length; i++)
          {'id': _items[i]['id'], 'pages': counts[i]},
      ],
      'reason': _reason.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    title: const Text('Check folder contents'),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('${widget.document['id']}'),
            Text(
              _inventory == null
                  ? 'No inventory was recorded for this older folder. Check its reference and confirm physical receipt.'
                  : '${_inventory['total_pages']} registered pages. Count what actually arrived; enter 0 for a missing item. The QR does not count pages.',
            ),
            for (var i = 0; i < _items.length; i++)
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: TextField(
                  controller: _counts[i],
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: '${_items[i]['name']} — received pages',
                    helperText:
                        '${_items[i]['pages']} registered${_items[i]['required'] == true ? ' · required' : ''}',
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() => _error = null),
                ),
              ),
            if (_items.isNotEmpty &&
                _values.every((value) => value != null)) ...[
              const SizedBox(height: 12),
              Text(
                '${_values.fold<int>(0, (sum, value) => sum + (value ?? 0))} received / ${_inventory!['total_pages']} registered pages${_incomplete
                    ? ' · Incomplete contents'
                    : _different
                    ? ' · Discrepancy'
                    : ' · Counts match'}',
              ),
            ],
            if (_different)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: TextField(
                  controller: _reason,
                  maxLength: 1000,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Discrepancy / missing item details',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() => _error = null),
                ),
              ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _confirmed,
              onChanged: (value) => setState(() => _confirmed = value ?? false),
              title: const Text(
                'I physically received this folder and checked its reference and contents.',
              ),
            ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: SfColors.red)),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _confirmed ? _save : null,
        child: Text(
          _incomplete
              ? 'Receive incomplete folder'
              : _different
              ? 'Receive with discrepancy'
              : 'Confirm receipt',
        ),
      ),
    ],
  );
}
