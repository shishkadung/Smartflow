import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_connectivity.dart';
import '../services/movement_recovery.dart';

/// Refresh time-sensitive visible data without replacing the current content.
class _RefreshObserver with WidgetsBindingObserver {
  _RefreshObserver(this.onChange);
  final void Function(AppLifecycleState) onChange;
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => onChange(state);
}

mixin LiveRefresh<T extends StatefulWidget> on State<T> {
  Timer? _refreshTimer;
  bool _refreshing = false;
  bool _foreground = true;
  late final _RefreshObserver _observer;
  Future<void> refreshLiveData();

  @override
  void initState() {
    super.initState();
    _observer = _RefreshObserver((state) {
      _foreground = state == AppLifecycleState.resumed;
      if (_foreground) unawaited(_refresh());
    });
    WidgetsBinding.instance.addObserver(_observer);
    ApiConnectivity.instance.retries.addListener(_retry);
    MovementRecovery.changes.addListener(_retry);
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _refresh(),
    );
  }

  void _retry() => unawaited(_refresh());

  Future<void> _refresh() async {
    if (!mounted ||
        !_foreground ||
        _refreshing ||
        !(ModalRoute.of(context)?.isCurrent ?? true)) {
      return;
    }
    _refreshing = true;
    try {
      await refreshLiveData();
    } finally {
      _refreshing = false;
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    ApiConnectivity.instance.retries.removeListener(_retry);
    MovementRecovery.changes.removeListener(_retry);
    WidgetsBinding.instance.removeObserver(_observer);
    super.dispose();
  }
}
