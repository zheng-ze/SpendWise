import 'dart:async';

import 'package:domain/domain.dart';
import 'package:spendwise/ledger/event_bus.dart';
import 'package:spendwise/persistence/ledger_store.dart';

/// The single pipe from the bus to the store.
///
/// Batches are forwarded exactly as published. Coalescing repeated upserts of
/// one target belongs to the store's debounce window, not here.
class PersistenceProcessor {
  PersistenceProcessor({required this.store, required this.bus});

  final LedgerStore store;

  final EventBus bus;

  StreamSubscription<List<LedgerChange>>? _subscription;

  /// The subscription is taken before the first await, so a batch published
  /// while the store is still starting is not lost. The stream is a broadcast
  /// with no buffer for a late listener.
  Future<void> start() async {
    _subscription ??= bus.subscribe().listen(store.enqueue);
    await store.start();
  }

  Future<void> flush() => store.flushNow();

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }
}
