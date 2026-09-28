import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:spendwise/persistence/device_identity.dart';
import 'package:spendwise/persistence/ledger_database.dart';
import 'package:spendwise/sync/credential_provider.dart';
import 'package:spendwise/sync/reconciliation_snapshot_hasher.dart';
import 'package:spendwise/sync/secret_store.dart';
import 'package:spendwise/sync/sync_e2e_key_provider.dart';
import 'package:spendwise/sync/sync_metadata_store.dart';
import 'package:spendwise/sync/sync_repair_gate.dart';
import 'package:spendwise/sync/sync_secret_keys.dart';
import 'package:sync/sync.dart';

final class SyncEnrollmentException implements Exception {
  const SyncEnrollmentException({
    required this.step,
    required this.code,
    this.message,
    this.retryAfter,
  });

  final String step;
  final String code;
  final String? message;
  final Duration? retryAfter;

  @override
  String toString() =>
      'SyncEnrollmentException($step, $code${message != null ? ": $message" : ""})';
}

final class SyncEnrollmentService {
  SyncEnrollmentService({
    required this.authenticator,
    required this.backend,
    required this.metadataStore,
    required this.secretStore,
    required this.database,
    required this.buildBeginRequest,
    required this.buildCompleteRequest,
    required this.resolveE2EKey,
    required this.buildSnapshotHasher,
    required this.bindingAuthorizer,
    required this.bindingIdentifier,
    required this.resolveBindingOtp,
    SyncRepairGate? repairGate,
  }) : repairGate = repairGate ?? SyncRepairGate.forDatabase(database);

  final SyncAuthenticator authenticator;
  final SyncBackend backend;
  final SyncMetadataStore metadataStore;
  final SecretStore secretStore;
  final LedgerDatabase database;
  final SyncRepairGate repairGate;
  final BeginEnrollmentRequest Function() buildBeginRequest;
  final Future<CompleteEnrollmentRequest> Function(
    EnrollmentChallenge challenge,
  )
  buildCompleteRequest;
  final Future<Uint8List> Function() resolveE2EKey;

  final ReconciliationSnapshotHasher Function(SyncCredential credential)
  buildSnapshotHasher;

  final DeviceBindingAuthorizer bindingAuthorizer;
  final String bindingIdentifier;
  final Future<String> Function(EnrollmentChallenge challenge)
  resolveBindingOtp;

  Future<void> enroll() async {
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
      await _advance(snapshot);
      snapshot = await metadataStore.snapshot();
    }
  }

  Future<SyncEnrollmentPhase> _advance(SyncMetadataSnapshot snapshot) {
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
      return _stepBindingAuthorizationRequired();
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
      return _stepSessionReauthRequired();
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

  Future<SyncEnrollmentPhase> _stepPrepareFreshEnrollment() async {
    await _ensureE2EKey();
    await repairGate.withSecretMutationLock(
      () => secretStore.delete(syncDeviceSecretKey),
    );
    await metadataStore.enterBindingAuthorizationRequired();
    return SyncEnrollmentPhase.bindingAuthorizationRequired;
  }

  Future<SyncEnrollmentPhase> _stepBindingAuthorizationRequired() async {
    await SyncE2EKeyProvider(secretStore: secretStore).accessor();
    final storedSecret = await secretStore.read(syncDeviceSecretKey);
    if (storedSecret != null) {
      if (isValidSyncDeviceSecret(storedSecret)) {
        await metadataStore.enterSnapshotInProgress();
        repairGate.release();
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
    await secretStore.write(
      syncCredentialSecretKey,
      const CredentialCodec().export(sessionCredential),
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
    final rawSecret = beginResponse.wire[_deviceSecretWireKey];
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
    await metadataStore.enterSnapshotInProgress();
    repairGate.release();
    final bound = await CredentialProvider(
      database: database,
      secretStore: secretStore,
    ).withBoundCredential((credential) => credential);
    return _completeSnapshot(bound, beginResponse);
  }

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
        if (value.wire.containsKey(_deviceSecretWireKey)) {
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
    var hashes = await _hashAll(hasher, context);
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
          mismatched: await _rehash(hasher, context, mismatched),
        },
      );
      completeOutcome = await backend.reconcile(
        credential,
        CompleteReconcile(collectionHashes: hashes),
      );
    }
    switch (completeOutcome) {
      case SyncSuccess<ReconcileResponse>(:final value):
        final writeProof = value.wire[_writeProofWireKey];
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

  Future<SyncEnrollmentPhase> _stepSessionReauthRequired() async {
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
    await secretStore.write(
      syncCredentialSecretKey,
      const CredentialCodec().export(credential),
    );
    final restored = await metadataStore.restoreFromSessionReauth();
    repairGate.release();
    return restored;
  }

  Future<Never> _routeCredentialUnavailable(
    CredentialUnavailableException error, {
    required String step,
  }) async {
    switch (error.reason) {
      case CredentialUnavailableReason.deviceSecretAbsent:
        await metadataStore.enterBindingAuthorizationRequired();
        throw SyncEnrollmentException(
          step: step,
          code: 'device_authorization_required',
          message: error.toString(),
        );
      case CredentialUnavailableReason.deviceSecretMalformed:
        await repairGate.withSecretMutationLock(
          () => secretStore.delete(syncDeviceSecretKey),
        );
        await metadataStore.enterBindingAuthorizationRequired();
        throw SyncEnrollmentException(
          step: step,
          code: 'device_authorization_required',
          message: error.toString(),
        );
      case CredentialUnavailableReason.absent:
      case CredentialUnavailableReason.malformed:
        await _enterSessionReauthOrThrow(
          step: step,
          code: 'credential_expired',
          message: error.toString(),
        );
      case CredentialUnavailableReason.storageFailed:
      case CredentialUnavailableReason.identityFailed:
        throw error;
    }
  }

  Future<Never> _routeBoundFailure({
    required String step,
    required String code,
    required String? message,
    required Duration? retryAfter,
  }) async {
    if (code == 'credential_expired') {
      await _enterSessionReauthOrThrow(
        step: step,
        code: code,
        message: message,
        retryAfter: retryAfter,
      );
    }
    if (code == 'device_authorization_required') {
      await repairGate.withSecretMutationLock(
        () => secretStore.delete(syncDeviceSecretKey),
      );
      await metadataStore.enterBindingAuthorizationRequired();
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
  }) async {
    final entry = await metadataStore.enterSessionReauthRequired();
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

  static const _writeProofWireKey = 'write_proof';
  static const _deviceSecretWireKey = 'device_secret';

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
  ) async {
    try {
      return await hasher.hashAll(context);
    } on ReconciliationSnapshotException catch (error) {
      await _routeBoundFailure(
        step: 'reconcileBegin',
        code: error.code,
        message: error.message,
        retryAfter: error.retryAfter,
      );
    }
  }

  Future<String> _rehash(
    ReconciliationSnapshotHasher hasher,
    ReconciliationContext context,
    SyncCollection collection,
  ) async {
    try {
      return await hasher.hashCollection(context, collection);
    } on ReconciliationSnapshotException catch (error) {
      await _routeBoundFailure(
        step: 'reconcileComplete',
        code: error.code,
        message: error.message,
        retryAfter: error.retryAfter,
      );
    }
  }

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
