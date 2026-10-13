part of '../sync_coordinator.dart';

// MARK: - Bound RPC

extension SyncCoordinatorBoundRpc on SyncCoordinator {
  Future<_BoundRpcResult<T>> _sendBoundRpc<T>({
    required String operation,
    required Future<SyncOutcome<T>> Function(BoundDeviceCredential credential)
    call,
  }) async {
    final BoundRpcAdmission admission = await repairGate.admit(
      metadataStore.snapshot,
    );
    final SyncMetadataSnapshot snapshot = admission.snapshot;
    final HostedOperationLegality legality = metadataStore
        .validateHostedOperationState(snapshot);
    if (legality is HostedOperationIllegal) {
      throw StateError('Cannot $operation: ${legality.reason}');
    }
    final BoundRpcLease? lease = admission.lease;
    if (lease == null) {
      throw StateError(
        'Cannot $operation while sync repair is required '
        '(binding=${snapshot.deviceBindingState.name}, '
        'phase=${snapshot.phase.name}).',
      );
    }
    final _PresentedBound presented;
    try {
      presented = await _credentialProvider.withBoundCredentialAndSecret(
        (BoundDeviceCredential credential, String deviceSecret) =>
            _PresentedBound(credential: credential, deviceSecret: deviceSecret),
      );
    } on CredentialUnavailableException catch (error) {
      await _routeCoordinatorCredentialUnavailable(operation, error);
    }
    if (!repairGate.isCurrent(lease)) {
      throw StateError(
        'Cannot $operation: sync repair began while the request was prepared.',
      );
    }
    final SyncOutcome<T> outcome = await call(presented.credential);
    switch (outcome) {
      case SyncSuccess<T>():
        if (!repairGate.isCurrent(lease)) {
          throw StateError(
            'Cannot $operation: sync repair began while the request was '
            'in flight; its result is discarded.',
          );
        }
        return _BoundRpcResult(outcome, lease);
      case CredentialExpired<T>():
        await _routeCoordinatorCredentialExpired(
          operation,
          presented.credential,
        );
      case DeviceAuthorizationRequired<T>():
        await _routeCoordinatorDeviceAuthorizationRequired(
          operation,
          presented.deviceSecret,
        );
      case SyncFailure<T>():
        return _BoundRpcResult(outcome, lease);
    }
  }

  // MARK: - Credential Routing

  Future<Never> _routeCoordinatorCredentialUnavailable(
    String operation,
    CredentialUnavailableException error,
  ) async {
    if (error.reason == CredentialUnavailableReason.storageFailed ||
        error.reason == CredentialUnavailableReason.identityFailed) {
      throw error;
    }
    final CredentialUnavailableReason? reason = await repairGate.withMutation((
      turn,
    ) async {
      final CredentialUnavailableReason currentReason;
      try {
        await _credentialProvider.withBoundCredential((credential) => null);
        return null;
      } on CredentialUnavailableException catch (current) {
        currentReason = current.reason;
      }
      switch (currentReason) {
        case CredentialUnavailableReason.deviceSecretAbsent:
          await _latchForBindingRepair(turn);
          await metadataStore.enterBindingAuthorizationRequired();
        case CredentialUnavailableReason.deviceSecretMalformed:
          await _latchForBindingRepair(turn);
          await _secretStore.delete(syncDeviceSecretKey);
          await metadataStore.enterBindingAuthorizationRequired();
        case CredentialUnavailableReason.absent:
        case CredentialUnavailableReason.malformed:
          await _latchForSessionRepair(turn);
          await metadataStore.enterSessionReauthRequired();
        case CredentialUnavailableReason.storageFailed:
        case CredentialUnavailableReason.identityFailed:
          throw CredentialUnavailableException(currentReason);
      }
      return currentReason;
    });
    switch (reason) {
      case null:
        throw StateError(
          'Cannot $operation: the unavailable credential was superseded.',
        );
      case CredentialUnavailableReason.deviceSecretAbsent:
        throw StateError(
          'Cannot $operation: the device binding is missing, '
          'binding repair is required.',
        );
      case CredentialUnavailableReason.deviceSecretMalformed:
        throw StateError(
          'Cannot $operation: the device binding is malformed, '
          'binding repair is required.',
        );
      case CredentialUnavailableReason.absent:
      case CredentialUnavailableReason.malformed:
        throw StateError(
          'Cannot $operation: the session credential is unavailable, '
          'session reauth is required.',
        );
      case CredentialUnavailableReason.storageFailed:
      case CredentialUnavailableReason.identityFailed:
        throw StateError('Cannot $operation: credential resolution failed.');
    }
  }

  Future<Never> _routeCoordinatorCredentialExpired(
    String operation,
    BoundDeviceCredential presented,
  ) async {
    final SessionReauthEntry? entry = await repairGate.withMutation((
      turn,
    ) async {
      final BoundDeviceCredential current;
      try {
        current = await _credentialProvider.withBoundCredential(
          (credential) => credential,
        );
      } on CredentialUnavailableException {
        return null;
      }
      if (!current.hasSameBearerAs(presented)) return null;
      await _latchForSessionRepair(turn);
      return metadataStore.enterSessionReauthRequired();
    });
    if (entry == null) {
      throw StateError(
        'Cannot $operation: the bearer expired for a superseded credential.',
      );
    }
    if (entry == SessionReauthEntry.rejectedIllegalState) {
      throw StateError(
        'Cannot $operation: the bearer expired while binding repair is '
        'required.',
      );
    }
    throw StateError(
      'Cannot $operation: the bearer expired, session reauth is required.',
    );
  }

  Future<Never> _routeCoordinatorDeviceAuthorizationRequired(
    String operation,
    String presentedSecret,
  ) async {
    await repairGate.withMutation((turn) async {
      final String? stored;
      try {
        stored = await _secretStore.read(syncDeviceSecretKey);
      } catch (_) {
        return;
      }
      if (stored != presentedSecret) {
        return;
      }
      await _latchForBindingRepair(turn);
      await _secretStore.delete(syncDeviceSecretKey);
      await metadataStore.enterBindingAuthorizationRequired();
    });
    throw StateError(
      'Cannot $operation: the device binding was rejected, '
      'binding repair is required.',
    );
  }

  // MARK: - Repair Latches

  Future<void> _latchForBindingRepair(GateMutation turn) async {
    final snapshot = await metadataStore.snapshot();
    final alreadyBinding =
        snapshot.deviceBindingState ==
            SyncDeviceBindingState.authorizationRequired &&
        snapshot.phase == SyncEnrollmentPhase.bindingAuthorizationRequired;
    if (!alreadyBinding || repairGate.isOpen) turn.latch();
  }

  Future<void> _latchForSessionRepair(GateMutation turn) async {
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
      return;
    }
    if (!alreadyReauth || repairGate.isOpen) turn.latch();
  }
}
