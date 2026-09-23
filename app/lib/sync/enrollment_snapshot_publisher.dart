import 'dart:async';

import 'package:spendwise/sync/secret_store.dart';
import 'package:spendwise/sync/sync_coordinator.dart';
import 'package:spendwise/sync/sync_secret_keys.dart';
import 'package:sync/sync.dart';

sealed class EnrollmentSnapshotPublishResult {
  const EnrollmentSnapshotPublishResult();
}

final class EnrollmentSnapshotPublished
    extends EnrollmentSnapshotPublishResult {
  const EnrollmentSnapshotPublished();
}

final class EnrollmentSnapshotPending extends EnrollmentSnapshotPublishResult {
  const EnrollmentSnapshotPending({
    required this.collection,
    required this.result,
  });

  final SyncCollection collection;
  final PushCollectionResult result;
}

final class EnrollmentSnapshotPublisher {
  EnrollmentSnapshotPublisher({
    required this.coordinator,
    SecretStore? secretStore,
  }) : _secretStore = secretStore ?? SecureSecretStore();

  final SyncCoordinator coordinator;
  final SecretStore _secretStore;

  Future<void>? _tail;

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
