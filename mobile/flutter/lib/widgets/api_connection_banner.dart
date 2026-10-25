import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../services/api_connectivity.dart';

class ApiConnectionBanner extends StatefulWidget {
  const ApiConnectionBanner({super.key});
  @override
  State<ApiConnectionBanner> createState() => _ApiConnectionBannerState();
}

class _ApiConnectionBannerState extends State<ApiConnectionBanner> {
  bool _checking = false;
  Future<void> _retry() async {
    setState(() => _checking = true);
    try {
      await context.read<AuthProvider>().api.validateSession();
      ApiConnectivity.instance.refresh();
    } catch (_) {
      /* Connection feedback stays visible on transport failure. */
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: ApiConnectivity.instance,
    builder: (context, _) {
      final state = ApiConnectivity.instance;
      if (!state.unavailable) return const SizedBox.shrink();
      return Material(
        color: const Color(0xFFFFF8EB),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Portal connection unavailable',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  'Displayed information may be outdated.${state.lastSuccess == null ? '' : ' Last contact: ${DateFormat.Hm().format(state.lastSuccess!)}.'}',
                  style: const TextStyle(fontSize: 13),
                ),
                TextButton(
                  onPressed: _checking ? null : _retry,
                  child: Text(_checking ? 'Checking…' : 'Retry connection'),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
