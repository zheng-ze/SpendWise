import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/persistence/device_identity.dart';
import 'package:spendwise/persistence/ledger_database.dart';
import 'package:spendwise/sync/sync_e2e_key_provider.dart';
import 'package:spendwise/sync/sync_enrollment_service.dart';
import 'package:spendwise/sync/sync_metadata_store.dart';
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

Map<SyncCollection, String> testHashes() => {
  for (final collection in SyncCollection.values)
    collection: 'hash-${collection.name}',
};

Uint8List validE2EKey() =>
    Uint8List.fromList(List<int>.generate(32, (index) => index));

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
    backend = InMemorySyncBackend();
  });

  tearDown(() => db.close());

  SyncEnrollmentService service({
    Future<Uint8List> Function()? resolveE2EKey,
    Future<Map<SyncCollection, String>> Function()? resolveCollectionHashes,
  }) => SyncEnrollmentService(
    authenticator: authenticator,
    backend: backend,
    metadataStore: metadataStore,
    secretStore: secrets,
    database: db,
    buildBeginRequest: () => BeginEnrollmentRequest(const {}),
    buildCompleteRequest: (challenge) async =>
        CompleteEnrollmentRequest(const {}),
    resolveE2EKey: resolveE2EKey ?? () async => validE2EKey(),
    resolveCollectionHashes:
        resolveCollectionHashes ?? () async => testHashes(),
  );

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

  test('happy path drives notEnrolled all the way to gateEnabled', () async {
    await configureHandshakeSuccess();
    final reconcileTypes = <Type>[];
    backend = InMemorySyncBackend(
      onReconcile: (credential, request) async {
        reconcileTypes.add(request.runtimeType);
        return SyncSuccess(ReconcileResponse(const {}));
      },
    );

    await service().enroll();

    expect(authenticator.beginCalls, 1);
    expect(authenticator.completeCalls, 1);
    expect(reconcileTypes, [BeginReconcile, CompleteReconcile]);
    final storedCredential = await secrets.read(syncCredentialSecretKey);
    expect(storedCredential, isNotNull);
    final storedKey = await secrets.read(syncE2EKeySecretKey);
    expect(storedKey, isNotNull);
    expect(decodeAndValidateSyncE2EKey(storedKey!), validE2EKey());
    final snapshot = await metadataStore.snapshot();
    expect(snapshot.phase, SyncEnrollmentPhase.gateEnabled);
    expect(snapshot.writeEnabled, isTrue);
  });

  test(
    'crash after credential write resumes without re-running the handshake',
    () async {
      final id = await deviceID(db);
      final credential = const CredentialCodec().restore(
        credentialPayload(id, 'test-bearer'),
      );
      await secrets.write(
        syncCredentialSecretKey,
        const CredentialCodec().export(credential),
      );
      await configureHandshakeSuccess();

      await service().enroll();

      expect(authenticator.beginCalls, 0);
      expect(authenticator.completeCalls, 0);
      final snapshot = await metadataStore.snapshot();
      expect(snapshot.phase, SyncEnrollmentPhase.gateEnabled);
      expect(snapshot.writeEnabled, isTrue);
    },
  );

  test('credential for another device is deleted and re-enrolled', () async {
    await secrets.write(
      syncCredentialSecretKey,
      credentialPayload('another-device', 'test-bearer'),
    );
    await configureHandshakeSuccess();

    await service().enroll();

    expect(authenticator.beginCalls, 1);
    expect(authenticator.completeCalls, 1);
    final stored = await secrets.read(syncCredentialSecretKey);
    final restored = const CredentialCodec().restore(stored!);
    expect(restored.deviceID, await deviceID(db));
    final snapshot = await metadataStore.snapshot();
    expect(snapshot.phase, SyncEnrollmentPhase.gateEnabled);
    expect(snapshot.writeEnabled, isTrue);
  });

  test('malformed credential payload is deleted and re-enrolled', () async {
    await secrets.write(
      syncCredentialSecretKey,
      base64Url.encode(utf8.encode('not-a-credential')),
    );
    await configureHandshakeSuccess();

    await service().enroll();

    expect(authenticator.beginCalls, 1);
    expect(authenticator.completeCalls, 1);
    final stored = await secrets.read(syncCredentialSecretKey);
    expect(
      const CredentialCodec().restore(stored!).deviceID,
      await deviceID(db),
    );
    expect(
      (await metadataStore.snapshot()).phase,
      SyncEnrollmentPhase.gateEnabled,
    );
  });

  test('resume from snapshotInProgress skips handshake and key work', () async {
    final id = await deviceID(db);
    final credential = const CredentialCodec().restore(
      credentialPayload(id, 'test-bearer'),
    );
    await secrets.write(
      syncCredentialSecretKey,
      const CredentialCodec().export(credential),
    );
    await secrets.write(syncE2EKeySecretKey, base64Url.encode(validE2EKey()));
    await metadataStore.setEnrollmentPhase(
      SyncEnrollmentPhase.snapshotInProgress,
    );
    await configureHandshakeSuccess();
    var resolveKeyCalls = 0;

    await service(
      resolveE2EKey: () async {
        resolveKeyCalls++;
        return validE2EKey();
      },
    ).enroll();

    expect(authenticator.beginCalls, 0);
    expect(authenticator.completeCalls, 0);
    expect(resolveKeyCalls, 0);
    expect(backend.calls, ['reconcile', 'reconcile']);
    expect(
      (await metadataStore.snapshot()).phase,
      SyncEnrollmentPhase.gateEnabled,
    );
  });

  test('resume from reconciliationComplete only flips the gate', () async {
    final id = await deviceID(db);
    final credential = const CredentialCodec().restore(
      credentialPayload(id, 'test-bearer'),
    );
    await secrets.write(
      syncCredentialSecretKey,
      const CredentialCodec().export(credential),
    );
    await metadataStore.setEnrollmentPhase(
      SyncEnrollmentPhase.reconciliationComplete,
    );
    await configureHandshakeSuccess();

    await service().enroll();

    expect(authenticator.beginCalls, 0);
    expect(backend.calls, isEmpty);
    final snapshot = await metadataStore.snapshot();
    expect(snapshot.phase, SyncEnrollmentPhase.gateEnabled);
    expect(snapshot.writeEnabled, isTrue);
  });

  test('complete reconcile carries exactly the resolved hashes', () async {
    await configureHandshakeSuccess();
    Map<SyncCollection, String>? sentHashes;
    backend = InMemorySyncBackend(
      onReconcile: (credential, request) async {
        if (request is CompleteReconcile) {
          sentHashes = request.collectionHashes;
        }
        return SyncSuccess(ReconcileResponse(const {}));
      },
    );

    await service().enroll();

    expect(sentHashes, testHashes());
    expect(sentHashes!.keys.toSet(), SyncCollection.values.toSet());
  });

  test(
    'reconcile-begin failure keeps snapshotInProgress and blocks writes',
    () async {
      await configureHandshakeSuccess();
      final reconcileTypes = <Type>[];
      backend = InMemorySyncBackend(
        onReconcile: (credential, request) async {
          reconcileTypes.add(request.runtimeType);
          return NetworkUnavailable<ReconcileResponse>(message: 'offline');
        },
      );

      final error = await enrollError(service().enroll);

      expect(
        error,
        isA<SyncEnrollmentException>()
            .having((e) => e.step, 'step', 'reconcileBegin')
            .having((e) => e.code, 'code', 'network_unavailable')
            .having((e) => e.message, 'message', 'offline'),
      );
      expect(reconcileTypes, [BeginReconcile]);
      final snapshot = await metadataStore.snapshot();
      expect(snapshot.phase, SyncEnrollmentPhase.snapshotInProgress);
      expect(snapshot.writeEnabled, isFalse);
    },
  );

  test('reconcile-complete failure keeps snapshotInProgress', () async {
    await configureHandshakeSuccess();
    final reconcileTypes = <Type>[];
    backend = InMemorySyncBackend(
      onReconcile: (credential, request) async {
        reconcileTypes.add(request.runtimeType);
        if (request is CompleteReconcile) {
          return SnapshotHashMismatch<ReconcileResponse>(
            message: 'hashes diverged',
          );
        }
        return SyncSuccess(ReconcileResponse(const {}));
      },
    );

    final error = await enrollError(service().enroll);

    expect(
      error,
      isA<SyncEnrollmentException>()
          .having((e) => e.step, 'step', 'reconcileComplete')
          .having((e) => e.code, 'code', 'snapshot_hash_mismatch'),
    );
    expect(reconcileTypes, [BeginReconcile, CompleteReconcile]);
    final snapshot = await metadataStore.snapshot();
    expect(snapshot.phase, SyncEnrollmentPhase.snapshotInProgress);
    expect(snapshot.writeEnabled, isFalse);
  });

  test('wrong-length resolved key fails without writing anything', () async {
    await configureHandshakeSuccess();

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
    final snapshot = await metadataStore.snapshot();
    expect(snapshot.phase, SyncEnrollmentPhase.credentialAcquired);
    expect(snapshot.writeEnabled, isFalse);
  });

  test(
    'malformed stored key is a hard failure that preserves the secret',
    () async {
      await configureHandshakeSuccess();
      await metadataStore.setEnrollmentPhase(
        SyncEnrollmentPhase.credentialAcquired,
      );
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
      final snapshot = await metadataStore.snapshot();
      expect(snapshot.phase, SyncEnrollmentPhase.credentialAcquired);
      expect(snapshot.writeEnabled, isFalse);
    },
  );

  test(
    'wrong-length stored key is a hard failure that preserves the secret',
    () async {
      await configureHandshakeSuccess();
      await metadataStore.setEnrollmentPhase(
        SyncEnrollmentPhase.credentialAcquired,
      );
      final shortKey = base64Url.encode(List<int>.filled(16, 7));
      await secrets.write(syncE2EKeySecretKey, shortKey);

      Object? thrown;
      try {
        await service().enroll();
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
      expect(await secrets.read(syncE2EKeySecretKey), shortKey);
      final snapshot = await metadataStore.snapshot();
      expect(snapshot.phase, SyncEnrollmentPhase.credentialAcquired);
      expect(snapshot.writeEnabled, isFalse);
    },
  );

  test('valid stored key is reused without calling resolveE2EKey', () async {
    final id = await deviceID(db);
    final credential = const CredentialCodec().restore(
      credentialPayload(id, 'test-bearer'),
    );
    await secrets.write(
      syncCredentialSecretKey,
      const CredentialCodec().export(credential),
    );
    await metadataStore.setEnrollmentPhase(
      SyncEnrollmentPhase.credentialAcquired,
    );
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

  test(
    'beginEnrollment credential-expired failure translates and writes nothing',
    () async {
      authenticator.onBegin = () =>
          const CredentialExpired<EnrollmentChallenge>(message: 'expired');

      final error = await enrollError(service().enroll);

      expect(error.step, 'beginEnrollment');
      expect(error.code, 'credential_expired');
      expect(error.message, 'expired');
      expect(error.retryAfter, isNull);
      expect(authenticator.completeCalls, 0);
      expect(await secrets.read(syncCredentialSecretKey), isNull);
      final snapshot = await metadataStore.snapshot();
      expect(snapshot.phase, SyncEnrollmentPhase.notEnrolled);
      expect(snapshot.writeEnabled, isFalse);
    },
  );

  test('beginEnrollment rate-limited failure preserves retryAfter', () async {
    const retryAfter = Duration(seconds: 30);
    authenticator.onBegin = () => const RateLimited<EnrollmentChallenge>(
      message: 'slow down',
      retryAfter: retryAfter,
    );

    final error = await enrollError(service().enroll);

    expect(error.step, 'beginEnrollment');
    expect(error.code, 'rate_limited');
    expect(error.message, 'slow down');
    expect(error.retryAfter, retryAfter);
    expect(await secrets.read(syncCredentialSecretKey), isNull);
    expect(
      (await metadataStore.snapshot()).phase,
      SyncEnrollmentPhase.notEnrolled,
    );
  });

  test(
    'beginEnrollment network failure translates and writes nothing',
    () async {
      authenticator.onBegin = () =>
          const NetworkUnavailable<EnrollmentChallenge>();

      final error = await enrollError(service().enroll);

      expect(error.step, 'beginEnrollment');
      expect(error.code, 'network_unavailable');
      expect(await secrets.read(syncCredentialSecretKey), isNull);
      expect(
        (await metadataStore.snapshot()).phase,
        SyncEnrollmentPhase.notEnrolled,
      );
    },
  );

  test('completeEnrollment failure translates and writes nothing', () async {
    authenticator.onComplete = () =>
        const SnapshotHashMismatch<DeviceCredential>(message: 'proof rejected');

    final error = await enrollError(service().enroll);

    expect(error.step, 'completeEnrollment');
    expect(error.code, 'snapshot_hash_mismatch');
    expect(error.message, 'proof rejected');
    expect(authenticator.beginCalls, 1);
    expect(await secrets.read(syncCredentialSecretKey), isNull);
    final snapshot = await metadataStore.snapshot();
    expect(snapshot.phase, SyncEnrollmentPhase.notEnrolled);
    expect(snapshot.writeEnabled, isFalse);
  });
}
