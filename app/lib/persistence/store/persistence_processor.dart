import 'dart:async';

import 'package:domain/domain.dart';
import 'package:spendwise/ledger/event_bus.dart';
import 'package:spendwise/persistence/store/ledger_store.dart';

class PersistenceProcessor {
  PersistenceProcessor({required this.store, required this.bus});

  final LedgerStore store;

  final EventBus bus;

  StreamSubscription<List<LedgerChange>>? _subscription;

  // MARK: - Lifecycle

  Future<void> start() async {
    _subscription ??= bus.subscribe().listen(_forward);
    await store.start();
  }

  // MARK: - Forwarding

  void _forward(List<LedgerChange> changes) => store.enqueue(changes);

  Future<void> flush() => store.flushNow();

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }
}
