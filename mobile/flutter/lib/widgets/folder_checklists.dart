import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/smartflow_api.dart';
import '../theme/smartflow_theme.dart';
import '../utils/api_error.dart';
import 'folder_contents.dart';

class FolderChecklists extends StatefulWidget {
  const FolderChecklists({
    super.key,
    required this.editor,
    required this.type,
    required this.onChanged,
    this.enabled = true,
    this.management = false,
  });
  final GlobalKey<FolderInventoryEditorState> editor;
  final String type;
  final VoidCallback onChanged;
  final bool enabled;
  final bool management;
  @override
  State<FolderChecklists> createState() => _FolderChecklistsState();
}

class _FolderChecklistsState extends State<FolderChecklists> {
  late final AuthProvider _auth;
  late final Object _identity;
  late final SmartflowApi _api;
  bool get _current => mounted && _auth.sessionIdentity == _identity;
  List<Map<String, dynamic>> _rows = [];
  bool _loaded = false;
  String? _loadError;
  String? _error;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _auth = context.read<AuthProvider>();
    _identity = _auth.sessionIdentity;
    _api = _auth.api;
    _load();
  }

  Future<void> _load() async {
    if (!_current || _auth.loggingOut) return;
    setState(() => _busy = true);
    try {
      final result = await _api.folderChecklists();
      if (_current) {
        setState(() {
          _rows = List<Map<String, dynamic>>.from(result['checklists'] as List);
          _loaded = true;
          _loadError = null;
        });
      }
    } catch (e) {
      if (_current) setState(() => _loadError = apiErrorMessage(e));
    } finally {
      if (_current) setState(() => _busy = false);
    }
  }

  Future<void> _apply(Map<String, dynamic> row) async {
    if (!_current || _auth.loggingOut || _busy || _loadError != null) return;
    if (widget.editor.currentState?.dirty == true) {
      final accept = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          scrollable: true,
          title: const Text('Replace the contents checklist?'),
          content: Text(
            widget.management
                ? 'This replaces the attachment names and required flags in this draft.'
                : 'This replaces the attachment names and clears all page counts and physical confirmation.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Replace'),
            ),
          ],
        ),
      );
      if (accept != true ||
          !_current ||
          _auth.loggingOut ||
          _loadError != null) {
        return;
      }
    }
    widget.editor.currentState?.restore({
      'items': [
        {'name': 'Main document', 'pages': '', 'required': true},
        for (final item in row['items'] as List)
          {...Map<String, dynamic>.from(item as Map), 'pages': ''},
      ],
    });
    widget.onChanged();
  }

  Future<void> _publish() async {
    if (!_current || _auth.loggingOut || _busy || _loadError != null) return;
    final attachments = widget.editor.currentState?.validateChecklistAndRead();
    if (attachments == null) return;
    var draftName = '';
    final name = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        scrollable: true,
        title: const Text('Publish office checklist'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Publish only requirements approved by your office. Page counts will stay blank when staff apply this checklist.',
            ),
            const SizedBox(height: 12),
            TextField(
              onChanged: (value) => draftName = value,
              maxLength: 100,
              decoration: const InputDecoration(labelText: 'Checklist name'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (draftName.trim().isNotEmpty) {
                Navigator.pop(c, draftName.trim());
              }
            },
            child: const Text('Publish'),
          ),
        ],
      ),
    );
    if (name == null || !_current || _auth.loggingOut || _loadError != null) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _api.saveFolderChecklist({
        'name': name,
        'document_type': widget.type,
        'items': [
          for (final row in attachments)
            {'name': row['name'], 'required': row['required']},
        ],
      });
      if (_current) await _load();
    } catch (e) {
      if (_current) setState(() => _error = apiErrorMessage(e));
    } finally {
      if (_current) setState(() => _busy = false);
    }
  }

  Future<void> _archive(Map<String, dynamic> row) async {
    if (!_current || _auth.loggingOut || _busy || _loadError != null) return;
    final approved = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Archive ${row['name']}?'),
        scrollable: true,
        content: const Text('Existing registered inventories stay unchanged.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
    if (approved != true ||
        !_current ||
        _auth.loggingOut ||
        _loadError != null) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _api.saveFolderChecklist({'action': 'archive', 'id': row['id']});
      if (_current) await _load();
    } catch (e) {
      if (_current) setState(() => _error = apiErrorMessage(e));
    } finally {
      if (_current) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final manager = [
      'head',
      'admin',
    ].contains(context.watch<AuthProvider>().user?.role);
    final rows = _rows
        .where((row) => row['document_type'] == widget.type)
        .toList();
    final refreshEnabled = widget.enabled && !_busy;
    final enabled = refreshEnabled && _loadError == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.management)
          const Text(
            'Office attachment checklists',
            style: TextStyle(fontWeight: FontWeight.w700),
          )
        else
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Office checklist',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                tooltip: 'Refresh checklists',
                onPressed: refreshEnabled ? _load : null,
                icon: const Icon(Icons.refresh, size: 20),
                color: SfColors.muted,
              ),
            ],
          ),
        if (_loadError != null) ...[
          Text(
            _loaded
                ? 'Refresh failed. Showing the last loaded checklists, which may be out of date. $_loadError'
                : 'Checklists unavailable. $_loadError',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: refreshEnabled ? _load : null,
              child: const Text('Retry'),
            ),
          ),
        ],
        if (_error != null)
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        if (_busy) const LinearProgressIndicator(),
        if (!_busy && _loaded && _loadError == null && rows.isEmpty)
          Text(
            widget.management
                ? 'No published checklist for this document type. Define approved attachment requirements below.'
                : 'No published checklist. Enter your office’s approved requirements below.',
            style: widget.management
                ? null
                : const TextStyle(fontSize: 13, color: SfColors.muted),
          ),
        for (final row in rows)
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: enabled ? () => _apply(row) : null,
                  child: Text('Use ${row['name']}'),
                ),
              ),
              if (manager)
                IconButton(
                  tooltip: 'Archive checklist',
                  onPressed: enabled ? () => _archive(row) : null,
                  icon: const Icon(Icons.archive_outlined),
                ),
            ],
          ),
        if (manager || widget.management)
          Wrap(
            spacing: 8,
            children: [
              if (manager)
                TextButton.icon(
                  onPressed: enabled ? _publish : null,
                  icon: const Icon(Icons.publish),
                  label: const Text('Publish attachments as checklist'),
                ),
              if (widget.management)
                TextButton(
                  onPressed: refreshEnabled ? _load : null,
                  child: const Text('Refresh checklists'),
                ),
            ],
          ),
        const SizedBox(height: 12),
      ],
    );
  }
}
