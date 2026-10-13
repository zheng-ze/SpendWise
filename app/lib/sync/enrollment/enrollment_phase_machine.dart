part of '../sync_enrollment_service.dart';

// MARK: - Phase Machine

extension SyncEnrollmentPhaseMachine on SyncEnrollmentService {
  Future<void> enroll() async {
    final int repairEpisode = await repairGate.repairEpisode();
    var snapshot = await metadataStore.snapshot();
    final legality = metadataStore.validateHostedOperationState(snapshot);
    if (legality is HostedOperationIllegal) {
      throw SyncEnrollmentException(
        step: 'enroll',
        code: 'invalid_request',
        message: legality.reason,
      );
    }
    while (snapshot.phase != SyncEnrollmentPhase.gateEnabled) {
      await _advance(snapshot, repairEpisode);
      snapshot = await metadataStore.snapshot();
    }
  }

  Future<SyncEnrollmentPhase> _advance(
    SyncMetadataSnapshot snapshot,
    int repairEpisode,
  ) {
    final binding = snapshot.deviceBindingState;
    final phase = snapshot.phase;
    if (binding == SyncDeviceBindingState.notApplicable &&
        phase == SyncEnrollmentPhase.notEnrolled) {
      return _stepPrepareFreshEnrollment();
    }
    if (binding == SyncDeviceBindingState.authorizationRequired &&
        phase == SyncEnrollmentPhase.credentialAcquired) {
      return _stepPrepareFreshEnrollment();
    }
    if (binding == SyncDeviceBindingState.authorizationRequired &&
        phase == SyncEnrollmentPhase.bindingAuthorizationRequired) {
      return _stepBindingAuthorizationRequired(repairEpisode);
    }
    if (binding == SyncDeviceBindingState.bound &&
        phase == SyncEnrollmentPhase.snapshotInProgress) {
      return _stepSnapshotInProgress();
    }
    if (binding == SyncDeviceBindingState.bound &&
        phase == SyncEnrollmentPhase.reconciliationComplete) {
      return _stepReconciliationComplete();
    }
    if (binding == SyncDeviceBindingState.bound &&
        phase == SyncEnrollmentPhase.sessionReauthRequired) {
      return _stepSessionReauthRequired(repairEpisode);
    }
    if (binding == SyncDeviceBindingState.bound &&
        phase == SyncEnrollmentPhase.gateEnabled) {
      return Future.value(SyncEnrollmentPhase.gateEnabled);
    }
    throw SyncEnrollmentException(
      step: 'enroll',
      code: 'invalid_request',
      message:
          'Illegal hosted sync state: binding=${binding.name}, '
          'phase=${phase.name}.',
    );
  }

  // MARK: - E2E Key

  Future<void> _ensureE2EKey() async {
    try {
      await SyncE2EKeyProvider(secretStore: secretStore).accessor();
      return;
    } on SyncE2EKeyUnavailableException catch (error) {
      if (error.reason != SyncE2EKeyUnavailableReason.absent) rethrow;
    }
    final bytes = await resolveE2EKey();
    if (bytes.length != SyncCipher.keyByteCount) {
      throw const SyncE2EKeyUnavailableException(
        SyncE2EKeyUnavailableReason.wrongLength,
      );
    }
    await secretStore.write(syncE2EKeySecretKey, base64Url.encode(bytes));
  }
}
