import 'dart:async';

import 'package:domain/domain.dart';
import 'package:sync/sync.dart';

import 'package:spendwise/ledger/ledger_publication.dart';

export 'package:spendwise/ledger/ledger_publication.dart';

/// A handler must only enqueue or bump a counter, never mutate the ledger. It
/// runs inside [publish], and so inside the mutation that produced the batch,
/// while the remaining subscribers have yet to be served. The controller
/// enforces this by throwing on the reentrant add.
class EventBus {
  final StreamController<LedgerPublication> _controller =
      StreamController<LedgerPublication>.broadcast(sync: true);

  /// Publishes [changes] with optional sync [stamps]. Ordinary local
  /// mutations omit [stamps]; the sync engine supplies them for remote
  /// batches. Returns without publishing when [changes] is empty, even when
  /// [stamps] is present.
  void publish(
    List<LedgerChange> changes, {
    Map<SyncRowID, VersionVector>? stamps,
  }) {
    if (changes.isEmpty) return;

    var publication = LedgerPublication(changes: changes, stamps: stamps);
    // Debug-only, so the wrapper allocations disappear in release.
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
