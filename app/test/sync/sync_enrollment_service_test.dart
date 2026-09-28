import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:domain/domain.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/persistence/device_identity.dart';
import 'package:spendwise/persistence/ledger_database.dart';
import 'package:spendwise/sync/credential_provider.dart';
import 'package:spendwise/sync/reconciliation_snapshot_hasher.dart';
import 'package:spendwise/sync/secret_store.dart';
import 'package:spendwise/sync/sync_e2e_key_provider.dart';
import 'package:spendwise/sync/sync_enrollment_service.dart';
import 'package:spendwise/sync/sync_metadata_store.dart';
import 'package:spendwise/sync/sync_repair_gate.dart';
import 'package:spendwise/sync/sync_secret_keys.dart';
import 'package:sync/sync.dart';

import 'in_memory_secret_store.dart';

String credentialPayload(String device, String bearer) => base64Url.encode(
  utf8.encode(
    jsonEncode({
      'deviceID': device,
      'bearerToken': base64Url.encode(utf8.encode(bearer)),
    }),
  ),
);

InMemorySyncBackend emptySnapshotBackend({
  PullHandler? onPull,
  ReconcileHandler? onReconcile,
}) => InMemorySyncBackend(
  onPull:
      onPull ??
      (credential, request) async => SyncSuccess(
        PullResponse(const <String, Object?>{
          'envelopes': <Object?>[],
          'cursor': 'cursor-0',
          'end_of_snapshot': true,
        }),
      ),
  onReconcile:
      onReconcile ??
      (credential, request) async {
        if (request is BeginReconcile) {
          return SyncSuccess(ReconcileResponse(beginContextWire()));
        }
        return SyncSuccess(ReconcileResponse(const {}));
      },
);

Map<String, Object?> beginContextWire() => <String, Object?>{
  'reconciliation': <String, Object?>{
    'reconciliation_id': 'recon-42',
    'snapshot_watermark': 'watermark-7',
    'expires_at': '2026-09-19T12:00:00.000Z',
  },
};

Uint8List validE2EKey() =>
    Uint8List.fromList(List<int>.generate(32, (index) => index));

String validDeviceSecret() => base64Url
    .encode(List<int>.generate(32, (index) => index + 1))
    .replaceAll('=', '');

String otherDeviceSecret() => base64Url
    .encode(List<int>.generate(32, (index) => 255 - index))
    .replaceAll('=', '');

SyncEnvelope entriesEnvelope(String row) => SyncEnvelope.create(
  protocolVersion: syncProtocolVersion,
  userID: 'user-1',
  collection: SyncCollection.entries,
  rowID: row,
  versionVector: VersionVector({'device-a': 1}),
  lifecycle: SiblingLifecycle.live,
  ciphertext: 'cipher-$row',
);

final class FakeSyncAuthenticator implements SyncAuthenticator {
  SyncOutcome<EnrollmentChallenge> Function()? onBegin;
  SyncOutcome<DeviceCredential> Function()? onComplete;
  int beginCalls = 0;
  int completeCalls = 0;

  @override
  Future<SyncOutcome<EnrollmentChallenge>> beginEnrollment(
    BeginEnrollmentRequest request,
  ) async {
    beginCalls++;
    return onBegin?.call() ?? SyncSuccess(EnrollmentChallenge(const {}));
  }

  @override
  Future<SyncOutcome<DeviceCredential>> completeEnrollment(
    CompleteEnrollmentRequest request,
  ) async {
    completeCalls++;
    final onComplete = this.onComplete;
    if (onComplete == null) throw StateError('no completion configured');
    return onComplete();
  }

  @override
  Future<SyncOutcome<DeviceCredential>> refreshCredential(
    DeviceCredential credential,
  ) async => throw UnimplementedError();
}

final class RecordingAuthorizer implements DeviceBindingAuthorizer {
  RecordingAuthorizer(this.inner);

  final InMemorySyncBackend inner;
  final starts = <StartDeviceBindingRequest>[];
  final verifies = <VerifyDeviceBindingRequest>[];
  Future<void> Function()? onStart;

  @override
  Future<SyncOutcome<StartDeviceBindingResponse>> startBinding(
    StartDeviceBindingRequest request,
  ) async {
    starts.add(request);
    await onStart?.call();
    return inner.startBinding(request);
  }

  @override
  Future<SyncOutcome<VerifyDeviceBindingResponse>> verifyBinding(
    VerifyDeviceBindingRequest request,
  ) async {
    verifies.add(request);
    return inner.verifyBinding(request);
  }
}

final class StubAuthorizer implements DeviceBindingAuthorizer {
  SyncOutcome<StartDeviceBindingResponse>? startOutcome;
  SyncOutcome<VerifyDeviceBindingResponse>? verifyOutcome;
  int startCalls = 0;
  int verifyCalls = 0;

  @override
  Future<SyncOutcome<StartDeviceBindingResponse>> startBinding(
    StartDeviceBindingRequest request,
  ) async {
    startCalls++;
    final outcome = startOutcome;
    if (outcome == null) throw StateError('no start outcome configured');
    return outcome;
  }

  @override
  Future<SyncOutcome<VerifyDeviceBindingResponse>> verifyBinding(
    VerifyDeviceBindingRequest request,
  ) async {
    verifyCalls++;
    final outcome = verifyOutcome;
    if (outcome == null) throw StateError('no verify outcome configured');
    return outcome;
  }
}

final class DelegatingBackend implements SyncBackend {
  DelegatingBackend(this.inner);

  final InMemorySyncBackend inner;
  FutureOr<SyncOutcome<ReconcileResponse>> Function(
    SyncCredential,
    ReconcileRequest,
  )?
  onAuthorizedBegin;
  FutureOr<SyncOutcome<ReconcileResponse>> Function(
    SyncCredential,
    ReconcileRequest,
  )?
  onBoundBegin;
  FutureOr<SyncOutcome<ReconcileResponse>> Function(
    SyncCredential,
    ReconcileRequest,
  )?
  onComplete;
  FutureOr<SyncOutcome<PullResponse>> Function(SyncCredential, PullRequest)?
  onPullOverride;
  final authorizedBegins = <ReconcileRequest>[];
  final boundBegins = <ReconcileRequest>[];
  final completes = <ReconcileRequest>[];
  final pulls = <PullRequest>[];
  final operationCredentials = <SyncCredential>[];

  @override
  Future<SyncOutcome<ReconcileResponse>> reconcile(
    SyncCredential credential,
    ReconcileRequest request,
  ) async {
    if (credential is DeviceCredential && request is BeginReconcile) {
      authorizedBegins.add(request);
      final hook = onAuthorizedBegin;
      if (hook != null) return hook(credential, request);
      return inner.reconcile(credential, request);
    }
    if (credential is BoundDeviceCredential && request is BeginReconcile) {
      boundBegins.add(request);
      operationCredentials.add(credential);
      final hook = onBoundBegin;
      if (hook != null) return hook(credential, request);
      return inner.reconcile(credential, request);
    }
    if (request is CompleteReconcile) {
      completes.add(request);
      operationCredentials.add(credential);
      final hook = onComplete;
      if (hook != null) return hook(credential, request);
      return inner.reconcile(credential, request);
    }
    return inner.reconcile(credential, request);
  }

  @override
  Future<SyncOutcome<PullResponse>> pull(
    SyncCredential credential,
    PullRequest request,
  ) async {
    pulls.add(request);
    operationCredentials.add(credential);
    final hook = onPullOverride;
    if (hook != null) return hook(credential, request);
    return inner.pull(credential, request);
  }

  @override
  Future<SyncOutcome<PushResponse>> push(
    SyncCredential credential,
    PushRequest request,
  ) => inner.push(credential, request);

  @override
  Future<SyncOutcome<AcknowledgeResponse>> acknowledge(
    SyncCredential credential,
    AcknowledgeRequest request,
  ) => inner.acknowledge(credential, request);
}

final class FailingWriteStore implements SecretStore {
  FailingWriteStore(this.inner, {this.failWritesFor = const {}});

  final InMemorySecretStore inner;
  final Set<String> failWritesFor;

  @override
  Future<String?> read(String key) => inner.read(key);

  @override
  Future<void> write(String key, String value) async {
    if (failWritesFor.contains(key)) {
      throw const SecretStoreException();
    }
    return inner.write(key, value);
  }

  @override
  Future<void> delete(String key) => inner.delete(key);
}

