part of '../sync_metadata_store.dart';

// MARK: - Hosted State Validation

extension SyncMetadataStoreValidation on SyncMetadataStore {
  HostedOperationLegality validateHostedOperationState(
    SyncMetadataSnapshot snapshot,
  ) {
    final binding = snapshot.deviceBindingState;
    final phase = snapshot.phase;
    final writes = snapshot.writeEnabled;
    final resume = snapshot.reauthResumePhase;
    switch (binding) {
      case SyncDeviceBindingState.notApplicable:
        if (phase == SyncEnrollmentPhase.notEnrolled &&
            !writes &&
            resume == null) {
          return const HostedOperationLegal();
        }
        break;
      case SyncDeviceBindingState.authorizationRequired:
        if (!writes &&
            resume == null &&
            (phase == SyncEnrollmentPhase.credentialAcquired ||
                phase == SyncEnrollmentPhase.bindingAuthorizationRequired)) {
          return const HostedOperationLegal();
        }
        break;
      case SyncDeviceBindingState.bound:
        switch (phase) {
          case SyncEnrollmentPhase.snapshotInProgress:
          case SyncEnrollmentPhase.reconciliationComplete:
            if (!writes && resume == null) {
              return const HostedOperationLegal();
            }
            break;
          case SyncEnrollmentPhase.gateEnabled:
            if (writes && resume == null) {
              return const HostedOperationLegal();
            }
            break;
          case SyncEnrollmentPhase.sessionReauthRequired:
            if (!writes &&
                (resume == SyncEnrollmentPhase.snapshotInProgress ||
                    resume == SyncEnrollmentPhase.reconciliationComplete ||
                    resume == SyncEnrollmentPhase.gateEnabled)) {
              return const HostedOperationLegal();
            }
            break;
          case SyncEnrollmentPhase.notEnrolled:
          case SyncEnrollmentPhase.credentialAcquired:
          case SyncEnrollmentPhase.bindingAuthorizationRequired:
            break;
        }
        break;
    }
    return HostedOperationIllegal(
      'Illegal hosted sync state: binding=${binding.name}, '
      'phase=${phase.name}, writes=$writes, resume=${resume?.name}.',
    );
  }
}
