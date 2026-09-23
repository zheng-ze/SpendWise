import 'dart:async';

import 'package:spendwise/ledger/event_bus.dart';
import 'package:spendwise/persistence/ledger_store.dart';

class PersistenceProcessor {
  PersistenceProcessor({required this.store, required this.bus});

  final LedgerStore store;

  final EventBus bus;

  StreamSubscription<LedgerPublication>? _subscription;

  Future<void> start() async {
    _subscription ??= bus.subscribe().listen(_forward);
    await store.start();
  }

  void _forward(LedgerPublication publication) {
    if (publication.hasStamps) {
      store.enqueueStamped(publication.changes, publication.stamps!);
    } else {
      store.enqueue(publication.changes);
    }
  }

  Future<void> flush() => store.flushNow();

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }
}
