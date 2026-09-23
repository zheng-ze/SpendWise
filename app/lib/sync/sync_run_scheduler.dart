import 'dart:async';

final class SyncRunScheduler {
  SyncRunScheduler({required this._runPass, required this._onStatusChanged});

  final Future<void> Function() _runPass;
  final void Function(bool running) _onStatusChanged;

  bool _active = false;
  bool _trailingQueued = false;
  final List<Completer<void>> _activeWaiters = <Completer<void>>[];
  final List<Completer<void>> _trailingWaiters = <Completer<void>>[];

  void requestRun() {
    if (_active) {
      _trailingQueued = true;
      return;
    }
    _launch();
  }

  Future<void> runNow() {
    final waiter = Completer<void>();
    if (!_active) {
      _activeWaiters.add(waiter);
      _launch();
      return waiter.future;
    }
    _trailingQueued = true;
    _trailingWaiters.add(waiter);
    return waiter.future;
  }

  void _launch() {
    _active = true;
    _onStatusChanged(true);
    unawaited(_drain());
  }

  Future<void> _drain() async {
    while (true) {
      try {
        await _runPass();
      } catch (error, stackTrace) {
        final hadWaiters =
            _activeWaiters.isNotEmpty || _trailingWaiters.isNotEmpty;
        _failPending(error, stackTrace);
        if (!hadWaiters) {
          Error.throwWithStackTrace(error, stackTrace);
        }
        return;
      }
      _completePassWaiters();
      if (!_trailingQueued) {
        _settleIdle();
        return;
      }
      _chainTrailing();
    }
  }

  void _completePassWaiters() {
    final finished = List<Completer<void>>.of(_activeWaiters);
    _activeWaiters.clear();
    for (final waiter in finished) {
      waiter.complete();
    }
  }

  void _chainTrailing() {
    _trailingQueued = false;
    _activeWaiters.addAll(_trailingWaiters);
    _trailingWaiters.clear();
  }

  void _settleIdle() {
    _active = false;
    _onStatusChanged(false);
  }

  void _failPending(Object error, StackTrace stackTrace) {
    final activeWaiters = List<Completer<void>>.of(_activeWaiters);
    final trailingWaiters = List<Completer<void>>.of(_trailingWaiters);
    _activeWaiters.clear();
    _trailingWaiters.clear();
    _trailingQueued = false;
    _active = false;
    for (final waiter in activeWaiters) {
      waiter.completeError(error, stackTrace);
    }
    for (final waiter in trailingWaiters) {
      waiter.completeError(error, stackTrace);
    }
    _onStatusChanged(false);
  }
}
