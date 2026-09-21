import 'dart:async';

import 'package:spendwise/sync/secret_store.dart';
import 'package:spendwise/sync/sync_coordinator.dart';
import 'package:spendwise/sync/sync_secret_keys.dart';
import 'package:sync/sync.dart';

/// Outcome of one [EnrollmentSnapshotPublisher.publish] run.
///
/// A run only succeeds once every collection is terminal for that
/// invocation ([PushNoop] or [PushFullyAcknowledged]). The first collection
/// that reports [PushDeferred] or [PushUnresolvedRows] stops the run and is
/// reported as [EnrollmentSnapshotPending], so the caller can reinvoke
/// [EnrollmentSnapshotPublisher.publish] later to retry that same collection
/// before any later one.
sealed class EnrollmentSnapshotPublishResult {
  const EnrollmentSnapshotPublishResult();
}

/// Every collection resolved terminally in this run.
final class EnrollmentSnapshotPublished
    extends EnrollmentSnapshotPublishResult {
  const EnrollmentSnapshotPublished();
}

/// The run stopped at [collection]: its [result] ([PushDeferred] or
/// [PushUnresolvedRows]) leaves rows outstanding, so a later `publish()` call
/// must retry this collection first.
final class EnrollmentSnapshotPending extends EnrollmentSnapshotPublishResult {
  const EnrollmentSnapshotPending({
    required this.collection,
    required this.result,
  });

  final SyncCollection collection;
  final PushCollectionResult result;
}

/// Pushes one enrollment snapshot across every collection in fixed order.
///
/// Constructed per enrollment attempt with the attempt's coordinator; the
/// caller (a later ticket) reinvokes [publish] until it reports
/// [EnrollmentSnapshotPublished]. The stored write proof is read once per run
/// and attached only to the run's first non-[PushNoop] push: a later push in
/// the same run never carries it, so the server sees the proof exactly once
/// per snapshot. A [PushFullyAcknowledged] or [PushUnresolvedRows] outcome on
/// the proof-bearing push deletes the stored proof immediately; a
/// [PushDeferred] outcome keeps it so the retry resupplies the same value.
/// All-[PushNoop] runs never touch the stored proof.
final class EnrollmentSnapshotPublisher {
  EnrollmentSnapshotPublisher({
    required this.coordinator,
    SecretStore? secretStore,
  }) : _secretStore = secretStore ?? SecureSecretStore();

  final SyncCoordinator coordinator;
  final SecretStore _secretStore;

  /// Serializes concurrent [publish] calls on this instance, so a second
  /// call's proof read always observes any deletion the first call already
  /// made instead of resubmitting a stale value once the coordinator's own
  /// per-collection recomputation lets a rejected row through again. The new
  /// tail installs before awaiting the prior one, so two overlapping callers
  /// can never both observe the same tail and run concurrently.
  Future<void>? _tail;

  /// Pushes each collection in [SyncCollection.values] order, stopping at the
  /// first collection that stays non-terminal.
  ///
  /// The proof-selection slot is consumed by the run's first non-[PushNoop]
  /// result even when no proof was stored: later collections in the same run
  /// always receive a null `writeProof`, never a resupplied one. Failures
  /// from the coordinator ([StateError] on a closed write gate or a failed
  /// backend push) and from the secret store propagate uncaught, leaving the
  /// stored proof untouched unless its own push was already confirmed.
  Future<EnrollmentSnapshotPublishResult> publish() async {
    final Future<void>? prior = _tail;
    final Completer<void> gate = Completer<void>();
    _tail = gate.future;
    try {
      if (prior != null) await prior;
      return await _publishLocked();
    } finally {
      if (identical(_tail, gate.future)) {
        _tail = null;
      }
      gate.complete();
    }
  }

  Future<EnrollmentSnapshotPublishResult> _publishLocked() async {
    final String? proof = await _secretStore.read(syncWriteProofSecretKey);
    bool proofSlotConsumed = false;
    for (final SyncCollection collection in SyncCollection.values) {
      final bool suppliesProof = !proofSlotConsumed;
      final PushCollectionResult outcome = await coordinator.pushCollection(
        collection,
        writeProof: suppliesProof ? proof : null,
      );
      if (outcome is PushNoop) continue;
      proofSlotConsumed = true;
      final bool confirmed =
          outcome is PushFullyAcknowledged || outcome is PushUnresolvedRows;
      if (suppliesProof && proof != null && confirmed) {
        await _secretStore.delete(syncWriteProofSecretKey);
      }
      if (outcome is PushDeferred || outcome is PushUnresolvedRows) {
        return EnrollmentSnapshotPending(
          collection: collection,
          result: outcome,
        );
      }
    }
    return const EnrollmentSnapshotPublished();
  }
}