Future<String> seedBoundDevice({
  required LedgerDatabase database,
  required InMemorySecretStore store,
  required InMemorySyncBackend target,
  String bearer = 'bound-bearer',
  String? deviceSecret,
  bool withE2EKey = true,
}) async {
  final id = await deviceID(database);
  final secret = deviceSecret ?? validDeviceSecret();
  target.provisionBoundDevice(
    deviceID: id,
    bearerToken: bearer,
    deviceSecret: secret,
  );
  final credential = const CredentialCodec().restore(
    credentialPayload(id, bearer),
  );
  await store.write(
    syncCredentialSecretKey,
    const CredentialCodec().export(credential),
  );
  await store.write(syncDeviceSecretKey, secret);
  if (withE2EKey) {
    await store.write(syncE2EKeySecretKey, base64Url.encode(validE2EKey()));
  }
  return id;
}

void main() {
  late LedgerDatabase db;
  late InMemorySecretStore secrets;
  late SyncMetadataStore metadataStore;
  late FakeSyncAuthenticator authenticator;
  late InMemorySyncBackend backend;

  setUp(() {
    db = LedgerDatabase(NativeDatabase.memory());
    secrets = InMemorySecretStore();
    metadataStore = SyncMetadataStore(db);
    authenticator = FakeSyncAuthenticator();
    backend = emptySnapshotBackend();
  });

  tearDown(() => db.close());

  SyncEnrollmentService service({
    SyncBackend? backendOverride,
    DeviceBindingAuthorizer? bindingAuthorizer,
    SecretStore? secretStoreOverride,
    Future<Uint8List> Function()? resolveE2EKey,
    ReconciliationSnapshotHasher Function(SyncCredential)? buildSnapshotHasher,
    Future<String> Function(EnrollmentChallenge)? resolveBindingOtp,
  }) {
    final effectiveBackend = backendOverride ?? backend;
    return SyncEnrollmentService(
      authenticator: authenticator,
      backend: effectiveBackend,
      metadataStore: metadataStore,
      secretStore: secretStoreOverride ?? secrets,
      database: db,
      buildBeginRequest: () => BeginEnrollmentRequest(const {}),
      buildCompleteRequest: (challenge) async =>
          CompleteEnrollmentRequest(const {}),
      resolveE2EKey: resolveE2EKey ?? () async => validE2EKey(),
      buildSnapshotHasher:
          buildSnapshotHasher ??
          (credential) => ReconciliationSnapshotHasher(
            backend: effectiveBackend,
            credential: credential,
          ),
      bindingAuthorizer: bindingAuthorizer ?? backend,
      bindingIdentifier: 'user@example.com',
      resolveBindingOtp:
          resolveBindingOtp ?? (_) async => InMemorySyncBackend.bindingOtp,
    );
  }

  Future<void> configureHandshakeSuccess({
    String bearer = 'test-bearer',
  }) async {
    final id = await deviceID(db);
    final credential = const CredentialCodec().restore(
      credentialPayload(id, bearer),
    );
    authenticator.onComplete = () => SyncSuccess(credential);
  }

  Future<SyncEnrollmentException> enrollError(
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } on SyncEnrollmentException catch (error) {
      return error;
    }
    throw StateError('Expected enrollment to fail.');
  }

  test('fresh enrollment reaches gateEnabled with one binding round', () async {
    backend = emptySnapshotBackend(
      onReconcile: (credential, request) async {
        if (request is CompleteReconcile) {
          return SyncSuccess(ReconcileResponse({'write_proof': 'proof-123'}));
        }
        return SyncSuccess(ReconcileResponse(beginContextWire()));
      },
    );
    final recorder = RecordingAuthorizer(backend);
    var keyStoredAtStart = false;
    recorder.onStart = () async {
      keyStoredAtStart = await secrets.read(syncE2EKeySecretKey) != null;
    };
    var otpCalls = 0;

    await service(
      bindingAuthorizer: recorder,
      resolveBindingOtp: (challenge) async {
        otpCalls++;
        return InMemorySyncBackend.bindingOtp;
      },
    ).enroll();

    expect(keyStoredAtStart, isTrue);
    expect(otpCalls, 1);
    expect(recorder.starts, hasLength(1));
    expect(recorder.verifies, hasLength(1));
    expect(authenticator.beginCalls, 0);
    expect(authenticator.completeCalls, 0);
    expect(backend.calls.where((call) => call == 'reconcile'), hasLength(2));
    expect(
      backend.calls.where((call) => call == 'pull'),
      hasLength(SyncCollection.values.length),
    );
    expect(backend.calls, isNot(contains('acknowledge')));
    final storedKey = await secrets.read(syncE2EKeySecretKey);
    expect(decodeAndValidateSyncE2EKey(storedKey!), validE2EKey());
    expect(
      isValidSyncDeviceSecret((await secrets.read(syncDeviceSecretKey))!),
      isTrue,
    );
    expect(await secrets.read(syncWriteProofSecretKey), 'proof-123');
    final snapshot = await metadataStore.snapshot();
    expect(snapshot.phase, SyncEnrollmentPhase.gateEnabled);
    expect(snapshot.writeEnabled, isTrue);
    expect(snapshot.deviceBindingState, SyncDeviceBindingState.bound);
  });

  test(
    'start, verify, and the persisted bearer share one normalized device ID',
    () async {
      const seed = 'ABCDEF12-3456-7890-ABCD-EF1234567890';
      await db
          .into(db.storeMeta)
          .insert(StoreMetaRow(id: 0, deviceId: seed, hasSeeded: false));
      final recorder = RecordingAuthorizer(backend);

      await service(bindingAuthorizer: recorder).enroll();

      expect(recorder.starts, hasLength(1));
      expect(recorder.verifies, hasLength(1));
      expect(recorder.starts.single.deviceID, normalizedID(seed));
      expect(recorder.verifies.single.deviceID, normalizedID(seed));
      expect(
        recorder.starts.single.deviceID,
        recorder.verifies.single.deviceID,
      );
      final stored = await secrets.read(syncCredentialSecretKey);
      expect(
        const CredentialCodec().restore(stored!).deviceID,
        normalizedID(seed),
      );
    },
  );

  test('migrated credentialAcquired row does key work before Start', () async {
    await metadataStore.setEnrollmentPhase(
      SyncEnrollmentPhase.credentialAcquired,
    );
    await db.customStatement(
      'UPDATE sync_meta SET device_binding_state = 1 WHERE id = 0',
    );
    var resolveKeyCalls = 0;

    await service(
      resolveE2EKey: () async {
        resolveKeyCalls++;
        return validE2EKey();
      },
    ).enroll();

    expect(resolveKeyCalls, 1);
    expect(backend.calls.where((call) => call == 'startBinding'), hasLength(1));
    expect(
      backend.calls.where((call) => call == 'verifyBinding'),
      hasLength(1),
    );
    expect(
      decodeAndValidateSyncE2EKey((await secrets.read(syncE2EKeySecretKey))!),
      validE2EKey(),
    );
    final snapshot = await metadataStore.snapshot();
    expect(snapshot.phase, SyncEnrollmentPhase.gateEnabled);
    expect(snapshot.writeEnabled, isTrue);
  });

  test('bindingAuthorizationRequired row collects one binding OTP', () async {
    await metadataStore.enterBindingAuthorizationRequired();
    await secrets.write(syncE2EKeySecretKey, base64Url.encode(validE2EKey()));
    var resolveKeyCalls = 0;
    var otpCalls = 0;

    await service(
      resolveE2EKey: () async {
        resolveKeyCalls++;
        return validE2EKey();
      },
      resolveBindingOtp: (challenge) async {
        otpCalls++;
        return InMemorySyncBackend.bindingOtp;
      },
    ).enroll();

    expect(resolveKeyCalls, 0);
    expect(otpCalls, 1);
    expect(backend.calls.where((call) => call == 'startBinding'), hasLength(1));
    expect(
      backend.calls.where((call) => call == 'verifyBinding'),
      hasLength(1),
    );
    expect(
      (await metadataStore.snapshot()).phase,
      SyncEnrollmentPhase.gateEnabled,
    );
  });

  test('sessionReauthRequired performs bearer-only OTP and restores each resume phase', () async {
    for (final resume in [
      SyncEnrollmentPhase.snapshotInProgress,
      SyncEnrollmentPhase.reconciliationComplete,
      SyncEnrollmentPhase.gateEnabled,
    ]) {
      final localDb = LedgerDatabase(NativeDatabase.memory());
      addTearDown(() => localDb.close());
      final localSecrets = InMemorySecretStore();
      final localMeta = SyncMetadataStore(localDb);
      final localAuth = FakeSyncAuthenticator();
      final localBackend = emptySnapshotBackend();
      await localMeta.enterSnapshotInProgress();
      if (resume == SyncEnrollmentPhase.reconciliationComplete ||
          resume == SyncEnrollmentPhase.gateEnabled) {
        await localMeta.enterReconciliationComplete();
      }
      if (resume == SyncEnrollmentPhase.gateEnabled) {
        await localMeta.enterGateEnabled();
      }
      await localMeta.enterSessionReauthRequired();
      final id = await seedBoundDevice(
        database: localDb,
        store: localSecrets,
        target: localBackend,
        bearer: 'old-bearer-$resume',
      );
      localAuth.onComplete = () {
        localBackend.updateBearer(id, 'new-bearer-$resume');
        return SyncSuccess(
          const CredentialCodec().restore(
            credentialPayload(id, 'new-bearer-$resume'),
          ),
        );
      };
      final localService = SyncEnrollmentService(
        authenticator: localAuth,
        backend: localBackend,
        metadataStore: localMeta,
        secretStore: localSecrets,
        database: localDb,
        buildBeginRequest: () => BeginEnrollmentRequest(const {}),
        buildCompleteRequest: (challenge) async =>
            CompleteEnrollmentRequest(const {}),
        resolveE2EKey: () async => validE2EKey(),
        buildSnapshotHasher: (credential) => ReconciliationSnapshotHasher(
          backend: localBackend,
          credential: credential,
        ),
        bindingAuthorizer: localBackend,
        bindingIdentifier: 'user@example.com',
        resolveBindingOtp: (_) async => InMemorySyncBackend.bindingOtp,
      );

      await localService.enroll();

      expect(localAuth.beginCalls, 1, reason: '$resume');
      expect(localAuth.completeCalls, 1, reason: '$resume');
      expect(
        localBackend.calls.where((call) => call == 'startBinding'),
        isEmpty,
        reason: '$resume',
      );
      expect(
        localBackend.calls.where((call) => call == 'verifyBinding'),
        isEmpty,
        reason: '$resume',
      );
      final storedBearer = const CredentialCodec().restore(
        (await localSecrets.read(syncCredentialSecretKey))!,
      );
      expect(storedBearer.deviceID, id, reason: '$resume');
      final finalSnapshot = await localMeta.snapshot();
      expect(
        finalSnapshot.phase,
        SyncEnrollmentPhase.gateEnabled,
        reason: '$resume',
      );
      expect(finalSnapshot.writeEnabled, isTrue, reason: '$resume');
    }
  });

  test(
    'lost authorized-Begin response retries with a fresh challenge',
    () async {
      await metadataStore.enterBindingAuthorizationRequired();
      await secrets.write(syncE2EKeySecretKey, base64Url.encode(validE2EKey()));
      final wrapper = DelegatingBackend(backend);
      var authorizedAttempts = 0;
      wrapper.onAuthorizedBegin = (credential, request) async {
        authorizedAttempts++;
        if (authorizedAttempts == 1) {
          await wrapper.inner.reconcile(credential, request);
          return const DeviceAuthorizationRequired<ReconcileResponse>(
            message: 'response lost',
          );
        }
        return wrapper.inner.reconcile(credential, request);
      };

      final firstError = await enrollError(
        () => service(backendOverride: wrapper).enroll(),
      );

      expect(firstError.step, 'reconcileBegin');
      expect(firstError.code, 'device_authorization_required');
      expect(
        (await metadataStore.snapshot()).phase,
        SyncEnrollmentPhase.bindingAuthorizationRequired,
      );

      await service(backendOverride: wrapper).enroll();

      expect(authorizedAttempts, 2);
      expect(wrapper.authorizedBegins, hasLength(2));
      expect(
        backend.calls.where((call) => call == 'startBinding'),
        hasLength(2),
      );
      expect(
        backend.calls.where((call) => call == 'verifyBinding'),
        hasLength(2),
      );
      expect(
        (await metadataStore.snapshot()).phase,
        SyncEnrollmentPhase.gateEnabled,
      );
    },
  );

  test('authorized-Begin CredentialExpired stays in binding repair', () async {
    await metadataStore.enterBindingAuthorizationRequired();
    await secrets.write(syncE2EKeySecretKey, base64Url.encode(validE2EKey()));
    final wrapper = DelegatingBackend(backend);
    wrapper.onAuthorizedBegin = (credential, request) =>
        const CredentialExpired<ReconcileResponse>(message: 'expired');

    final error = await enrollError(
      () => service(backendOverride: wrapper).enroll(),
    );

    expect(error.step, 'reconcileBegin');
    expect(error.code, 'credential_expired');
    final snapshot = await metadataStore.snapshot();
    expect(snapshot.phase, SyncEnrollmentPhase.bindingAuthorizationRequired);
    expect(snapshot.writeEnabled, isFalse);
    expect(wrapper.pulls, isEmpty);

    await service(backendOverride: wrapper..onAuthorizedBegin = null).enroll();

    expect(
      (await metadataStore.snapshot()).phase,
      SyncEnrollmentPhase.gateEnabled,
    );
  });

  test(
    'authorized-Begin DeviceAuthorizationRequired stays in binding repair',
    () async {
      await metadataStore.enterBindingAuthorizationRequired();
      await secrets.write(syncE2EKeySecretKey, base64Url.encode(validE2EKey()));
      final wrapper = DelegatingBackend(backend);
      wrapper.onAuthorizedBegin = (credential, request) =>
          const DeviceAuthorizationRequired<ReconcileResponse>(
            message: 'denied',
          );

      final error = await enrollError(
        () => service(backendOverride: wrapper).enroll(),
      );

      expect(error.step, 'reconcileBegin');
      expect(error.code, 'device_authorization_required');
      final snapshot = await metadataStore.snapshot();
      expect(snapshot.phase, SyncEnrollmentPhase.bindingAuthorizationRequired);
      expect(snapshot.writeEnabled, isFalse);
      expect(wrapper.pulls, isEmpty);
    },
  );

  test('startBinding failure keeps bindingAuthorizationRequired', () async {
    await metadataStore.enterBindingAuthorizationRequired();
    await secrets.write(syncE2EKeySecretKey, base64Url.encode(validE2EKey()));
    final stub = StubAuthorizer()
      ..startOutcome = const NetworkUnavailable<StartDeviceBindingResponse>(
        message: 'offline',
      );

    final error = await enrollError(
      () => service(bindingAuthorizer: stub).enroll(),
    );

    expect(error.step, 'startBinding');
    expect(error.code, 'network_unavailable');
    expect(error.message, 'offline');
    expect(stub.startCalls, 1);
    expect(stub.verifyCalls, 0);
    expect(await secrets.read(syncCredentialSecretKey), isNull);
    final snapshot = await metadataStore.snapshot();
    expect(snapshot.phase, SyncEnrollmentPhase.bindingAuthorizationRequired);
    expect(snapshot.writeEnabled, isFalse);
  });

  test('verifyBinding failure keeps bindingAuthorizationRequired', () async {
    await metadataStore.enterBindingAuthorizationRequired();
    await secrets.write(syncE2EKeySecretKey, base64Url.encode(validE2EKey()));
    final stub = StubAuthorizer()
      ..startOutcome = SyncSuccess(
        StartDeviceBindingResponse(
          challengeID: 'challenge-1',
          expiresAt: DateTime.utc(2026, 9, 28, 12),
        ),
      )
      ..verifyOutcome =
          const DeviceAuthorizationRequired<VerifyDeviceBindingResponse>(
            message: 'wrong OTP',
          );

    final error = await enrollError(
      () => service(bindingAuthorizer: stub).enroll(),
    );

    expect(error.step, 'verifyBinding');
    expect(error.code, 'device_authorization_required');
    expect(stub.startCalls, 1);
    expect(stub.verifyCalls, 1);
    expect(await secrets.read(syncCredentialSecretKey), isNull);
    expect(backend.calls, isEmpty);
    final snapshot = await metadataStore.snapshot();
    expect(snapshot.phase, SyncEnrollmentPhase.bindingAuthorizationRequired);
    expect(snapshot.writeEnabled, isFalse);
  });

  test(
    'absent E2E key in bindingAuthorizationRequired never regenerates',
    () async {
      await metadataStore.enterBindingAuthorizationRequired();
      var resolveKeyCalls = 0;

      Object? thrown;
      try {
        await service(
          resolveE2EKey: () async {
            resolveKeyCalls++;
            return validE2EKey();
          },
        ).enroll();
      } catch (error) {
        thrown = error;
      }

      expect(
        thrown,
        isA<SyncE2EKeyUnavailableException>().having(
          (error) => error.reason,
          'reason',
          SyncE2EKeyUnavailableReason.absent,
        ),
      );
      expect(resolveKeyCalls, 0);
      expect(backend.calls, isEmpty);
      final snapshot = await metadataStore.snapshot();
      expect(snapshot.phase, SyncEnrollmentPhase.bindingAuthorizationRequired);
      expect(snapshot.writeEnabled, isFalse);
    },
  );

  test('malformed E2E key in bindingAuthorizationRequired makes zero binding calls', () async {
    await metadataStore.enterBindingAuthorizationRequired();
    await secrets.write(syncE2EKeySecretKey, '!!!-not-base64url-!!!');
    var resolveKeyCalls = 0;

    Object? thrown;
    try {
      await service(
        resolveE2EKey: () async {
          resolveKeyCalls++;
          return validE2EKey();
        },
      ).enroll();
    } catch (error) {
      thrown = error;
    }

    expect(
      thrown,
      isA<SyncE2EKeyUnavailableException>().having(
        (error) => error.reason,
        'reason',
        SyncE2EKeyUnavailableReason.malformed,
      ),
    );
    expect(resolveKeyCalls, 0);
    expect(backend.calls, isEmpty);
    final snapshot = await metadataStore.snapshot();
    expect(snapshot.phase, SyncEnrollmentPhase.bindingAuthorizationRequired);
  });

  test('wrong-length E2E key in bindingAuthorizationRequired makes zero binding calls', () async {
    await metadataStore.enterBindingAuthorizationRequired();
    await secrets.write(
      syncE2EKeySecretKey,
      base64Url.encode(List<int>.filled(16, 7)),
    );
    var resolveKeyCalls = 0;

    Object? thrown;
    try {
      await service(
        resolveE2EKey: () async {
          resolveKeyCalls++;
          return validE2EKey();
        },
      ).enroll();
    } catch (error) {
      thrown = error;
    }

    expect(
      thrown,
      isA<SyncE2EKeyUnavailableException>().having(
        (error) => error.reason,
        'reason',
        SyncE2EKeyUnavailableReason.wrongLength,
      ),
    );
    expect(resolveKeyCalls, 0);
    expect(backend.calls, isEmpty);
    final snapshot = await metadataStore.snapshot();
    expect(snapshot.phase, SyncEnrollmentPhase.bindingAuthorizationRequired);
  });

  test('E2E storage failure in bindingAuthorizationRequired surfaces storageFailed', () async {
    await metadataStore.enterBindingAuthorizationRequired();
    await secrets.write(syncE2EKeySecretKey, base64Url.encode(validE2EKey()));
    secrets.readFailure = const SecretStoreException();
    secrets.readFailureKey = syncE2EKeySecretKey;
    var resolveKeyCalls = 0;

    Object? thrown;
    try {
      await service(
        resolveE2EKey: () async {
          resolveKeyCalls++;
          return validE2EKey();
        },
      ).enroll();
    } catch (error) {
      thrown = error;
    } finally {
      secrets.readFailure = null;
      secrets.readFailureKey = null;
    }

    expect(
      thrown,
      isA<SyncE2EKeyUnavailableException>().having(
        (error) => error.reason,
        'reason',
        SyncE2EKeyUnavailableReason.storageFailed,
      ),
    );
    expect(resolveKeyCalls, 0);
    expect(backend.calls, isEmpty);
    final snapshot = await metadataStore.snapshot();
    expect(snapshot.phase, SyncEnrollmentPhase.bindingAuthorizationRequired);
  });

  test('valid stored secret recovers the crash window without OTP', () async {
    await metadataStore.enterBindingAuthorizationRequired();
    await secrets.write(syncE2EKeySecretKey, base64Url.encode(validE2EKey()));
    await seedBoundDevice(database: db, store: secrets, target: backend);

    await service().enroll();

    expect(backend.calls.where((call) => call == 'startBinding'), isEmpty);
    expect(backend.calls.where((call) => call == 'verifyBinding'), isEmpty);
    expect(backend.calls.where((call) => call == 'reconcile'), hasLength(2));
    final snapshot = await metadataStore.snapshot();
    expect(snapshot.phase, SyncEnrollmentPhase.gateEnabled);
    expect(snapshot.writeEnabled, isTrue);
  });

  test(
    'server-rejected secret is deleted and the next attempt collects OTP',
    () async {
      await metadataStore.enterBindingAuthorizationRequired();
      await secrets.write(syncE2EKeySecretKey, base64Url.encode(validE2EKey()));
      final id = await deviceID(db);
      backend.provisionBoundDevice(
        deviceID: id,
        bearerToken: 'server-bearer',
        deviceSecret: validDeviceSecret(),
      );
      final credential = const CredentialCodec().restore(
        credentialPayload(id, 'server-bearer'),
      );
      await secrets.write(
        syncCredentialSecretKey,
        const CredentialCodec().export(credential),
      );
      await secrets.write(syncDeviceSecretKey, otherDeviceSecret());

      final error = await enrollError(service().enroll);

      expect(error.step, 'reconcileBegin');
      expect(error.code, 'device_authorization_required');
      expect(await secrets.read(syncDeviceSecretKey), isNull);
      expect(backend.calls.where((call) => call == 'pull'), isEmpty);
      var snapshot = await metadataStore.snapshot();
      expect(snapshot.phase, SyncEnrollmentPhase.bindingAuthorizationRequired);

      await service().enroll();

      expect(
        backend.calls.where((call) => call == 'startBinding'),
        hasLength(1),
      );
      expect(
        backend.calls.where((call) => call == 'verifyBinding'),
        hasLength(1),
      );
      snapshot = await metadataStore.snapshot();
      expect(snapshot.phase, SyncEnrollmentPhase.gateEnabled);
    },
  );

  test('malformed stored secret is deleted before binding OTP', () async {
    await metadataStore.enterBindingAuthorizationRequired();
    await secrets.write(syncE2EKeySecretKey, base64Url.encode(validE2EKey()));
    await secrets.write(syncDeviceSecretKey, '!!!-not-a-secret-!!!');

    await service().enroll();

    expect(backend.calls.where((call) => call == 'startBinding'), hasLength(1));
    expect(
      backend.calls.where((call) => call == 'verifyBinding'),
      hasLength(1),
    );
    expect(
      isValidSyncDeviceSecret((await secrets.read(syncDeviceSecretKey))!),
      isTrue,
    );
    expect(
      (await metadataStore.snapshot()).phase,
      SyncEnrollmentPhase.gateEnabled,
    );
  });

  test(
    'stale secret is deleted even when entering binding authorization fails',
    () async {
      await secrets.write(syncDeviceSecretKey, validDeviceSecret());
      await db.customStatement(
        'CREATE TRIGGER fail_binding_enter BEFORE UPDATE ON sync_meta '
        'WHEN NEW.device_binding_state = 1 '
        'BEGIN SELECT RAISE(ABORT, \'boom\'); END',
      );

      Object? thrown;
      try {
        await service().enroll();
      } catch (error) {
        thrown = error;
      }

      expect(thrown, isNotNull);
      expect(await secrets.read(syncDeviceSecretKey), isNull);
      expect(
        (await metadataStore.snapshot()).phase,
        SyncEnrollmentPhase.notEnrolled,
      );

      await db.customStatement('DROP TRIGGER fail_binding_enter');

      await service().enroll();

      expect(
        backend.calls.where((call) => call == 'startBinding'),
        hasLength(1),
      );
      expect(
        (await metadataStore.snapshot()).phase,
        SyncEnrollmentPhase.gateEnabled,
      );
    },
  );

  test(
    'session reauth with an absent secret enters binding repair first',
    () async {
      await metadataStore.enterSnapshotInProgress();
      await metadataStore.enterSessionReauthRequired();
      await secrets.write(syncE2EKeySecretKey, base64Url.encode(validE2EKey()));
      await configureHandshakeSuccess();

      await service().enroll();

      expect(authenticator.beginCalls, 0);
      expect(authenticator.completeCalls, 0);
      expect(
        backend.calls.where((call) => call == 'startBinding'),
        hasLength(1),
      );
      expect(
        backend.calls.where((call) => call == 'verifyBinding'),
        hasLength(1),
      );
      expect(
        (await metadataStore.snapshot()).phase,
        SyncEnrollmentPhase.gateEnabled,
      );
    },
  );

  test(
    'session reauth with a malformed secret deletes it before binding repair',
    () async {
      await metadataStore.enterSnapshotInProgress();
      await metadataStore.enterSessionReauthRequired();
      await secrets.write(syncE2EKeySecretKey, base64Url.encode(validE2EKey()));
      await secrets.write(syncDeviceSecretKey, '!!!-not-a-secret-!!!');
      await configureHandshakeSuccess();

      await service().enroll();

      expect(authenticator.beginCalls, 0);
      expect(
        isValidSyncDeviceSecret((await secrets.read(syncDeviceSecretKey))!),
        isTrue,
      );
      expect(
        (await metadataStore.snapshot()).phase,
        SyncEnrollmentPhase.gateEnabled,
      );
    },
  );

  test('session reauth storage failure stops without a transition', () async {
    await metadataStore.enterSnapshotInProgress();
    await metadataStore.enterSessionReauthRequired();
    await secrets.write(syncE2EKeySecretKey, base64Url.encode(validE2EKey()));
    await secrets.write(syncDeviceSecretKey, validDeviceSecret());
    secrets.readFailure = const SecretStoreException();
    secrets.readFailureKey = syncDeviceSecretKey;

    Object? thrown;
    try {
      await service().enroll();
    } catch (error) {
      thrown = error;
    } finally {
      secrets.readFailure = null;
      secrets.readFailureKey = null;
    }

    expect(thrown, isA<SecretStoreException>());
    final snapshot = await metadataStore.snapshot();
    expect(snapshot.phase, SyncEnrollmentPhase.sessionReauthRequired);
    expect(snapshot.reauthResumePhase, SyncEnrollmentPhase.snapshotInProgress);
  });

  test('session reauth rejects a credential for another device', () async {
    await metadataStore.enterSnapshotInProgress();
    await metadataStore.enterSessionReauthRequired();
    await secrets.write(syncE2EKeySecretKey, base64Url.encode(validE2EKey()));
    await secrets.write(syncDeviceSecretKey, validDeviceSecret());
    const otherBearer = 'other-bearer';
    await secrets.write(
      syncCredentialSecretKey,
      credentialPayload('another-device', otherBearer),
    );
    authenticator.onComplete = () => SyncSuccess(
      const CredentialCodec().restore(
        credentialPayload('another-device', otherBearer),
      ),
    );

    Object? thrown;
    try {
      await service().enroll();
    } catch (error) {
      thrown = error;
    }

    expect(
      thrown,
      isA<CredentialUnavailableException>().having(
        (error) => error.reason,
        'reason',
        CredentialUnavailableReason.identityFailed,
      ),
    );
    expect(
      await secrets.read(syncCredentialSecretKey),
      credentialPayload('another-device', otherBearer),
    );
    final snapshot = await metadataStore.snapshot();
    expect(snapshot.phase, SyncEnrollmentPhase.sessionReauthRequired);
    expect(snapshot.reauthResumePhase, SyncEnrollmentPhase.snapshotInProgress);
  });

  test('session reauth begin failure preserves the resume phase', () async {
    await metadataStore.enterSnapshotInProgress();
    await metadataStore.enterSessionReauthRequired();
    await secrets.write(syncE2EKeySecretKey, base64Url.encode(validE2EKey()));
    await secrets.write(syncDeviceSecretKey, validDeviceSecret());
    authenticator.onBegin = () =>
        const NetworkUnavailable<EnrollmentChallenge>(message: 'offline');

    final error = await enrollError(service().enroll);

    expect(error.step, 'beginEnrollment');
    expect(error.code, 'network_unavailable');
    expect(authenticator.completeCalls, 0);
    final snapshot = await metadataStore.snapshot();
    expect(snapshot.phase, SyncEnrollmentPhase.sessionReauthRequired);
    expect(snapshot.reauthResumePhase, SyncEnrollmentPhase.snapshotInProgress);
    expect(snapshot.writeEnabled, isFalse);
  });

  test('failed device-secret write sends no Pull or Complete', () async {
    await metadataStore.enterBindingAuthorizationRequired();
    await secrets.write(syncE2EKeySecretKey, base64Url.encode(validE2EKey()));
    final failingSecrets = FailingWriteStore(
      secrets,
      failWritesFor: {syncDeviceSecretKey},
    );

    Object? thrown;
    try {
      await service(secretStoreOverride: failingSecrets).enroll();
    } catch (error) {
      thrown = error;
    }

    expect(thrown, isA<SecretStoreException>());
    expect(backend.calls.where((call) => call == 'pull'), isEmpty);
    expect(backend.calls.where((call) => call == 'reconcile'), hasLength(1));
    expect(await secrets.read(syncCredentialSecretKey), isNotNull);
    expect(await secrets.read(syncDeviceSecretKey), isNull);
    final snapshot = await metadataStore.snapshot();
    expect(snapshot.phase, SyncEnrollmentPhase.bindingAuthorizationRequired);
    expect(snapshot.writeEnabled, isFalse);
  });

  test('metadata transition failure after a stored device secret sends no Pull or Complete', () async {
    await metadataStore.enterBindingAuthorizationRequired();
    await secrets.write(syncE2EKeySecretKey, base64Url.encode(validE2EKey()));
    await db.customStatement(
      'CREATE TRIGGER fail_snapshot_enter BEFORE UPDATE ON sync_meta '
      'WHEN NEW.device_binding_state = 2 AND NEW.enrollment_phase = 2 '
      'BEGIN SELECT RAISE(ABORT, \'boom\'); END',
    );

    Object? thrown;
    try {
      await service().enroll();
    } catch (error) {
      thrown = error;
    }

    expect(thrown, isNotNull);
    expect(await secrets.read(syncDeviceSecretKey), isNotNull);
    expect(backend.calls.where((call) => call == 'pull'), isEmpty);
    expect(backend.calls.where((call) => call == 'reconcile'), hasLength(1));
    var snapshot = await metadataStore.snapshot();
    expect(snapshot.phase, SyncEnrollmentPhase.bindingAuthorizationRequired);
    expect(snapshot.writeEnabled, isFalse);

    await db.customStatement('DROP TRIGGER fail_snapshot_enter');

    await service().enroll();

    expect(backend.calls.where((call) => call == 'startBinding'), hasLength(1));
    expect(
      backend.calls.where((call) => call == 'verifyBinding'),
      hasLength(1),
    );
    snapshot = await metadataStore.snapshot();
    expect(snapshot.phase, SyncEnrollmentPhase.gateEnabled);
  });

  test(
    'snapshotInProgress precedes the first Pull on one bound credential',
    () async {
      await metadataStore.enterBindingAuthorizationRequired();
      await secrets.write(syncE2EKeySecretKey, base64Url.encode(validE2EKey()));
      final wrapper = DelegatingBackend(backend);
      final phasesAtPull = <SyncEnrollmentPhase>[];
      wrapper.onPullOverride = (credential, request) async {
        phasesAtPull.add((await metadataStore.snapshot()).phase);
        return wrapper.inner.pull(credential, request);
      };

      await service(backendOverride: wrapper).enroll();

      expect(phasesAtPull, hasLength(SyncCollection.values.length));
      expect(phasesAtPull.toSet(), {SyncEnrollmentPhase.snapshotInProgress});
      expect(wrapper.operationCredentials, isNotEmpty);
      expect(wrapper.operationCredentials.toSet(), hasLength(1));
      expect(wrapper.operationCredentials.first, isA<BoundDeviceCredential>());
      expect(
        (await metadataStore.snapshot()).phase,
        SyncEnrollmentPhase.gateEnabled,
      );
    },
  );

  test(
    'authorized-Begin secrets that fail validation are incompatible',
    () async {
      final valid = validDeviceSecret();
      final variants = <String, Map<String, Object?>?>{
        'missing': null,
        'padded': {'device_secret': '$valid='},
        'noncanonical': {
          'device_secret':
              valid.substring(0, valid.length - 1) +
              (valid.endsWith('A') ? 'B' : 'A'),
        },
        'malformed': {'device_secret': '!!!-not-a-secret-!!!'},
        'wrong-length': {
          'device_secret': base64Url.encode(List<int>.filled(16, 7)),
        },
      };
      for (final entry in variants.entries) {
        final localDb = LedgerDatabase(NativeDatabase.memory());
        addTearDown(() => localDb.close());
        final localSecrets = InMemorySecretStore();
        final localMeta = SyncMetadataStore(localDb);
        final localBackend = emptySnapshotBackend();
        final localAuth = FakeSyncAuthenticator();
        await localMeta.enterBindingAuthorizationRequired();
        await localSecrets.write(
          syncE2EKeySecretKey,
          base64Url.encode(validE2EKey()),
        );
        if (entry.value case final secretEntry?) {
          expect(
            isValidSyncDeviceSecret(secretEntry['device_secret']! as String),
            isFalse,
            reason: entry.key,
          );
        }
        final wrapper = DelegatingBackend(localBackend);
        final secretOverride = entry.value;
        wrapper.onAuthorizedBegin = (credential, request) => SyncSuccess(
          ReconcileResponse(<String, Object?>{
            ...beginContextWire(),
            ...?secretOverride,
          }),
        );
        final localService = SyncEnrollmentService(
          authenticator: localAuth,
          backend: wrapper,
          metadataStore: localMeta,
          secretStore: localSecrets,
          database: localDb,
          buildBeginRequest: () => BeginEnrollmentRequest(const {}),
          buildCompleteRequest: (challenge) async =>
              CompleteEnrollmentRequest(const {}),
          resolveE2EKey: () async => validE2EKey(),
          buildSnapshotHasher: (credential) => ReconciliationSnapshotHasher(
            backend: wrapper,
            credential: credential,
          ),
          bindingAuthorizer: localBackend,
          bindingIdentifier: 'user@example.com',
          resolveBindingOtp: (_) async => InMemorySyncBackend.bindingOtp,
        );

        Object? thrown;
        try {
          await localService.enroll();
        } on SyncEnrollmentException catch (error) {
          thrown = error;
        }

        expect(
          thrown,
          isA<SyncEnrollmentException>()
              .having((e) => e.step, 'step', 'reconcileBegin')
              .having((e) => e.code, 'code', 'incompatible_server'),
          reason: entry.key,
        );
        expect(
          await localSecrets.read(syncDeviceSecretKey),
          isNull,
          reason: entry.key,
        );
        expect(wrapper.pulls, isEmpty, reason: entry.key);
        final snapshot = await localMeta.snapshot();
        expect(
          snapshot.phase,
          SyncEnrollmentPhase.bindingAuthorizationRequired,
          reason: entry.key,
        );
        expect(snapshot.writeEnabled, isFalse, reason: entry.key);
      }
    },
  );

  test('bound Begin carrying device_secret is incompatible', () async {
    const secretKeys = [
      syncCredentialSecretKey,
      syncDeviceSecretKey,
      syncE2EKeySecretKey,
      syncWriteProofSecretKey,
    ];
    Future<Map<String, String?>> readAllSecrets(
      InMemorySecretStore store,
    ) async {
      final values = <String, String?>{};
      for (final key in secretKeys) {
        values[key] = await store.read(key);
      }
      return values;
    }

    for (final secretValue in [validDeviceSecret(), null]) {
      final localDb = LedgerDatabase(NativeDatabase.memory());
      addTearDown(() => localDb.close());
      final localSecrets = InMemorySecretStore();
      final localMeta = SyncMetadataStore(localDb);
      final localBackend = emptySnapshotBackend();
      final localAuth = FakeSyncAuthenticator();
      await seedBoundDevice(
        database: localDb,
        store: localSecrets,
        target: localBackend,
      );
      await localMeta.enterSnapshotInProgress();
      final wrapper = DelegatingBackend(localBackend);
      wrapper.onBoundBegin = (credential, request) => SyncSuccess(
        ReconcileResponse(<String, Object?>{
          ...beginContextWire(),
          'device_secret': secretValue,
        }),
      );
      final localService = SyncEnrollmentService(
        authenticator: localAuth,
        backend: wrapper,
        metadataStore: localMeta,
        secretStore: localSecrets,
        database: localDb,
        buildBeginRequest: () => BeginEnrollmentRequest(const {}),
        buildCompleteRequest: (challenge) async =>
            CompleteEnrollmentRequest(const {}),
        resolveE2EKey: () async => validE2EKey(),
        buildSnapshotHasher: (credential) => ReconciliationSnapshotHasher(
          backend: wrapper,
          credential: credential,
        ),
        bindingAuthorizer: localBackend,
        bindingIdentifier: 'user@example.com',
        resolveBindingOtp: (_) async => InMemorySyncBackend.bindingOtp,
      );

      Object? thrown;
      final secretsBefore = await readAllSecrets(localSecrets);
      final writesBefore = List.of(localSecrets.writes);
      final deletesBefore = List.of(localSecrets.deletes);
      try {
        await localService.enroll();
      } on SyncEnrollmentException catch (error) {
        thrown = error;
      }

      expect(
        thrown,
        isA<SyncEnrollmentException>()
            .having((e) => e.step, 'step', 'reconcileBegin')
            .having((e) => e.code, 'code', 'incompatible_server'),
        reason: 'device_secret=$secretValue',
      );
      expect(wrapper.pulls, isEmpty, reason: 'device_secret=$secretValue');
      expect(
        await readAllSecrets(localSecrets),
        secretsBefore,
        reason: 'device_secret=$secretValue',
      );
      expect(
        localSecrets.writes,
        writesBefore,
        reason: 'device_secret=$secretValue',
      );
      expect(
        localSecrets.deletes,
        deletesBefore,
        reason: 'device_secret=$secretValue',
      );
      expect(
        localSecrets.writes.sublist(writesBefore.length),
        isNot(contains(syncDeviceSecretKey)),
        reason: 'device_secret=$secretValue',
      );
      expect(
        localSecrets.writes,
        isNot(contains(syncWriteProofSecretKey)),
        reason: 'device_secret=$secretValue',
      );
      final snapshot = await localMeta.snapshot();
      expect(
        snapshot.phase,
        SyncEnrollmentPhase.snapshotInProgress,
        reason: 'device_secret=$secretValue',
      );
    }
  });

  test('bound Begin CredentialExpired records session reauth', () async {
    await seedBoundDevice(database: db, store: secrets, target: backend);
    await metadataStore.enterSnapshotInProgress();
    final wrapper = DelegatingBackend(backend);
    wrapper.onBoundBegin = (credential, request) =>
        const CredentialExpired<ReconcileResponse>(message: 'expired');

    final error = await enrollError(
      () => service(backendOverride: wrapper).enroll(),
    );

    expect(error.step, 'reconcileBegin');
    expect(error.code, 'credential_expired');
    expect(wrapper.pulls, isEmpty);
    final snapshot = await metadataStore.snapshot();
    expect(snapshot.phase, SyncEnrollmentPhase.sessionReauthRequired);
    expect(snapshot.reauthResumePhase, SyncEnrollmentPhase.snapshotInProgress);
    expect(snapshot.writeEnabled, isFalse);
  });

  test('bound Pull CredentialExpired during binding repair surfaces device_authorization_required', () async {
    await seedBoundDevice(database: db, store: secrets, target: backend);
    await metadataStore.enterSnapshotInProgress();
    final wrapper = DelegatingBackend(backend);
    wrapper.onPullOverride = (credential, request) async {
      await metadataStore.enterBindingAuthorizationRequired();
      return const CredentialExpired<PullResponse>(message: 'expired');
    };

    final error = await enrollError(
      () => service(backendOverride: wrapper).enroll(),
    );

    expect(error.step, 'reconcileBegin');
    expect(error.code, 'device_authorization_required');
    expect(error.message, 'expired');
    final snapshot = await metadataStore.snapshot();
    expect(snapshot.phase, SyncEnrollmentPhase.bindingAuthorizationRequired);
    expect(
      snapshot.deviceBindingState,
      SyncDeviceBindingState.authorizationRequired,
    );
    expect(snapshot.writeEnabled, isFalse);
  });

  test('bound Complete CredentialExpired on a non-repair illegal row surfaces invalid_request', () async {
    await seedBoundDevice(database: db, store: secrets, target: backend);
    await metadataStore.enterSnapshotInProgress();
    final wrapper = DelegatingBackend(backend);
    wrapper.onComplete = (credential, request) async {
      await metadataStore.setEnrollmentPhase(SyncEnrollmentPhase.notEnrolled);
      return const CredentialExpired<ReconcileResponse>(message: 'expired');
    };

    final error = await enrollError(
      () => service(backendOverride: wrapper).enroll(),
    );

    expect(error.step, 'reconcileComplete');
    expect(error.code, 'invalid_request');
    expect(error.message, 'expired');
    final snapshot = await metadataStore.snapshot();
    expect(snapshot.phase, SyncEnrollmentPhase.notEnrolled);
    expect(snapshot.deviceBindingState, SyncDeviceBindingState.bound);
  });

  test('bound Begin DeviceAuthorizationRequired deletes the secret', () async {
    await seedBoundDevice(database: db, store: secrets, target: backend);
    await metadataStore.enterSnapshotInProgress();
    final wrapper = DelegatingBackend(backend);
    wrapper.onBoundBegin = (credential, request) =>
        const DeviceAuthorizationRequired<ReconcileResponse>(message: 'denied');

    final error = await enrollError(
      () => service(backendOverride: wrapper).enroll(),
    );

    expect(error.step, 'reconcileBegin');
    expect(error.code, 'device_authorization_required');
    expect(await secrets.read(syncDeviceSecretKey), isNull);
    expect(wrapper.pulls, isEmpty);
    final snapshot = await metadataStore.snapshot();
    expect(snapshot.phase, SyncEnrollmentPhase.bindingAuthorizationRequired);
  });

  test('Pull CredentialExpired records session reauth', () async {
    await seedBoundDevice(database: db, store: secrets, target: backend);
    await metadataStore.enterSnapshotInProgress();
    final wrapper = DelegatingBackend(backend);
    wrapper.onPullOverride = (credential, request) =>
        const CredentialExpired<PullResponse>(message: 'expired');

    final error = await enrollError(
      () => service(backendOverride: wrapper).enroll(),
    );

    expect(error.step, 'reconcileBegin');
    expect(error.code, 'credential_expired');
    final snapshot = await metadataStore.snapshot();
    expect(snapshot.phase, SyncEnrollmentPhase.sessionReauthRequired);
    expect(snapshot.reauthResumePhase, SyncEnrollmentPhase.snapshotInProgress);
  });

  test('Pull DeviceAuthorizationRequired deletes the secret', () async {
    await seedBoundDevice(database: db, store: secrets, target: backend);
    await metadataStore.enterSnapshotInProgress();
    final wrapper = DelegatingBackend(backend);
    wrapper.onPullOverride = (credential, request) =>
        const DeviceAuthorizationRequired<PullResponse>(message: 'denied');

    final error = await enrollError(
      () => service(backendOverride: wrapper).enroll(),
    );

    expect(error.step, 'reconcileBegin');
    expect(error.code, 'device_authorization_required');
    expect(await secrets.read(syncDeviceSecretKey), isNull);
    final snapshot = await metadataStore.snapshot();
    expect(snapshot.phase, SyncEnrollmentPhase.bindingAuthorizationRequired);
  });

  test('Complete CredentialExpired records session reauth', () async {
    await seedBoundDevice(database: db, store: secrets, target: backend);
    await metadataStore.enterSnapshotInProgress();
    final wrapper = DelegatingBackend(backend);
    wrapper.onComplete = (credential, request) =>
        const CredentialExpired<ReconcileResponse>(message: 'expired');

    final error = await enrollError(
      () => service(backendOverride: wrapper).enroll(),
    );

    expect(error.step, 'reconcileComplete');
    expect(error.code, 'credential_expired');
    final snapshot = await metadataStore.snapshot();
    expect(snapshot.phase, SyncEnrollmentPhase.sessionReauthRequired);
    expect(snapshot.reauthResumePhase, SyncEnrollmentPhase.snapshotInProgress);
  });

  test('Complete DeviceAuthorizationRequired deletes the secret', () async {
    await seedBoundDevice(database: db, store: secrets, target: backend);
    await metadataStore.enterSnapshotInProgress();
    final wrapper = DelegatingBackend(backend);
    wrapper.onComplete = (credential, request) =>
        const DeviceAuthorizationRequired<ReconcileResponse>(message: 'denied');

    final error = await enrollError(
      () => service(backendOverride: wrapper).enroll(),
    );

    expect(error.step, 'reconcileComplete');
    expect(error.code, 'device_authorization_required');
    expect(await secrets.read(syncDeviceSecretKey), isNull);
    final snapshot = await metadataStore.snapshot();
    expect(snapshot.phase, SyncEnrollmentPhase.bindingAuthorizationRequired);
  });

  test('absent device secret wins over an absent bearer', () async {
    await secrets.write(syncE2EKeySecretKey, base64Url.encode(validE2EKey()));
    await metadataStore.enterSnapshotInProgress();

    final error = await enrollError(service().enroll);

    expect(error.step, 'reconcileBegin');
    expect(error.code, 'device_authorization_required');
    final snapshot = await metadataStore.snapshot();
    expect(snapshot.phase, SyncEnrollmentPhase.bindingAuthorizationRequired);
    expect(snapshot.reauthResumePhase, isNull);
  });

  test('malformed device secret is deleted before binding repair', () async {
    await secrets.write(syncE2EKeySecretKey, base64Url.encode(validE2EKey()));
    await secrets.write(syncDeviceSecretKey, '!!!-not-a-secret-!!!');
    await metadataStore.enterSnapshotInProgress();

    final error = await enrollError(service().enroll);

    expect(error.step, 'reconcileBegin');
    expect(error.code, 'device_authorization_required');
    expect(await secrets.read(syncDeviceSecretKey), isNull);
    final snapshot = await metadataStore.snapshot();
    expect(snapshot.phase, SyncEnrollmentPhase.bindingAuthorizationRequired);
    expect(snapshot.reauthResumePhase, isNull);
  });

  test('valid secret with an absent bearer enters session reauth', () async {
    final id = await deviceID(db);
    backend.provisionBoundDevice(
      deviceID: id,
      bearerToken: 'server-bearer',
      deviceSecret: validDeviceSecret(),
    );
    await secrets.write(syncE2EKeySecretKey, base64Url.encode(validE2EKey()));
    await secrets.write(syncDeviceSecretKey, validDeviceSecret());
    await metadataStore.enterSnapshotInProgress();

    final error = await enrollError(service().enroll);

    expect(error.step, 'reconcileBegin');
    expect(error.code, 'credential_expired');
    final snapshot = await metadataStore.snapshot();
    expect(snapshot.phase, SyncEnrollmentPhase.sessionReauthRequired);
    expect(snapshot.reauthResumePhase, SyncEnrollmentPhase.snapshotInProgress);
  });

  test('device-secret read failure stops without claiming repair', () async {
    await seedBoundDevice(database: db, store: secrets, target: backend);
    await metadataStore.enterSnapshotInProgress();
    secrets.readFailure = const SecretStoreException();
    secrets.readFailureKey = syncDeviceSecretKey;

    Object? thrown;
    try {
      await service().enroll();
    } catch (error) {
      thrown = error;
    } finally {
      secrets.readFailure = null;
      secrets.readFailureKey = null;
    }

    expect(
      thrown,
      isA<CredentialUnavailableException>().having(
        (error) => error.reason,
        'reason',
        CredentialUnavailableReason.storageFailed,
      ),
    );
    expect(backend.calls, isEmpty);
    final snapshot = await metadataStore.snapshot();
    expect(snapshot.phase, SyncEnrollmentPhase.snapshotInProgress);
  });

  test('complete reconcile carries the hashed empty snapshot', () async {
    await seedBoundDevice(database: db, store: secrets, target: backend);
    await metadataStore.enterSnapshotInProgress();
    Map<SyncCollection, String>? sentHashes;
    final wrapper = DelegatingBackend(backend);
    wrapper.onComplete = (credential, request) {
      sentHashes = (request as CompleteReconcile).collectionHashes;
      return SyncSuccess(ReconcileResponse(const {}));
    };

    await service(backendOverride: wrapper).enroll();

    expect(sentHashes, {
      for (final collection in SyncCollection.values)
        collection: computeSnapshotHash(const <SyncEnvelope>[]),
    });
    expect(sentHashes!.keys.toSet(), SyncCollection.values.toSet());
  });

  test(
    'snapshot pulls carry the begin-reconcile context, never a cursor',
    () async {
      await seedBoundDevice(database: db, store: secrets, target: backend);
      await metadataStore.enterSnapshotInProgress();
      final seenPulls = <PullRequest>[];
      final wrapper = DelegatingBackend(backend);
      wrapper.onPullOverride = (credential, request) async {
        seenPulls.add(request);
        return wrapper.inner.pull(credential, request);
      };

      await service(backendOverride: wrapper).enroll();

      expect(
        seenPulls.map((request) => request.collection),
        SyncCollection.values,
      );
      for (final request in seenPulls) {
        expect(request.cursor, isNull);
        final context = request.reconciliation;
        expect(context, isNotNull);
        expect(context!.snapshotWatermark, isNotEmpty);
      }
      expect(wrapper.operationCredentials.toSet(), hasLength(1));
    },
  );

  test(
    'a complete-reconcile response without a write proof leaves none stored',
    () async {
      await seedBoundDevice(database: db, store: secrets, target: backend);
      await metadataStore.enterSnapshotInProgress();

      await service().enroll();

      expect(await secrets.read(syncWriteProofSecretKey), isNull);
      expect(
        (await metadataStore.snapshot()).phase,
        SyncEnrollmentPhase.gateEnabled,
      );
    },
  );

  test(
    'reconcile-begin failure keeps snapshotInProgress and blocks writes',
    () async {
      await seedBoundDevice(database: db, store: secrets, target: backend);
      await metadataStore.enterSnapshotInProgress();
      final wrapper = DelegatingBackend(backend);
      wrapper.onBoundBegin = (credential, request) =>
          NetworkUnavailable<ReconcileResponse>(message: 'offline');

      final error = await enrollError(
        () => service(backendOverride: wrapper).enroll(),
      );

      expect(
        error,
        isA<SyncEnrollmentException>()
            .having((e) => e.step, 'step', 'reconcileBegin')
            .having((e) => e.code, 'code', 'network_unavailable')
            .having((e) => e.message, 'message', 'offline'),
      );
      final snapshot = await metadataStore.snapshot();
      expect(snapshot.phase, SyncEnrollmentPhase.snapshotInProgress);
      expect(snapshot.writeEnabled, isFalse);
    },
  );

  test('reconcile-complete failure keeps snapshotInProgress', () async {
    await seedBoundDevice(database: db, store: secrets, target: backend);
    await metadataStore.enterSnapshotInProgress();
    final wrapper = DelegatingBackend(backend);
    wrapper.onComplete = (credential, request) =>
        const SnapshotHashMismatch<ReconcileResponse>(
          message: 'hashes diverged',
        );

    final error = await enrollError(
      () => service(backendOverride: wrapper).enroll(),
    );

    expect(
      error,
      isA<SyncEnrollmentException>()
          .having((e) => e.step, 'step', 'reconcileComplete')
          .having((e) => e.code, 'code', 'snapshot_hash_mismatch'),
    );
    final snapshot = await metadataStore.snapshot();
    expect(snapshot.phase, SyncEnrollmentPhase.snapshotInProgress);
    expect(snapshot.writeEnabled, isFalse);
  });

  test(
    'one named mismatch re-pages only that collection, then succeeds',
    () async {
      await seedBoundDevice(database: db, store: secrets, target: backend);
      await metadataStore.enterSnapshotInProgress();
      final firstEntries = entriesEnvelope('row-e1');
      final secondEntries = entriesEnvelope('row-e2');
      final pullCounts = <SyncCollection, int>{};
      var entriesPulls = 0;
      var completeCalls = 0;
      final completions = <Map<SyncCollection, String>>[];
      final wrapper = DelegatingBackend(
        emptySnapshotBackend(
          onPull: (credential, request) async {
            pullCounts.update(
              request.collection,
              (count) => count + 1,
              ifAbsent: () => 1,
            );
            if (request.collection == SyncCollection.entries) {
              entriesPulls++;
              final envelope = entriesPulls == 1 ? firstEntries : secondEntries;
              return SyncSuccess(
                PullResponse(<String, Object?>{
                  'envelopes': <Object?>[envelope.toWireJson()],
                  'cursor': 'cursor-e$entriesPulls',
                  'end_of_snapshot': true,
                }),
              );
            }
            return SyncSuccess(
              PullResponse(const <String, Object?>{
                'envelopes': <Object?>[],
                'cursor': 'cursor-0',
                'end_of_snapshot': true,
              }),
            );
          },
        ),
      );
      wrapper.onComplete = (credential, request) {
        completeCalls++;
        completions.add((request as CompleteReconcile).collectionHashes);
        if (completeCalls == 1) {
          return const SnapshotHashMismatch<ReconcileResponse>(
            message: 'entries diverged',
            mismatchedCollection: SyncCollection.entries,
          );
        }
        return SyncSuccess(
          ReconcileResponse(const {'write_proof': 'proof-123'}),
        );
      };

      await service(backendOverride: wrapper).enroll();

      expect(completeCalls, 2);
      expect(
        completions[0][SyncCollection.entries],
        computeSnapshotHash([firstEntries]),
      );
      expect(
        completions[1][SyncCollection.entries],
        computeSnapshotHash([secondEntries]),
      );
      for (final collection in SyncCollection.values) {
        if (collection != SyncCollection.entries) {
          expect(
            completions[1][collection],
            completions[0][collection],
            reason: 'only the named collection is re-paged.',
          );
          expect(pullCounts[collection], 1);
        }
      }
      expect(pullCounts[SyncCollection.entries], 2);
      expect(wrapper.operationCredentials.toSet(), hasLength(1));
      expect(await secrets.read(syncWriteProofSecretKey), 'proof-123');
      final snapshot = await metadataStore.snapshot();
      expect(snapshot.phase, SyncEnrollmentPhase.gateEnabled);
      expect(snapshot.writeEnabled, isTrue);
    },
  );

  test('a repeated mismatch fails safely with the gate closed', () async {
    await seedBoundDevice(database: db, store: secrets, target: backend);
    await metadataStore.enterSnapshotInProgress();
    var completeCalls = 0;
    final wrapper = DelegatingBackend(backend);
    wrapper.onComplete = (credential, request) {
      completeCalls++;
      return const SnapshotHashMismatch<ReconcileResponse>(
        message: 'entries diverged',
        mismatchedCollection: SyncCollection.entries,
      );
    };

    final error = await enrollError(
      () => service(backendOverride: wrapper).enroll(),
    );

    expect(
      error,
      isA<SyncEnrollmentException>()
          .having((e) => e.step, 'step', 'reconcileComplete')
          .having((e) => e.code, 'code', 'snapshot_hash_mismatch'),
    );
    expect(completeCalls, 2);
    final snapshot = await metadataStore.snapshot();
    expect(snapshot.phase, SyncEnrollmentPhase.snapshotInProgress);
    expect(snapshot.writeEnabled, isFalse);
  });

  test('illegal hosted state is rejected before any backend call', () async {
    await metadataStore.setEnrollmentPhase(
      SyncEnrollmentPhase.snapshotInProgress,
    );
    await configureHandshakeSuccess();

    final error = await enrollError(service().enroll);

    expect(error.step, 'enroll');
    expect(error.code, 'invalid_request');
    expect(authenticator.beginCalls, 0);
    expect(authenticator.completeCalls, 0);
    expect(backend.calls, isEmpty);
  });

  test('wrong-length resolved key fails without writing anything', () async {
    Object? thrown;
    try {
      await service(
        resolveE2EKey: () async => Uint8List.fromList(List<int>.filled(16, 7)),
      ).enroll();
    } catch (error) {
      thrown = error;
    }

    expect(
      thrown,
      isA<SyncE2EKeyUnavailableException>().having(
        (error) => error.reason,
        'reason',
        SyncE2EKeyUnavailableReason.wrongLength,
      ),
    );
    expect(await secrets.read(syncE2EKeySecretKey), isNull);
    expect(backend.calls, isEmpty);
    final snapshot = await metadataStore.snapshot();
    expect(snapshot.phase, SyncEnrollmentPhase.notEnrolled);
    expect(snapshot.writeEnabled, isFalse);
  });

  test(
    'malformed stored key is a hard failure that preserves the secret',
    () async {
      const malformed = '!!!-not-base64url-!!!';
      await secrets.write(syncE2EKeySecretKey, malformed);
      var resolveKeyCalls = 0;

      Object? thrown;
      try {
        await service(
          resolveE2EKey: () async {
            resolveKeyCalls++;
            return validE2EKey();
          },
        ).enroll();
      } catch (error) {
        thrown = error;
      }

      expect(
        thrown,
        isA<SyncE2EKeyUnavailableException>().having(
          (error) => error.reason,
          'reason',
          SyncE2EKeyUnavailableReason.malformed,
        ),
      );
      expect(resolveKeyCalls, 0);
      expect(await secrets.read(syncE2EKeySecretKey), malformed);
      expect(backend.calls, isEmpty);
      final snapshot = await metadataStore.snapshot();
      expect(snapshot.phase, SyncEnrollmentPhase.notEnrolled);
      expect(snapshot.writeEnabled, isFalse);
    },
  );

  test('valid stored key is reused without calling resolveE2EKey', () async {
    final encoded = base64Url.encode(validE2EKey());
    await secrets.write(syncE2EKeySecretKey, encoded);
    var resolveKeyCalls = 0;

    await service(
      resolveE2EKey: () async {
        resolveKeyCalls++;
        return validE2EKey();
      },
    ).enroll();

    expect(resolveKeyCalls, 0);
    expect(await secrets.read(syncE2EKeySecretKey), encoded);
    final snapshot = await metadataStore.snapshot();
    expect(snapshot.phase, SyncEnrollmentPhase.gateEnabled);
    expect(snapshot.writeEnabled, isTrue);
  });

  test('resume from reconciliationComplete only flips the gate', () async {
    await metadataStore.enterReconciliationComplete();
    await configureHandshakeSuccess();

    await service().enroll();

    expect(authenticator.beginCalls, 0);
    expect(backend.calls, isEmpty);
    final snapshot = await metadataStore.snapshot();
    expect(snapshot.phase, SyncEnrollmentPhase.gateEnabled);
    expect(snapshot.writeEnabled, isTrue);
  });

  group('shared repair gate (IR4)', () {
    test(
      'the service uses the database gate shared with coordinators',
      () async {
        expect(
          identical(service().repairGate, SyncRepairGate.forDatabase(db)),
          isTrue,
        );
      },
    );

    test('device-secret mutations wait on the shared gate lock', () async {
      await secrets.write(syncDeviceSecretKey, validDeviceSecret());
      final gate = SyncRepairGate.forDatabase(db);
      final release = Completer<void>();
      var holderExited = false;
      final held = gate.withSecretMutationLock(() async {
        await release.future;
        holderExited = true;
      });

      final enrollment = service().enroll();
      for (var i = 0; i < 200; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(holderExited, isFalse);
      expect(await secrets.read(syncDeviceSecretKey), validDeviceSecret());

      release.complete();
      await enrollment;
      await held;

      expect(holderExited, isTrue);
      final snapshot = await metadataStore.snapshot();
      expect(snapshot.phase, SyncEnrollmentPhase.gateEnabled);
    });
  });
}
