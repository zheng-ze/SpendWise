import 'dart:async';

import 'package:spendwise/persistence/ledger_database.dart';
import 'package:spendwise/sync/sync_metadata_store.dart';

final class BoundRpcLease {
  const BoundRpcLease._(this._generation);

  final int _generation;
}

final class BoundRpcAdmission {
  const BoundRpcAdmission(this.snapshot, this.lease);

  final SyncMetadataSnapshot snapshot;
  final BoundRpcLease? lease;
}

final class GateMutation {
  GateMutation._(this._gate);

  final SyncRepairGate _gate;
  bool _active = true;

  int latch() {
    if (!_active) throw StateError('The gate mutation turn has ended.');
    return _gate._latch();
  }

  bool isCurrentEpisode(int generation) {
    if (!_active) throw StateError('The gate mutation turn has ended.');
    return _gate._generation == generation;
  }

  void release(int generation) {
    if (!_active) throw StateError('The gate mutation turn has ended.');
    _gate._release(generation);
  }
}

final class SyncRepairGate {
  SyncRepairGate._();

  static final Expando<SyncRepairGate> _instances = Expando<SyncRepairGate>(
    'SyncRepairGate',
  );

  factory SyncRepairGate.forDatabase(LedgerDatabase database) =>
      _instances[database] ??= SyncRepairGate._();

  bool _latched = false;
  bool _initialized = false;
  int _generation = 0;
  Future<void> _mutationTail = Future<void>.value();

  bool get isOpen => !_latched;

  int _latch() {
    _initialized = true;
    _latched = true;
    return ++_generation;
  }

  Future<int> latch() => withMutation((turn) async => turn.latch());

  void _release(int generation) {
    _initialized = true;
    if (_latched && _generation == generation) {
      _latched = false;
      _generation++;
    }
  }

  Future<void> release(int generation) => withMutation((turn) async {
    turn.release(generation);
  });

  Future<int> repairEpisode() => withMutation((_) async => _generation);

  Future<void> reseed(SyncMetadataSnapshot snapshot) => withMutation((_) async {
    if (_initialized) return;
    _initialized = true;
    _latched = !_isBoundAtAllowedPhase(snapshot);
  });

  Future<BoundRpcAdmission> admit(
    Future<SyncMetadataSnapshot> Function() readSnapshot,
  ) => withMutation((_) async {
    final snapshot = await readSnapshot();
    _initialized = true;
    if (_latched) return BoundRpcAdmission(snapshot, null);
    if (!_isBoundAtAllowedPhase(snapshot)) {
      _latch();
      return BoundRpcAdmission(snapshot, null);
    }
    return BoundRpcAdmission(snapshot, BoundRpcLease._(_generation));
  });

  bool isCurrent(BoundRpcLease lease) =>
      !_latched && lease._generation == _generation;

  Future<T> withCurrentLease<T>(
    BoundRpcLease lease,
    Future<T> Function() work,
  ) => withMutation((_) async {
    if (!isCurrent(lease)) {
      throw StateError(
        'Sync repair began before the bound result could commit.',
      );
    }
    return work();
  });

  Future<T> withMutation<T>(Future<T> Function(GateMutation turn) work) async {
    final prior = _mutationTail;
    final turn = Completer<void>();
    _mutationTail = turn.future;
    await prior;
    final mutation = GateMutation._(this);
    try {
      return await work(mutation);
    } finally {
      mutation._active = false;
      turn.complete();
    }
  }

  Future<T> withSecretMutationLock<T>(Future<T> Function() work) =>
      withMutation((_) => work());

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
