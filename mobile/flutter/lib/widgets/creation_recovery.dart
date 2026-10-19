import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/smartflow_api.dart';
import '../utils/api_error.dart';

class CreationRecoveryPanel extends StatefulWidget {
  const CreationRecoveryPanel({
    super.key,
    required this.kind,
    required this.onRecovered,
  });
  final String kind;
  final ValueChanged<Map<String, dynamic>> onRecovered;
  @override
  State<CreationRecoveryPanel> createState() => _CreationRecoveryPanelState();
}

class _CreationRecoveryPanelState extends State<CreationRecoveryPanel> {
  late final AuthProvider _auth;
  late final Object _identity;
  late final SmartflowApi _api;
  bool get _current => mounted && _auth.sessionIdentity == _identity;
  @override
  void initState() {
    super.initState();
    _auth = context.read<AuthProvider>();
    _identity = _auth.sessionIdentity;
    _api = _auth.api;
  }

  bool _busy = false;
  String? _message;
  Future<void> _run(bool retry) async {
    if (!_current || _auth.loggingOut || _busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final outcome = await _api.checkCreation(widget.kind);
      if (!_current) return;
      final result = outcome?['state'] == 'recorded'
          ? Map<String, dynamic>.from(outcome!['result'] as Map)
          : retry && !_auth.loggingOut
          ? await _api.retryCreation(widget.kind)
          : null;
      if (!_current) return;
      if (result != null) {
        widget.onRecovered(result);
      } else {
        _message =
            'No completed result found yet. Retry saved submission uses the same operation ID and cannot create it twice.';
      }
    } catch (error) {
      if (_current) _message = apiErrorMessage(error);
    } finally {
      if (_current) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>?>(
    future: _api.pendingCreation(widget.kind),
    builder: (context, snapshot) {
      if (snapshot.data == null && !snapshot.hasError && _message == null) {
        return const SizedBox.shrink();
      }
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              snapshot.hasError
                  ? 'Saved submission unavailable. Check your connection and try again.'
                  : _message ??
                        'Recover the previous submission before creating another record.',
            ),
            if (snapshot.data?['body'] is Map)
              Text(
                '${snapshot.data!['body']['title'] ?? snapshot.data!['body']['purpose'] ?? ''}',
              ),
            if (snapshot.data != null)
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: _busy ? null : () => _run(false),
                    child: const Text('Check previous submission'),
                  ),
                  TextButton(
                    onPressed: _busy ? null : () => _run(true),
                    child: const Text('Retry saved submission'),
                  ),
                ],
              ),
          ],
        ),
      );
    },
  );
}
