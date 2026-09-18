import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:spendwise/persistence/device_identity.dart';
import 'package:spendwise/persistence/ledger_database.dart';
import 'package:spendwise/sync/credential_provider.dart';
import 'package:spendwise/sync/secret_store.dart';
import 'package:spendwise/sync/sync_e2e_key_provider.dart';
import 'package:spendwise/sync/sync_metadata_store.dart';
import 'package:spendwise/sync/sync_secret_keys.dart';
import 'package:sync/sync.dart';

/// Error thrown when a remote enrollment step fails.
///
/// The [step] names the enrollment step that failed (`beginEnrollment`,
/// `completeEnrollment`, `reconcileBegin`, or `reconcileComplete`), [code] is
/// the underlying [SyncFailure.code], and [message]/[retryAfter] carry the
/// failure details through. The enrollment phase is left untouched so a later
/// `enroll()` call resumes from the same durably recorded phase.
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

/// Drives enrollment through [SyncMetadataStore]'s durable phases.
///
/// Each step performs its underlying work first and records the durable phase
/// only once that work completes, so a crash at any boundary resumes safely
/// from the recorded phase on the next [enroll] call. Credential presence
/// alone never enables writes; only the durable `reconciliationComplete`
/// phase permits the write-gate flip.
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
    required this.resolveCollectionHashes,
  });

  final SyncAuthenticator authenticator;
  final SyncBackend backend;
  final SyncMetadataStore metadataStore;
  final SecretStore secretStore;
  final LedgerDatabase database;
  final BeginEnrollmentRequest Function() buildBeginRequest;
  final Future<CompleteEnrollmentRequest> Function(
    EnrollmentChallenge challenge,
  )
  buildCompleteRequest;
  final Future<Uint8List> Function() resolveE2EKey;
  final Future<Map<SyncCollection, String>> Function() resolveCollectionHashes;

  /// Advances enrollment until the gate is durably enabled.
  Future<void> enroll() async {
    var phase = (await metadataStore.snapshot()).phase;
    while (phase != SyncEnrollmentPhase.gateEnabled) {
      phase = await _advance(phase);
    }
  }

  Future<SyncEnrollmentPhase> _advance(SyncEnrollmentPhase phase) =>
      switch (phase) {
        SyncEnrollmentPhase.notEnrolled => _stepNotEnrolled(),
        SyncEnrollmentPhase.credentialAcquired => _stepCredentialAcquired(),
        SyncEnrollmentPhase.snapshotInProgress => _stepSnapshotInProgress(),
        SyncEnrollmentPhase.reconciliationComplete =>
          _stepReconciliationComplete(),
        SyncEnrollmentPhase.gateEnabled => throw StateError('unreachable'),
      };

  /// Acquires the device credential, reusing a valid stored one when the
  /// previous run crashed after writing it but before recording the phase.
  Future<SyncEnrollmentPhase> _stepNotEnrolled() async {
    final stored = await secretStore.read(syncCredentialSecretKey);
    if (stored != null) {
      final matches = await _storedCredentialMatchesDevice(stored);
      if (matches) {
        await metadataStore.setEnrollmentPhase(
          SyncEnrollmentPhase.credentialAcquired,
        );
        return SyncEnrollmentPhase.credentialAcquired;
      }
      await secretStore.delete(syncCredentialSecretKey);
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
    await metadataStore.setEnrollmentPhase(
      SyncEnrollmentPhase.credentialAcquired,
    );
    return SyncEnrollmentPhase.credentialAcquired;
  }

  /// Returns true when [stored] restores to a credential for this device.
  Future<bool> _storedCredentialMatchesDevice(String stored) async {
    final DeviceCredential restored;
    try {
      restored = const CredentialCodec().restore(stored);
    } on FormatException {
      return false;
    }
    return restored.deviceID == await deviceID(database);
  }

  /// Ensures a valid E2E key secret exists before snapshot work begins.
  ///
  /// A present-but-invalid key is a hard failure: it is never deleted or
  /// overwritten here, and the phase stays at `credentialAcquired`.
  Future<SyncEnrollmentPhase> _stepCredentialAcquired() async {
    final stored = await secretStore.read(syncE2EKeySecretKey);
    if (stored != null) {
      decodeAndValidateSyncE2EKey(stored);
    } else {
      final bytes = await resolveE2EKey();
      if (bytes.length != SyncCipher.keyByteCount) {
        throw const SyncE2EKeyUnavailableException(
          SyncE2EKeyUnavailableReason.wrongLength,
        );
      }
      await secretStore.write(syncE2EKeySecretKey, base64Url.encode(bytes));
    }
    await metadataStore.setEnrollmentPhase(
      SyncEnrollmentPhase.snapshotInProgress,
    );
    return SyncEnrollmentPhase.snapshotInProgress;
  }

  /// Runs the begin/complete reconcile round trip, then records completion.
  Future<SyncEnrollmentPhase> _stepSnapshotInProgress() async {
    final credential = await CredentialProvider(
      database: database,
      secretStore: secretStore,
    ).withCredential((restored) => restored);
    _requireSuccess(
      await backend.reconcile(credential, const BeginReconcile()),
      step: 'reconcileBegin',
    );
    final hashes = await resolveCollectionHashes();
    _requireSuccess(
      await backend.reconcile(
        credential,
        CompleteReconcile(collectionHashes: hashes),
      ),
      step: 'reconcileComplete',
    );
    await metadataStore.setEnrollmentPhase(
      SyncEnrollmentPhase.reconciliationComplete,
    );
    return SyncEnrollmentPhase.reconciliationComplete;
  }

  /// Flips the write gate, then records the terminal phase.
  Future<SyncEnrollmentPhase> _stepReconciliationComplete() async {
    await metadataStore.setWriteEnabled(true);
    await metadataStore.setEnrollmentPhase(SyncEnrollmentPhase.gateEnabled);
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
