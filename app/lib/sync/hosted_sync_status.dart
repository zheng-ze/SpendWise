import 'package:flutter/foundation.dart';

import 'package:spendwise/sync/sync_metadata_store.dart';

@immutable
sealed class HostedSyncStatus {
  const HostedSyncStatus();
}

@immutable
final class HostedSyncNoSelection extends HostedSyncStatus {
  const HostedSyncNoSelection();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is HostedSyncNoSelection;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'HostedSyncNoSelection()';
}

@immutable
final class HostedSyncSetupPending extends HostedSyncStatus {
  const HostedSyncSetupPending();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is HostedSyncSetupPending;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'HostedSyncSetupPending()';
}

@immutable
final class HostedSyncReady extends HostedSyncStatus {
  const HostedSyncReady();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is HostedSyncReady;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'HostedSyncReady()';
}

@immutable
final class HostedSyncBindingRepair extends HostedSyncStatus {
  const HostedSyncBindingRepair();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is HostedSyncBindingRepair;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'HostedSyncBindingRepair()';
}

@immutable
final class HostedSyncSessionReauth extends HostedSyncStatus {
  const HostedSyncSessionReauth();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is HostedSyncSessionReauth;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'HostedSyncSessionReauth()';
}

@immutable
final class HostedSyncUnsupportedV2 extends HostedSyncStatus {
  const HostedSyncUnsupportedV2();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is HostedSyncUnsupportedV2;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'HostedSyncUnsupportedV2()';
}

@immutable
final class HostedSyncUnavailable extends HostedSyncStatus {
  const HostedSyncUnavailable();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is HostedSyncUnavailable;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'HostedSyncUnavailable()';
}

HostedSyncStatus projectHostedSyncStatus(SyncMetadataSnapshot snapshot) {
  if (snapshot.backend == SyncBackendKind.custom) {
    return const HostedSyncUnsupportedV2();
  }
  if (snapshot.backend == null) {
    final binding = snapshot.deviceBindingState;
    final phase = snapshot.phase;
    if (!snapshot.writeEnabled &&
        snapshot.reauthResumePhase == null &&
        binding == SyncDeviceBindingState.notApplicable &&
        phase == SyncEnrollmentPhase.notEnrolled) {
      return const HostedSyncNoSelection();
    }
    return const HostedSyncUnavailable();
  }
  final binding = snapshot.deviceBindingState;
  final phase = snapshot.phase;
  final writes = snapshot.writeEnabled;
  final resume = snapshot.reauthResumePhase;
  if (!writes &&
      resume == null &&
      binding == SyncDeviceBindingState.authorizationRequired &&
      phase == SyncEnrollmentPhase.bindingAuthorizationRequired) {
    return const HostedSyncBindingRepair();
  }
  if (!writes &&
      binding == SyncDeviceBindingState.bound &&
      phase == SyncEnrollmentPhase.sessionReauthRequired &&
      (resume == SyncEnrollmentPhase.snapshotInProgress ||
          resume == SyncEnrollmentPhase.reconciliationComplete ||
          resume == SyncEnrollmentPhase.gateEnabled)) {
    return const HostedSyncSessionReauth();
  }
  if (writes &&
      resume == null &&
      binding == SyncDeviceBindingState.bound &&
      phase == SyncEnrollmentPhase.gateEnabled) {
    return const HostedSyncReady();
  }
  if (_isLegalSetupPending(
    binding: binding,
    phase: phase,
    writes: writes,
    resume: resume,
  )) {
    return const HostedSyncSetupPending();
  }
  return const HostedSyncUnavailable();
}

// Mirrors the non-repair tuples of SyncMetadataStore.validateHostedOperationState
// so corrupt metadata projects to unavailable instead of healthy.
bool _isLegalSetupPending({
  required SyncDeviceBindingState binding,
  required SyncEnrollmentPhase phase,
  required bool writes,
  required SyncEnrollmentPhase? resume,
}) {
  if (writes || resume != null) return false;
  return switch ((binding, phase)) {
    (SyncDeviceBindingState.notApplicable, SyncEnrollmentPhase.notEnrolled) ||
    (
      SyncDeviceBindingState.authorizationRequired,
      SyncEnrollmentPhase.credentialAcquired,
    ) ||
    (SyncDeviceBindingState.bound, SyncEnrollmentPhase.snapshotInProgress) ||
    (
      SyncDeviceBindingState.bound,
      SyncEnrollmentPhase.reconciliationComplete,
    ) => true,
    _ => false,
  };
}
