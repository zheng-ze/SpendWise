part of '../sync_enrollment_service.dart';

// MARK: - Binding Step

extension SyncEnrollmentBindingStep on SyncEnrollmentService {
  Future<SyncEnrollmentPhase> _stepPrepareFreshEnrollment() async {
    await _ensureE2EKey();
    await repairGate.withSecretMutationLock(
      () => secretStore.delete(syncDeviceSecretKey),
    );
    await metadataStore.enterBindingAuthorizationRequired();
    return SyncEnrollmentPhase.bindingAuthorizationRequired;
  }

  Future<SyncEnrollmentPhase> _stepBindingAuthorizationRequired(
    int repairEpisode,
  ) async {
    await SyncE2EKeyProvider(secretStore: secretStore).accessor();
    final storedSecret = await secretStore.read(syncDeviceSecretKey);
    if (storedSecret != null) {
      if (isValidSyncDeviceSecret(storedSecret)) {
        await _commitRepairExit(
          repairEpisode,
          metadataStore.enterSnapshotInProgress,
        );
        return _stepSnapshotInProgress();
      }
      await repairGate.withSecretMutationLock(
        () => secretStore.delete(syncDeviceSecretKey),
      );
    }
    final currentDeviceID = await deviceID(database);
    final startResponse = _requireSuccess(
      await bindingAuthorizer.startBinding(
        StartDeviceBindingRequest(
          identifier: bindingIdentifier,
          deviceID: currentDeviceID,
        ),
      ),
      step: 'startBinding',
    );
    final otp = await resolveBindingOtp(
      EnrollmentChallenge(<String, Object?>{
        'challenge_id': startResponse.challengeID,
        'expires_at': startResponse.expiresAt.toUtc().toIso8601String(),
        'identifier': bindingIdentifier,
      }),
    );
    final verifyResponse = _requireSuccess(
      await bindingAuthorizer.verifyBinding(
        VerifyDeviceBindingRequest(
          challengeID: startResponse.challengeID,
          identifier: bindingIdentifier,
          deviceID: currentDeviceID,
          otp: otp,
        ),
      ),
      step: 'verifyBinding',
    );
    final sessionCredential = verifyResponse.sessionCredential(currentDeviceID);
    await repairGate.withSecretMutationLock(
      () => secretStore.write(
        syncCredentialSecretKey,
        const CredentialCodec().export(sessionCredential),
      ),
    );
    final beginOutcome = await backend.reconcile(
      sessionCredential,
      verifyResponse.authorizeBegin(),
    );
    final ReconcileResponse beginResponse;
    switch (beginOutcome) {
      case SyncSuccess<ReconcileResponse>(:final value):
        beginResponse = value;
      case SyncFailure<ReconcileResponse>(
        :final code,
        :final message,
        :final retryAfter,
      ):
        throw SyncEnrollmentException(
          step: 'reconcileBegin',
          code: code,
          message: message,
          retryAfter: retryAfter,
        );
    }
    final rawSecret =
        beginResponse.wire[SyncEnrollmentService._deviceSecretWireKey];
    if (rawSecret is! String || !isValidSyncDeviceSecret(rawSecret)) {
      throw const SyncEnrollmentException(
        step: 'reconcileBegin',
        code: 'incompatible_server',
        message:
            'Authorization-bearing Begin must carry a valid device_secret.',
      );
    }
    await repairGate.withSecretMutationLock(
      () => secretStore.write(syncDeviceSecretKey, rawSecret),
    );
    await _commitRepairExit(
      repairEpisode,
      metadataStore.enterSnapshotInProgress,
    );
    final bound = await CredentialProvider(
      database: database,
      secretStore: secretStore,
    ).withBoundCredential((credential) => credential);
    return _completeSnapshot(bound, beginResponse);
  }
}
