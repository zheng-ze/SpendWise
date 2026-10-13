part of '../sync_enrollment_service.dart';

// MARK: - Session Step

extension SyncEnrollmentSessionStep on SyncEnrollmentService {
  Future<SyncEnrollmentPhase> _stepSessionReauthRequired(
    int repairEpisode,
  ) async {
    final storedSecret = await secretStore.read(syncDeviceSecretKey);
    if (storedSecret == null) {
      await metadataStore.enterBindingAuthorizationRequired();
      return SyncEnrollmentPhase.bindingAuthorizationRequired;
    }
    if (!isValidSyncDeviceSecret(storedSecret)) {
      await repairGate.withSecretMutationLock(
        () => secretStore.delete(syncDeviceSecretKey),
      );
      await metadataStore.enterBindingAuthorizationRequired();
      return SyncEnrollmentPhase.bindingAuthorizationRequired;
    }
    final challenge = _requireSuccess(
      await authenticator.beginEnrollment(buildBeginRequest()),
      step: 'beginEnrollment',
    );
    final credential = _requireSuccess(
      await authenticator.completeEnrollment(
        await buildCompleteRequest(challenge),
      ),
      step: 'completeEnrollment',
    );
    if (credential.deviceID != await deviceID(database)) {
      throw const CredentialUnavailableException(
        CredentialUnavailableReason.identityFailed,
      );
    }
    await repairGate.withSecretMutationLock(
      () => secretStore.write(
        syncCredentialSecretKey,
        const CredentialCodec().export(credential),
      ),
    );
    final restored = await _commitRepairExit(
      repairEpisode,
      metadataStore.restoreFromSessionReauth,
    );
    return restored;
  }

  Future<T> _commitRepairExit<T>(
    int repairEpisode,
    Future<T> Function() transition,
  ) => repairGate.withMutation((turn) async {
    if (!turn.isCurrentEpisode(repairEpisode)) {
      throw StateError('Sync repair changed before the enrollment exit.');
    }
    final value = await transition();
    turn.release(repairEpisode);
    return value;
  });

  Future<SyncEnrollmentPhase> _stepReconciliationComplete() async {
    await metadataStore.enterGateEnabled();
    return SyncEnrollmentPhase.gateEnabled;
  }

  T _requireSuccess<T>(SyncOutcome<T> outcome, {required String step}) {
    switch (outcome) {
      case SyncSuccess<T>(:final value):
        return value;
      case SyncFailure<T>(:final code, :final message, :final retryAfter):
        throw SyncEnrollmentException(
          step: step,
          code: code,
          message: message,
          retryAfter: retryAfter,
        );
    }
  }
}
