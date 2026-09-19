import 'dart:async';

import 'package:sync/sync.dart';

/// Per-[SyncCollection] async critical section serializing concurrent async
/// work for the same collection, while letting different collections run
/// fully concurrently.
///
/// Not reentrant: a [withLock] call for the same collection from inside a
/// running body self-deadlocks (the inner call awaits the outer call's own
/// gate).
final class CollectionLock {
  final Map<SyncCollection, Future<void>> _tails = {};

  /// Callers for the same collection run one at a time in arrival order;
  /// callers for different collections overlap freely. If [body] throws, the
  /// exception propagates to this caller only: the tail always completes
  /// normally, so the lock is never poisoned for the next caller.
  Future<T> withLock<T>(
    SyncCollection collection,
    Future<T> Function() body,
  ) async {
    final prior = _tails[collection];
    // Install the new tail synchronously, before awaiting the prior tail. A
    // caller that awaited first and installed after would let two overlapping
    // callers read the same current tail and run concurrently instead of
    // serialized; chaining first closes that race.
    final gate = Completer<void>();
    _tails[collection] = gate.future;
    try {
      if (prior != null) await prior;
      return await body();
    } finally {
      // Remove this tail only if no newer caller has replaced it meanwhile;
      // dropping a newer tail would break serialization for that caller. The
      // gate completes normally either way, so waiters never observe body()'s
      // failure through the tail.
      if (identical(_tails[collection], gate.future)) {
        _tails.remove(collection);
      }
      gate.complete();
    }
  }
}
