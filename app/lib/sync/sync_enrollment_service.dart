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
