import 'dart:async';

/// Pure-Dart single-flight scheduler with exactly one coalesced trailing slot.
///
/// The scheduler owns no I/O, backend, persistence, or coordinator state: a
/// pass is whatever the injected [runPass] callback does, and running-versus-
/// idle transitions are reported through the injected [onStatusChanged]
/// callback. A future sibling wires this into the sync coordinator; until
/// then this class has no production caller.
///
/// Behavior:
/// - [requestRun] is fire-and-forget. It starts a pass immediately when none
///   is active, queues exactly one coalesced trailing pass when one is
///   already active, and is a no-op when both slots are already full.
/// - [runNow] starts a pass when none is active and resolves when that pass
///   completes; while a pass is active it joins the same single trailing slot
///   a [requestRun] would have queued, resolving only once that trailing pass
///   completes rather than the already-active one. Overlapping [runNow] calls
///   share one coalesced trailing pass.
/// - [onStatusChanged] reports `true` while a pass (or a chained trailing
///   pass) is running and `false` once the scheduler settles idle. It never
///   reports idle between an active pass and its immediately-chained trailing
///   pass.
///
/// A [runPass] failure is delivered to every pending [runNow] future and then
/// settles the scheduler back to idle; no retry or failure policy lives here.
final class SyncRunScheduler {
  // Private named parameters are not legal Dart, so initializing formals
  // cannot be used for these private fields; the ignores below are exact.
  SyncRunScheduler({
    required Future<void> Function() runPass,
    required void Function(bool running) onStatusChanged,
  }) : _runPass = runPass, // ignore: prefer_initializing_formals
       _onStatusChanged = // ignore: prefer_initializing_formals
           onStatusChanged;

  final Future<void> Function() _runPass;
  final void Function(bool running) _onStatusChanged;

  bool _active = false;
  bool _trailingQueued = false;
  final List<Completer<void>> _activeWaiters = <Completer<void>>[];
  final List<Completer<void>> _trailingWaiters = <Completer<void>>[];

  /// Requests a pass without waiting for it.
  ///
  /// Starts a pass when idle; otherwise ensures one coalesced trailing pass
  /// follows the active one. A no-op when a trailing pass is already queued.
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
