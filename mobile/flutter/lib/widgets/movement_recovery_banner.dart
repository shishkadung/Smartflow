import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/movement_recovery.dart';
import '../services/api_connectivity.dart';
import '../utils/api_error.dart';

class MovementRecoveryBanner extends StatefulWidget {
  const MovementRecoveryBanner({super.key});
  @override
  State<MovementRecoveryBanner> createState() => _MovementRecoveryBannerState();
}

class _MovementRecoveryBannerState extends State<MovementRecoveryBanner>
    with WidgetsBindingObserver {
  Map<String, dynamic>? _pending;
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    MovementRecovery.changes.addListener(_reload);
    ApiConnectivity.instance.retries.addListener(_check);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _reload() async {
    try {
      final body = await context.read<AuthProvider>().api.pendingMovement();
      if (mounted) setState(() => _pending = body);
    } catch (e) {
      if (mounted) setState(() => _error = apiErrorMessage(e));
    }
  }

  void _check() => _resolve(false);
  Future<void> _resolve(bool cancel) async {
    if (!mounted || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final api = context.read<AuthProvider>().api;
      final pending = await api.pendingMovement();
      if (pending == null) {
        if (mounted) setState(() => _pending = null);
        return;
      }
      if (mounted) setState(() => _pending = pending);
      final result = cancel
          ? await api.cancelPendingMovement()
          : await api.checkPendingMovement();
      if (!mounted) return;
      if (result?['state'] == 'recorded') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Verified: ${result!['result']['message']}')),
        );
      } else if (result?['state'] == 'cancelled') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Request cancelled safely. Refresh the document before another action.',
            ),
          ),
        );
      } else {
        setState(
          () => _error =
              'No committed result yet. Check again, or cancel this request safely before a new action.',
        );
      }
      await _reload();
    } catch (e) {
      if (mounted) setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        scrollable: true,
        title: const Text('Cancel the pending request?'),
        content: const Text(
          'SmartFlow first checks the committed result. If it was recorded, that movement stays. Otherwise this request is blocked from recording later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Keep checking'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Cancel request'),
          ),
        ],
      ),
    );
    if (yes == true && mounted) await _resolve(true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    MovementRecovery.changes.removeListener(_reload);
    ApiConnectivity.instance.retries.removeListener(_check);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _pending == null
      ? const SizedBox.shrink()
      : ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.3,
          ),
          child: SingleChildScrollView(
            child: Container(
              color: const Color(0xfffff1d0),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Pending ${_pending!['correction_confirmed'] == true ? 'destination correction' : _pending!['status']} · ${_pending!['document_id']}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (_error != null) Text(_error!),
                  if (_busy) const LinearProgressIndicator(),
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton(
                        onPressed: _busy ? null : _check,
                        child: const Text('Check result'),
                      ),
                      TextButton(
                        onPressed: _busy ? null : _cancel,
                        child: const Text('Cancel pending request'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
}
