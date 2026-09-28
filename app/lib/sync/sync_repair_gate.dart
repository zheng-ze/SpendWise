import 'dart:async';

import 'package:spendwise/persistence/ledger_database.dart';
import 'package:spendwise/sync/sync_metadata_store.dart';

/// Admission lease proving a bound RPC was admitted under a specific gate
/// generation. Any latch or release retires outstanding leases, so a late
/// response can prove which gate state admitted it before committing.
final class BoundRpcLease {
  const BoundRpcLease._(this._generation);

  final int _generation;
}

/// Process-lifetime stop gate for bound sync RPCs, one per [LedgerDatabase].
///
/// A repair triggered by any composed pair stops new bound work for every
/// later pair until a durable repair exit; [reseed] recreates this from
/// durable metadata on restart. Admission is separate from metadata legality:
/// legal repair states never admit bound RPCs.
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
  int _generation = 0;

  Future<void> _mutationTail = Future<void>.value();

  bool get isOpen => !_latched;

  /// Closes the gate, retiring outstanding leases. A snapshot read during the
  /// gap before the repair transaction commits still shows the pre-repair
  /// state, so only an explicit [release] from a committed repair exit may
  /// reopen — never another [admit].
  void latch() {
    _latched = true;
    _generation++;
  }

  /// Reopens after a committed durable repair exit. A no-op while open, so
  /// forward-progress transitions never disturb in-flight leases.
  void release() {
    if (_latched) {
      _latched = false;
      _generation++;
    }
  }

  /// One-time startup path recreating the gate from durable state. Unlike
  /// [admit], this runs before any lease exists, so it sets the flag without
  /// retiring anything.
  void reseed(SyncMetadataSnapshot snapshot) {
    _latched = !_isBoundAtAllowedPhase(snapshot);
  }

  /// Admits a bound RPC, returning its lease, or null when repair is required.
  /// A latched gate stays latched here even if the passed snapshot still
  /// shows the pre-repair state; observing repair-durable state while open
  /// latches, retiring in-flight leases whose results must no longer commit.
  BoundRpcLease? admit(SyncMetadataSnapshot snapshot) {
    if (_latched) {
      return null;
    }
    if (!_isBoundAtAllowedPhase(snapshot)) {
      _latched = true;
      _generation++;
      return null;
    }
    return BoundRpcLease._(_generation);
  }

  bool isCurrent(BoundRpcLease lease) => lease._generation == _generation;

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
