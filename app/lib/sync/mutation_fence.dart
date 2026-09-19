import 'dart:async';

import 'package:spendwise/ledger/event_bus.dart';

/// Synchronous fence detecting whether any ledger mutation was published
/// during a window, so a fold-in attempt can tell if it raced a concurrent
/// write.
///
/// The fence installs its own independent [EventBus.subscribe] listener whose
/// only job is to bump a global monotonic epoch counter on every publication
/// it observes. It never mutates the ledger inside the callback, matching
/// [EventBus]'s contract that a handler must only enqueue or bump a counter.
///
/// [EventBus] wraps a `StreamController.broadcast(sync: true)`, so `publish`
/// dispatches synchronously into every listener before it returns. That makes
/// [snapshot] and [checkClean] exact around synchronous code: a publication
/// that happened anywhere in the same call stack is already reflected.
///
/// One fence instance is meant to span an entire fold-in attempt end to end:
/// [install] once at the start of the attempt, [snapshot] at the point where
/// a candidate set of rows is decided, [checkClean] immediately before the
/// final commit decision, and [uninstall] when the attempt ends.
final class MutationFence {
  MutationFence(this._bus);

  final EventBus _bus;

  StreamSubscription<LedgerPublication>? _subscription;

  var _epoch = 0;

  /// Subscribes the epoch-bumping listener. Calling [install] twice on the
  /// same instance is a safe no-op: the second call leaves the single existing
  /// subscription untouched rather than double-subscribing.
  void install() {
    if (_subscription != null) return;
    _subscription = _bus.subscribe().listen((_) {
      _epoch++;
    });
  }

  int snapshot() => _epoch;

  /// Returns true iff the epoch has not advanced since [snapshot] was taken,
  /// meaning no publication happened in between.
  bool checkClean(int snapshot) => _epoch == snapshot;

  /// Cancels the listener subscription. Safe to call even if never installed,
  /// or called twice.
  Future<void> uninstall() async {
    final subscription = _subscription;
    _subscription = null;
    await subscription?.cancel();
  }
}
