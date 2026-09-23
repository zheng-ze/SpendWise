import 'dart:async';

import 'package:domain/domain.dart';
import 'package:sync/sync.dart';

import 'package:spendwise/ledger/ledger_publication.dart';

export 'package:spendwise/ledger/ledger_publication.dart';

/// Handlers must not mutate the ledger; they run inside publish.
class EventBus {
  final StreamController<LedgerPublication> _controller =
      StreamController<LedgerPublication>.broadcast(sync: true);

  void publish(
    List<LedgerChange> changes, {
    Map<SyncRowID, VersionVector>? stamps,
  }) {
    if (changes.isEmpty) return;

    var publication = LedgerPublication(changes: changes, stamps: stamps);
    assert(() {
      publication = LedgerPublication(
        changes: List<LedgerChange>.unmodifiable(changes),
        stamps: stamps == null
            ? null
            : Map<SyncRowID, VersionVector>.unmodifiable(
                Map<SyncRowID, VersionVector>.of(stamps),
              ),
      );
      return true;
    }());

    _controller.add(publication);
  }

  Stream<LedgerPublication> subscribe() => _controller.stream;

  Future<void> dispose() => _controller.close();
}
