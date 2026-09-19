import 'dart:async';

/// Single-flight scheduler with one coalesced trailing pass.
///
/// [requestRun] starts a pass when idle, otherwise queues one trailing pass.
/// [runNow] starts a pass when idle and resolves when it completes; while a
/// pass is active it joins the same trailing slot, resolving when that
/// trailing pass completes. Overlapping [runNow] calls share one trailing
/// pass. [onStatusChanged] reports `true` while running and `false` once
/// idle, with no idle report between a pass and its chained trailing pass.
/// A [runPass] failure completes every pending [runNow] future with that
/// error; no retry lives here.
final class SyncRunScheduler {
  SyncRunScheduler({required this._runPass, required this._onStatusChanged});

  final Future<void> Function() _runPass;
  final void Function(bool running) _onStatusChanged;

  bool _active = false;
  bool _trailingQueued = false;
  final List<Completer<void>> _activeWaiters = <Completer<void>>[];
  final List<Completer<void>> _trailingWaiters = <Completer<void>>[];

  /// Starts a pass immediately if idle, otherwise queues one coalesced
  /// trailing pass; a no-op if a trailing pass is already queued.
  void requestRun() {
    if (_active) {
      _trailingQueued = true;
      return;
    }
    _launch();
  }

  /// Starts a pass when idle, or joins the single trailing slot when active.
  ///
  /// The returned future resolves once the pass this call joined completes:
  /// the freshly started pass when idle, or the coalesced trailing pass when
  /// a pass is already active.
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
