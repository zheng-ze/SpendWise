import 'dart:async';

import 'package:spendwise/persistence/ledger_database.dart';
import 'package:spendwise/sync/sync_metadata_store.dart';

/// Process-lifetime stop gate for bound sync RPCs, one per [LedgerDatabase].
///
/// Every coordinator composed for the same database shares one gate, so a
/// repair triggered by any pair stops new bound work for every later pair
/// until a durable repair exit. The gate is recreated from durable metadata
/// on restart through [reseed]: repair-durable state latches it, a bound
/// phase at an allowed resume point releases it.
///
/// Admission is separate from metadata legality: legal repair states never
/// admit bound RPCs. Callers check
/// [SyncMetadataStore.validateHostedOperationState] first, then [admit].
///
/// [withSecretMutationLock] serializes device-secret compare-and-delete
/// sections so a late authorization failure for a rotated-away secret cannot
/// interleave with a concurrent repair and delete the new secret.
final class SyncRepairGate {
  SyncRepairGate._();

  static final Expando<SyncRepairGate> _instances = Expando<SyncRepairGate>(
    'SyncRepairGate',
  );

  factory SyncRepairGate.forDatabase(LedgerDatabase database) =>
      _instances[database] ??= SyncRepairGate._();

  bool _latched = false;

  Future<void> _mutationTail = Future<void>.value();

  bool get isOpen => !_latched;

  void latch() {
    _latched = true;
  }

  void reseed(SyncMetadataSnapshot snapshot) {
    admit(snapshot);
  }

  bool admit(SyncMetadataSnapshot snapshot) {
    if (_isBoundAtAllowedPhase(snapshot)) {
      _latched = false;
      return true;
    }
    _latched = true;
    return false;
  }

  Future<T> withSecretMutationLock<T>(Future<T> Function() work) async {
    final Future<void> prior = _mutationTail;
    final Completer<void> turn = Completer<void>();
    _mutationTail = turn.future;
    await prior;
    try {
      return await work();
    } finally {
      turn.complete();
    }
  }

  static bool _isBoundAtAllowedPhase(SyncMetadataSnapshot snapshot) {
    if (snapshot.deviceBindingState != SyncDeviceBindingState.bound) {
      return false;
    }
    return switch (snapshot.phase) {
      SyncEnrollmentPhase.snapshotInProgress ||
      SyncEnrollmentPhase.reconciliationComplete ||
      SyncEnrollmentPhase.gateEnabled => true,
      SyncEnrollmentPhase.notEnrolled ||
      SyncEnrollmentPhase.credentialAcquired ||
      SyncEnrollmentPhase.bindingAuthorizationRequired ||
      SyncEnrollmentPhase.sessionReauthRequired => false,
    };
  }
}
