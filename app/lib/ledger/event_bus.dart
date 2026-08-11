import 'dart:async';

import 'package:domain/domain.dart';

/// A handler must only enqueue or bump a counter, never mutate the ledger. It
/// runs inside [publish], and so inside the mutation that produced the batch,
/// while the remaining subscribers have yet to be served. The controller
/// enforces this by throwing on the reentrant add.
class EventBus {
  final StreamController<List<LedgerChange>> _controller =
      StreamController<List<LedgerChange>>.broadcast(sync: true);

  void publish(List<LedgerChange> changes) {
    if (changes.isEmpty) return;

    var batch = changes;
    // Debug-only, so the wrapper allocation disappears in release.
    assert(() {
      batch = List<LedgerChange>.unmodifiable(changes);
      return true;
    }());

    _controller.add(batch);
  }

  Stream<List<LedgerChange>> subscribe() => _controller.stream;

  Future<void> dispose() => _controller.close();
}
