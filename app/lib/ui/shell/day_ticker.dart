import 'dart:async';

import 'package:flutter/widgets.dart';

class DayTicker with WidgetsBindingObserver {
  DayTicker({required this.clock, required this.onDayChanged}) {
    WidgetsBinding.instance.addObserver(this);
    _schedule();
  }

  final DateTime Function() clock;
  final void Function() onDayChanged;

  Timer? _timer;
  bool _disposed = false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_disposed) return;
    if (state == AppLifecycleState.resumed) {
      _timer?.cancel();
      onDayChanged();
      _schedule();
    }
  }

  void _schedule() {
    if (_disposed) return;
    final now = clock();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    var delay = nextMidnight.difference(now);
    if (delay <= Duration.zero) delay = const Duration(seconds: 1);
    _timer = Timer(delay, () {
      if (_disposed) return;
      onDayChanged();
      _schedule();
    });
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    WidgetsBinding.instance.removeObserver(this);
  }
}
