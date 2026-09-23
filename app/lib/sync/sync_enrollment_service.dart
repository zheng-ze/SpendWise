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
    required this.buildSnapshotHasher,
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

  /// Builds the attempt-scoped hasher that pages the `BeginReconcile`
  /// snapshot under its returned device-bound reconciliation context
  /// (reconciliation ID, fixed snapshot watermark, expiry) and hashes the
  /// fetched envelopes, per `docs/sync-protocol.md` section 4.
  final ReconciliationSnapshotHasher Function(SyncCredential credential)
  buildSnapshotHasher;

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
  ///
  /// Pages the snapshot through the attempt hasher under `BeginReconcile`'s
  /// context. A `snapshot_hash_mismatch` naming a collection re-pages only
  /// that collection under the same context, replaces its digest, and retries
  /// `CompleteReconcile` exactly once. A second mismatch, or one naming no
  /// (or an unrecognized) collection, fails without advancing the phase, so
  /// the write gate stays closed. Durably captures the single-use write-proof
  /// `CompleteReconcile` returns before recording completion, so the first
  /// post-reconciliation push can supply it.
  Future<SyncEnrollmentPhase> _stepSnapshotInProgress() async {
    final credential = await CredentialProvider(
      database: database,
      secretStore: secretStore,
    ).withCredential((restored) => restored);
    final beginResponse = _requireSuccess(
      await backend.reconcile(credential, const BeginReconcile()),
      step: 'reconcileBegin',
    );
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
    final completeResponse = _requireSuccess(
      completeOutcome,
      step: 'reconcileComplete',
    );
    final writeProof = completeResponse.wire[_writeProofWireKey];
    if (writeProof is String) {
      await secretStore.write(syncWriteProofSecretKey, writeProof);
    }
    await metadataStore.setEnrollmentPhase(
      SyncEnrollmentPhase.reconciliationComplete,
    );
    return SyncEnrollmentPhase.reconciliationComplete;
  }

  static const _writeProofWireKey = 'write_proof';

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

  /// Snapshot paging belongs to the begin half of the round trip.
  Future<Map<SyncCollection, String>> _hashAll(
    ReconciliationSnapshotHasher hasher,
    ReconciliationContext context,
  ) async {
    try {
      return await hasher.hashAll(context);
    } on ReconciliationSnapshotException catch (error) {
      throw SyncEnrollmentException(
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
      throw SyncEnrollmentException(
        step: 'reconcileComplete',
        code: error.code,
        message: error.message,
        retryAfter: error.retryAfter,
      );
    }
  }

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
