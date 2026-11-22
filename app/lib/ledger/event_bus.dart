import 'dart:async';

import 'package:domain/domain.dart';

/// Handlers must not mutate the ledger; they run inside publish.
class EventBus {
  final StreamController<List<LedgerChange>> _controller =
      StreamController<List<LedgerChange>>.broadcast(sync: true);

  // MARK: - Publishing

  void publish(List<LedgerChange> changes) {
    if (changes.isEmpty) return;

    var published = changes;
    assert(() {
      published = List<LedgerChange>.unmodifiable(changes);
      return true;
    }());

    _controller.add(published);
  }

  // MARK: - Subscribing

  Stream<List<LedgerChange>> subscribe() => _controller.stream;

  Future<void> dispose() => _controller.close();
}
