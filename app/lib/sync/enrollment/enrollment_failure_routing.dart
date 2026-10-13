part of '../sync_enrollment_service.dart';

// MARK: - Failure Routing

extension SyncEnrollmentFailureRouting on SyncEnrollmentService {
  Future<Never> _routeCredentialUnavailable(
    CredentialUnavailableException error, {
    required String step,
  }) async {
    if (error.reason == CredentialUnavailableReason.storageFailed ||
        error.reason == CredentialUnavailableReason.identityFailed) {
      throw error;
    }
    final ({CredentialUnavailableReason reason, String code})? route =
        await repairGate.withMutation((turn) async {
          final CredentialUnavailableReason currentReason;
          try {
            await CredentialProvider(
              database: database,
              secretStore: secretStore,
            ).withBoundCredential((credential) => null);
            return null;
          } on CredentialUnavailableException catch (current) {
            currentReason = current.reason;
          }
          final String code;
          switch (currentReason) {
            case CredentialUnavailableReason.deviceSecretAbsent:
              await _enterBindingRepair(turn);
              code = 'device_authorization_required';
            case CredentialUnavailableReason.deviceSecretMalformed:
              await _enterBindingRepair(turn, deleteSecret: true);
              code = 'device_authorization_required';
            case CredentialUnavailableReason.absent:
            case CredentialUnavailableReason.malformed:
              final entry = await _enterSessionRepair(turn);
              if (entry == SessionReauthEntry.rejectedIllegalState) {
                final snapshot = await metadataStore.snapshot();
                code =
                    snapshot.deviceBindingState ==
                        SyncDeviceBindingState.authorizationRequired
                    ? 'device_authorization_required'
                    : 'invalid_request';
              } else {
                code = 'credential_expired';
              }
            case CredentialUnavailableReason.storageFailed:
            case CredentialUnavailableReason.identityFailed:
              throw CredentialUnavailableException(currentReason);
          }
          return (reason: currentReason, code: code);
        });
    if (route == null) {
      throw SyncEnrollmentException(
        step: step,
        code: 'invalid_request',
        message: 'The unavailable credential was superseded.',
      );
    }
    throw SyncEnrollmentException(
      step: step,
      code: route.code,
      message: CredentialUnavailableException(route.reason).toString(),
    );
  }

  Future<Never> _routeBoundFailure({
    required String step,
    required String code,
    required String? message,
    required Duration? retryAfter,
    required BoundDeviceCredential presented,
  }) async {
    if (code == 'credential_expired') {
      await _enterSessionReauthOrThrow(
        step: step,
        code: code,
        message: message,
        retryAfter: retryAfter,
        presented: presented,
      );
    }
    if (code == 'device_authorization_required') {
      await repairGate.withMutation((turn) async {
        final BoundDeviceCredential current;
        try {
          current = await CredentialProvider(
            database: database,
            secretStore: secretStore,
          ).withBoundCredential((credential) => credential);
        } on CredentialUnavailableException {
          return;
        }
        if (!current.hasSameDeviceSecretAs(presented)) return;
        await _enterBindingRepair(turn, deleteSecret: true);
      });
    }
    throw SyncEnrollmentException(
      step: step,
      code: code,
      message: message,
      retryAfter: retryAfter,
    );
  }

  Future<Never> _enterSessionReauthOrThrow({
    required String step,
    required String code,
    required String? message,
    Duration? retryAfter,
    BoundDeviceCredential? presented,
  }) async {
    final entry = await repairGate.withMutation((turn) async {
      if (presented != null) {
        final BoundDeviceCredential current;
        try {
          current = await CredentialProvider(
            database: database,
            secretStore: secretStore,
          ).withBoundCredential((credential) => credential);
        } on CredentialUnavailableException {
          return null;
        }
        if (!current.hasSameBearerAs(presented)) return null;
      }
      return _enterSessionRepair(turn);
    });
    if (entry == null) {
      throw SyncEnrollmentException(
        step: step,
        code: 'invalid_request',
        message: 'The expired credential was superseded.',
      );
    }
    if (entry == SessionReauthEntry.rejectedIllegalState) {
      final current = await metadataStore.snapshot();
      if (current.deviceBindingState ==
          SyncDeviceBindingState.authorizationRequired) {
        throw SyncEnrollmentException(
          step: step,
          code: 'device_authorization_required',
          message: message,
          retryAfter: retryAfter,
        );
      }
      throw SyncEnrollmentException(
        step: step,
        code: 'invalid_request',
        message: message,
        retryAfter: retryAfter,
      );
    }
    throw SyncEnrollmentException(
      step: step,
      code: code,
      message: message,
      retryAfter: retryAfter,
    );
  }

  // MARK: - Repair Entry

  Future<void> _enterBindingRepair(
    GateMutation turn, {
    bool deleteSecret = false,
  }) async {
    final snapshot = await metadataStore.snapshot();
    final alreadyBinding =
        snapshot.deviceBindingState ==
            SyncDeviceBindingState.authorizationRequired &&
        snapshot.phase == SyncEnrollmentPhase.bindingAuthorizationRequired;
    if (!alreadyBinding || repairGate.isOpen) turn.latch();
    if (deleteSecret) await secretStore.delete(syncDeviceSecretKey);
    await metadataStore.enterBindingAuthorizationRequired();
  }

  Future<SessionReauthEntry> _enterSessionRepair(GateMutation turn) async {
    final snapshot = await metadataStore.snapshot();
    final alreadyReauth =
        snapshot.deviceBindingState == SyncDeviceBindingState.bound &&
        snapshot.phase == SyncEnrollmentPhase.sessionReauthRequired;
    final bindingRepair =
        snapshot.deviceBindingState ==
            SyncDeviceBindingState.authorizationRequired &&
        snapshot.phase == SyncEnrollmentPhase.bindingAuthorizationRequired;
    if (bindingRepair) {
      if (repairGate.isOpen) turn.latch();
    } else if (!alreadyReauth || repairGate.isOpen) {
      turn.latch();
    }
    return metadataStore.enterSessionReauthRequired();
  }
}
