import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/smartflow_api.dart';
import '../utils/api_error.dart';

class DestinationCorrectionAction extends StatelessWidget {
  const DestinationCorrectionAction({
    super.key,
    required this.document,
    required this.onChanged,
    this.disabled = false,
  });
  final Map<String, dynamic> document;
  final Future<void> Function() onChanged;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    if (context.watch<AuthProvider>().user?.role != 'staff' ||
        document['can_correct_destination'] != true) {
      return const SizedBox.shrink();
    }
    return OutlinedButton(
      onPressed: disabled
          ? null
          : () async {
              final auth = context.read<AuthProvider>();
              if (auth.loggingOut) return;
              final identity = auth.sessionIdentity;
              final changed = await showDialog<bool>(
                context: context,
                barrierDismissible: false,
                builder: (_) => _CorrectionDialog(
                  document: Map<String, dynamic>.from(document),
                ),
              );
              if (changed == true &&
                  context.mounted &&
                  auth.sessionIdentity == identity) {
                await onChanged();
              }
            },
      child: const Text('Correct recorded destination'),
    );
  }
}

class _CorrectionDialog extends StatefulWidget {
  const _CorrectionDialog({required this.document});
  final Map<String, dynamic> document;
  @override
  State<_CorrectionDialog> createState() => _CorrectionDialogState();
}

class _CorrectionDialogState extends State<_CorrectionDialog> {
  final _reason = TextEditingController();
  List<Map<String, dynamic>> _offices = [];
  int? _destination;
  bool _confirmed = false, _loading = true, _busy = false;
  String? _error;
  late final AuthProvider _auth;
  late final Object _identity;
  late final SmartflowApi _api;
  late final int? _officeId;
  bool get _current => mounted && _auth.sessionIdentity == _identity;
  @override
  void initState() {
    super.initState();
    _auth = context.read<AuthProvider>();
    _identity = _auth.sessionIdentity;
    _api = _auth.api;
    _officeId = _auth.user?.officeId;
    _load();
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!_current) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await _api.offices();
      if (_current) {
        setState(
          () => _offices = rows
              .where(
                (office) =>
                    office['id'] != _officeId &&
                    office['id'] != widget.document['destination_office_id'],
              )
              .toList(),
        );
      }
    } catch (error) {
      if (_current) setState(() => _error = apiErrorMessage(error));
    } finally {
      if (_current) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    if (!_current ||
        _auth.loggingOut ||
        _busy ||
        _destination == null ||
        !_confirmed ||
        _reason.text.trim().length < 5) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final doc = widget.document;
    try {
      await _api.correctMovementDestination({
        'document_id': doc['id'],
        'expected_movement_id': doc['last_movement_id'],
        'expected_destination_office_id': doc['destination_office_id'],
        'expected_correction_id': doc['last_destination_correction_id'] ?? 0,
        'destination_office_id': _destination,
        'reason': _reason.text.trim(),
        'correction_confirmed': true,
      });
      if (mounted && _current) Navigator.pop(context, true);
    } catch (error) {
      if (_current) {
        setState(() {
          _error = apiErrorMessage(error);
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      scrollable: true,
      title: const Text('Correct recorded destination'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${widget.document['id']}\nRecorded destination: ${widget.document['destination_office_name']}',
          ),
          const SizedBox(height: 12),
          const Text(
            'Correct only an unreceived OUT. The original destination and reason stay in its history. This records no receipt or additional handoff.',
          ),
          const SizedBox(height: 12),
          if (_error != null) ...[
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            if (_offices.isEmpty)
              TextButton(
                onPressed: _busy ? null : _load,
                child: const Text('Retry offices'),
              ),
          ],
          if (_loading) const LinearProgressIndicator(),
          DropdownButtonFormField<int>(
            initialValue: _destination,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Correct destination'),
            items: [
              for (final office in _offices)
                DropdownMenuItem(
                  value: (office['id'] as num).toInt(),
                  child: Text('${office['name']}'),
                ),
            ],
            onChanged: _busy || _loading
                ? null
                : (value) => setState(() {
                    _destination = value;
                    _confirmed = false;
                  }),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _reason,
            enabled: !_busy,
            maxLength: 1000,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Reason for correction',
            ),
            onChanged: (_) => setState(() {}),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _confirmed,
            onChanged: _busy
                ? null
                : (value) => setState(() => _confirmed = value ?? false),
            title: const Text(
              'I verified the actual destination and this folder has not been received in SmartFlow.',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed:
              _busy ||
                  _loading ||
                  _destination == null ||
                  !_confirmed ||
                  _reason.text.trim().length < 5
              ? null
              : _submit,
          child: Text(_busy ? 'Recording…' : 'Confirm correction'),
        ),
      ],
    ),
  );
}

class DestinationCorrectionHistory extends StatelessWidget {
  const DestinationCorrectionHistory({super.key, required this.corrections});
  final List corrections;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final correction in corrections)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            'Destination corrected: ${correction['previous_destination_office_name']} → ${correction['destination_office_name']}\n${correction['reason']}\n${correction['corrected_by_name']} · ${correction['corrected_at']}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
    ],
  );
}
