part of '../sync_enrollment_service.dart';

// MARK: - Snapshot Step

extension SyncEnrollmentSnapshotStep on SyncEnrollmentService {
  Future<SyncEnrollmentPhase> _stepSnapshotInProgress() async {
    final BoundDeviceCredential bound;
    try {
      bound = await CredentialProvider(
        database: database,
        secretStore: secretStore,
      ).withBoundCredential((credential) => credential);
    } on CredentialUnavailableException catch (error) {
      await _routeCredentialUnavailable(error, step: 'reconcileBegin');
    }
    final beginOutcome = await backend.reconcile(bound, const BeginReconcile());
    switch (beginOutcome) {
      case SyncSuccess<ReconcileResponse>(:final value):
        if (value.wire.containsKey(
          SyncEnrollmentService._deviceSecretWireKey,
        )) {
          throw const SyncEnrollmentException(
            step: 'reconcileBegin',
            code: 'incompatible_server',
            message: 'Bound Begin must not carry device_secret.',
          );
        }
        return _completeSnapshot(bound, value);
      case SyncFailure<ReconcileResponse>(
        :final code,
        :final message,
        :final retryAfter,
      ):
        if (code == 'credential_expired' ||
            code == 'device_authorization_required') {
          await _routeBoundFailure(
            step: 'reconcileBegin',
            code: code,
            message: message,
            retryAfter: retryAfter,
            presented: bound,
          );
        }
        throw SyncEnrollmentException(
          step: 'reconcileBegin',
          code: code,
          message: message,
          retryAfter: retryAfter,
        );
    }
  }

  Future<SyncEnrollmentPhase> _completeSnapshot(
    BoundDeviceCredential credential,
    ReconcileResponse beginResponse,
  ) async {
    final context = _decodeContext(beginResponse);
    final hasher = buildSnapshotHasher(credential);
    var hashes = await _hashAll(hasher, context, credential);
    var completeOutcome = await backend.reconcile(
      credential,
      CompleteReconcile(collectionHashes: hashes),
    );
    if (completeOutcome is SnapshotHashMismatch<ReconcileResponse>) {
      final mismatched = completeOutcome.mismatchedCollection;
      if (mismatched == null) {
        throw SyncEnrollmentException(
          step: 'reconcileComplete',
          code: completeOutcome.code,
          message: completeOutcome.message,
        );
      }
      hashes = Map<SyncCollection, String>.unmodifiable(
        <SyncCollection, String>{
          ...hashes,
          mismatched: await _rehash(hasher, context, mismatched, credential),
        },
      );
      completeOutcome = await backend.reconcile(
        credential,
        CompleteReconcile(collectionHashes: hashes),
      );
    }
    switch (completeOutcome) {
      case SyncSuccess<ReconcileResponse>(:final value):
        final writeProof = value.wire[SyncEnrollmentService._writeProofWireKey];
        if (writeProof is String) {
          await secretStore.write(syncWriteProofSecretKey, writeProof);
        }
        await metadataStore.enterReconciliationComplete();
        return SyncEnrollmentPhase.reconciliationComplete;
      case SyncFailure<ReconcileResponse>(
        :final code,
        :final message,
        :final retryAfter,
      ):
        if (code == 'credential_expired' ||
            code == 'device_authorization_required') {
          await _routeBoundFailure(
            step: 'reconcileComplete',
            code: code,
            message: message,
            retryAfter: retryAfter,
            presented: credential,
          );
        }
        throw SyncEnrollmentException(
          step: 'reconcileComplete',
          code: code,
          message: message,
          retryAfter: retryAfter,
        );
    }
  }

  // MARK: - Snapshot Hashing

  ReconciliationContext _decodeContext(ReconcileResponse beginResponse) {
    try {
      return beginResponse.reconciliationContext;
    } on FormatException catch (error) {
      throw SyncEnrollmentException(
        step: 'reconcileBegin',
        code: 'invalid_request',
        message: error.message,
      );
    }
  }

  Future<Map<SyncCollection, String>> _hashAll(
    ReconciliationSnapshotHasher hasher,
    ReconciliationContext context,
    BoundDeviceCredential credential,
  ) async {
    try {
      return await hasher.hashAll(context);
    } on ReconciliationSnapshotException catch (error) {
      await _routeBoundFailure(
        step: 'reconcileBegin',
        code: error.code,
        message: error.message,
        retryAfter: error.retryAfter,
        presented: credential,
      );
    }
  }

  Future<String> _rehash(
    ReconciliationSnapshotHasher hasher,
    ReconciliationContext context,
    SyncCollection collection,
    BoundDeviceCredential credential,
  ) async {
    try {
      return await hasher.hashCollection(context, collection);
    } on ReconciliationSnapshotException catch (error) {
      await _routeBoundFailure(
        step: 'reconcileComplete',
        code: error.code,
        message: error.message,
        retryAfter: error.retryAfter,
        presented: credential,
      );
    }
  }
}
