import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:spendwise/ledger/event_bus.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/persistence/device_identity.dart';
import 'package:spendwise/persistence/drift_ledger_store.dart';
import 'package:spendwise/persistence/ledger_database.dart'
    hide Account, SubPocket, Entry, Budget;
import 'package:spendwise/persistence/ledger_store.dart';
import 'package:spendwise/persistence/persistence_processor.dart';
import 'package:spendwise/sync/cached_collection_version_source.dart';
import 'package:spendwise/sync/collection_version_reader.dart';
import 'package:spendwise/sync/credential_provider.dart';
import 'package:spendwise/sync/drift_sync_staging_store.dart';
import 'package:spendwise/sync/post_flush_readback_verifier.dart';
import 'package:spendwise/sync/reconciliation_snapshot_hasher.dart';
import 'package:spendwise/sync/secret_store.dart';
import 'package:spendwise/sync/sync_backend_resolver.dart';
import 'package:spendwise/sync/sync_coordinator.dart';
import 'package:spendwise/sync/sync_e2e_key_provider.dart';
import 'package:spendwise/sync/sync_enrollment_service.dart';
import 'package:spendwise/sync/sync_metadata_store.dart';
import 'package:spendwise/sync/sync_repair_gate.dart';
import 'package:spendwise/sync/sync_secret_keys.dart';
import 'package:spendwise/sync/sync_status.dart';
import 'package:sync/sync.dart';

import '../support/recording_ledger_store.dart';
import 'in_memory_secret_store.dart';

String _encodeKey(List<int> bytes) =>
    base64Url.encode(bytes).replaceAll('=', '');

Uint8List _freshKey() =>
    Uint8List.fromList(List<int>.generate(32, (index) => index));

final class _RecordingHttpClient extends http.BaseClient {
  int requests = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    requests++;
    throw StateError('No network in SyncCoordinator tests.');
  }
}

final class _UnusedEnrollmentCollaborators
    implements SyncAuthenticator, DeviceBindingAuthorizer {
  @override
  Future<SyncOutcome<EnrollmentChallenge>> beginEnrollment(
    BeginEnrollmentRequest request,
  ) => throw StateError('Unexpected enrollment authentication.');

  @override
  Future<SyncOutcome<DeviceCredential>> completeEnrollment(
    CompleteEnrollmentRequest request,
  ) => throw StateError('Unexpected enrollment authentication.');

  @override
  Future<SyncOutcome<DeviceCredential>> refreshCredential(
    DeviceCredential credential,
  ) => throw StateError('Unexpected credential refresh.');

  @override
  Future<SyncOutcome<StartDeviceBindingResponse>> startBinding(
    StartDeviceBindingRequest request,
  ) => throw StateError('Unexpected binding start.');

  @override
  Future<SyncOutcome<VerifyDeviceBindingResponse>> verifyBinding(
    VerifyDeviceBindingRequest request,
  ) => throw StateError('Unexpected binding verification.');
}

final class _FakeSyncBackend implements SyncBackend {
  _FakeSyncBackend({
    Map<SyncCollection, PullResponse>? pages,
    this.failure,
    Map<SyncCollection, SyncOutcome<AcknowledgeResponse>>? acknowledgeOutcomes,
  }) : pages = Map<SyncCollection, PullResponse>.of(pages ?? const {}),
       acknowledgeOutcomes = acknowledgeOutcomes ?? const {};

  final Map<SyncCollection, PullResponse> pages;

  SyncOutcome<PullResponse>? failure;
  final Map<SyncCollection, SyncOutcome<AcknowledgeResponse>>
  acknowledgeOutcomes;
  final List<PullRequest> pulls = [];
  final List<AcknowledgeRequest> acknowledges = [];
  final List<PushRequest> pushes = [];
  final List<SyncCredential> pullCredentials = [];
  final List<SyncCredential> acknowledgeCredentials = [];
  final List<SyncCredential> pushCredentials = [];

  Future<SyncOutcome<PushResponse>> Function(PushRequest request)? onPush;
  Future<SyncOutcome<ReconcileResponse>> Function(
    SyncCredential credential,
    ReconcileRequest request,
  )?
  onReconcile;
  Future<SyncOutcome<AcknowledgeResponse>> Function(AcknowledgeRequest request)?
  onAcknowledge;
  Future<SyncOutcome<PullResponse>> Function(PullRequest request)?
  onPullRequest;

  @override
  Future<SyncOutcome<PullResponse>> pull(
    SyncCredential credential,
    PullRequest request,
  ) async {
    pulls.add(request);
    pullCredentials.add(credential);
    final hook = onPullRequest;
    if (hook != null) return hook(request);
    final SyncOutcome<PullResponse>? failure = this.failure;
    if (failure != null) return failure;
    final page = pages[request.collection];
    if (page == null) {
      throw StateError('No stubbed pull page for ${request.collection}.');
    }
    return SyncSuccess<PullResponse>(page);
  }

  @override
  Future<SyncOutcome<PushResponse>> push(
    SyncCredential credential,
    PushRequest request,
  ) async {
    pushes.add(request);
    pushCredentials.add(credential);
    final handler = onPush;
    if (handler == null) {
      throw StateError('No stubbed push outcome.');
    }
    return handler(request);
  }

  @override
  Future<SyncOutcome<ReconcileResponse>> reconcile(
    SyncCredential credential,
    ReconcileRequest request,
  ) =>
      onReconcile?.call(credential, request) ??
      Future<SyncOutcome<ReconcileResponse>>.error(
        UnimplementedError('No stubbed reconcile outcome.'),
      );

  @override
  Future<SyncOutcome<AcknowledgeResponse>> acknowledge(
    SyncCredential credential,
    AcknowledgeRequest request,
  ) async {
    acknowledges.add(request);
    acknowledgeCredentials.add(credential);
    final handler = onAcknowledge;
    if (handler != null) return handler(request);
    return acknowledgeOutcomes[request.collection] ??
        SyncSuccess<AcknowledgeResponse>(
          AcknowledgeResponse(<String, Object?>{}),
        );
  }
}

final class _LatchingSecretStore implements SecretStore {
  _LatchingSecretStore(this.inner, this.gate);

  final InMemorySecretStore inner;
  final SyncRepairGate gate;
  var latched = false;

  @override
  Future<String?> read(String key) async {
    if (!latched && key == syncDeviceSecretKey) {
      latched = true;
      await gate.latch();
    }
    return inner.read(key);
  }

  @override
  Future<void> write(String key, String value) => inner.write(key, value);

  @override
  Future<void> delete(String key) => inner.delete(key);
}

final class _BlockingDeleteSecretStore implements SecretStore {
  _BlockingDeleteSecretStore(this.inner);

  final InMemorySecretStore inner;
  final deleteStarted = Completer<void>();
  final releaseDelete = Completer<void>();

  @override
  Future<String?> read(String key) => inner.read(key);

  @override
  Future<void> write(String key, String value) => inner.write(key, value);

  @override
  Future<void> delete(String key) async {
    if (key == syncDeviceSecretKey) {
      deleteStarted.complete();
      await releaseDelete.future;
    }
    await inner.delete(key);
  }
}

final class _RotatingMissingSecretStore implements SecretStore {
  _RotatingMissingSecretStore(this.inner, this.gate);

  final InMemorySecretStore inner;
  final SyncRepairGate gate;
  var replaced = false;

  @override
  Future<String?> read(String key) async {
    if (key == syncDeviceSecretKey && !replaced) {
      replaced = true;
      await gate.withSecretMutationLock(
        () => inner.write(syncDeviceSecretKey, _deviceSecret(9)),
      );
      return null;
    }
    return inner.read(key);
  }

  @override
  Future<void> write(String key, String value) => inner.write(key, value);

  @override
  Future<void> delete(String key) => inner.delete(key);
}

Entry _pullTestEntry(String id) => Entry(
  id: id,
  date: DateTime.utc(2024, 3, 15),
  amount: Decimal.parse('-12.50'),
  name: 'Coffee',
  categoryID: 'cccccccc-0000-1111-2222-555555555555',
  sourceID: 'aaaaaaaa-0000-1111-2222-333333333333',
  includeInAnalysis: true,
);

Future<SyncEnvelope> _pullEnvelope({
  required Uint8List key,
  required String rowID,
  required VersionVector version,
  LedgerChange? change,
  SyncCollection collection = SyncCollection.entries,
}) async {
  const cipher = SyncCipher();
  const codec = PayloadCodec();
  const userID = 'user';
  final normalized = normalizedID(rowID);
  SyncEnvelope preview({required String ciphertext}) => SyncEnvelope(
    protocolVersion: syncProtocolVersion,
    userID: userID,
    collection: collection,
    rowID: normalized,
    siblingID: computeSiblingID(
      userID: userID,
      collection: collection,
      rowID: normalized,
      versionVector: version,
    ),
    versionVector: version,
    lifecycle: SiblingLifecycle.live,
    ciphertext: ciphertext,
  );
  final payload = change == null ? const <int>[] : codec.encodeChange(change);
  final framed = await cipher.encrypt(
    key: key,
    plaintext: Uint8List.fromList(payload),
    aad: preview(ciphertext: '').aadBytes(),
  );
  return preview(ciphertext: base64Url.encode(framed).replaceAll('=', ''));
}

PullResponse _pullPage(List<SyncEnvelope> envelopes, String cursor) =>
    PullResponse(<String, Object?>{
      'envelopes': [for (final envelope in envelopes) envelope.toWireJson()],
      'cursor': cursor,
    });

String _credentialPayload(String deviceID, String bearer) => base64Url.encode(
  utf8.encode(
    jsonEncode({
      'deviceID': deviceID,
      'bearerToken': base64Url.encode(utf8.encode(bearer)),
    }),
  ),
);

String _deviceSecret([int fill = 0]) =>
    base64Url.encode(List<int>.filled(32, fill)).replaceAll('=', '');

void main() {
  late LedgerDatabase db;
  late InMemorySecretStore secrets;
  late RecordingLedgerStore store;
  late EventBus bus;
  late Ledger ledger;
  late PersistenceProcessor processor;
  late _RecordingHttpClient httpSpy;

  setUp(() {
    db = LedgerDatabase(NativeDatabase.memory());
    secrets = InMemorySecretStore();
    store = RecordingLedgerStore();
    bus = EventBus();
    ledger = Ledger(bus: bus);
    processor = PersistenceProcessor(store: store, bus: bus);
    httpSpy = _RecordingHttpClient();
  });

  tearDown(() async {
    await bus.dispose();
    ledger.dispose();
    await db.close();
  });

  Future<SyncCoordinator> create({SupabaseConfig? supabaseConfig}) =>
      SyncCoordinator.create(
        database: db,
        ledger: ledger,
        persistenceProcessor: processor,
        supabaseConfig: supabaseConfig,
        httpClient: httpSpy,
        secretStore: secrets,
      );

  Future<SyncCoordinator> pullCoordinator({
    required SyncBackend backend,
    required SyncVersionSource versionSource,
    required SyncStagingStore staging,
    required Uint8List e2eKey,
    CollectionVersionReader? reader,
    CollectionVersionReader? versionReader,
    PassFailureHandler? onPassFailure,
    SecretStore? credentialSecrets,
  }) async {
    final id = await deviceID(db);
    await secrets.write(
      syncCredentialSecretKey,
      _credentialPayload(id, 'test-bearer'),
    );
    await secrets.write(syncE2EKeySecretKey, _encodeKey(e2eKey));
    await secrets.write(syncDeviceSecretKey, _deviceSecret());
    await SyncMetadataStore(db).enterSnapshotInProgress();
    return SyncCoordinator.forTesting(
      engine: SyncEngine(
        userID: id,
        keyAccessor: SyncE2EKeyProvider(secretStore: secrets).accessor,
        stagingStore: staging,
      ),
      backend: backend,
      versionSource: versionSource,
      versionReader: versionReader ?? InMemoryCollectionVersionReader(),
      metadataStore: SyncMetadataStore(db),
      verifier: PostFlushReadbackVerifier(
        reader ?? DriftCollectionVersionReader(db),
      ),
      credentialProvider: CredentialProvider(
        database: db,
        secretStore: credentialSecrets ?? secrets,
      ),
      repairGate: SyncRepairGate.forDatabase(db),
      secretStore: credentialSecrets ?? secrets,
      ledger: ledger,
      persistenceProcessor: processor,
      stagingStore: staging,
      onPassFailure: onPassFailure,
    );
  }

  Future<void> expectDuplicatePageCommit(
    SyncCoordinator coordinator,
    _FakeSyncBackend backend,
    String cursor,
    List<LedgerPublication> publications,
  ) async {
    expect(backend.pulls, hasLength(1));
    final snapshot = await coordinator.metadataStore.snapshot();
    expect(snapshot.watermarks[SyncCollection.entries], cursor);
    expect(
      await coordinator.metadataStore.pendingAcknowledgement(
        SyncCollection.entries,
      ),
      cursor,
    );
    expect(await coordinator.metadataStore.acknowledgedVectors(), isEmpty);
    expect(publications, isEmpty);
    expect(store.calls, isEmpty);
    expect(store.enqueuedBatches, isEmpty);
  }

  Future<List<LedgerPublication>> collectPublications(
    Future<void> Function() work,
  ) async {
    final publications = <LedgerPublication>[];
    final subscription = bus.subscribe().listen(publications.add);
    try {
      await work();
    } finally {
      await subscription.cancel();
    }
    return publications;
  }

  Future<_DriftSetup> driftSetup({
    required _FakeSyncBackend backend,
    Uint8List? e2eKey,
    LedgerStore Function(DriftLedgerStore inner)? wrapStore,
    SyncVersionSource Function(SyncVersionSource inner)? wrapVersions,
    SyncEngine Function({
      required String userID,
      required SyncE2EKeyAccessor accessor,
      required SyncStagingStore staging,
    })?
    buildEngine,
    CollectionVersionReader Function(CollectionVersionReader inner)? wrapReader,
  }) async {
    final Uint8List key = e2eKey ?? _freshKey();
    final String id = await deviceID(db);
    await secrets.write(
      syncCredentialSecretKey,
      _credentialPayload(id, 'test-bearer'),
    );
    await secrets.write(syncE2EKeySecretKey, _encodeKey(key));
    await secrets.write(syncDeviceSecretKey, _deviceSecret());
    await SyncMetadataStore(db).enterSnapshotInProgress();
    final clock = _ManualClock();
    final DriftLedgerStore driftStore = DriftLedgerStore(
      db,
      armTimer: clock.arm,
    );
    final LedgerStore effectiveStore =
        wrapStore?.call(driftStore) ?? driftStore;
    final PersistenceProcessor driftProcessor = PersistenceProcessor(
      store: effectiveStore,
      bus: bus,
    );
    await driftProcessor.start();
    addTearDown(driftProcessor.dispose);
    final DriftSyncStagingStore driftStaging = DriftSyncStagingStore(db);
    final CollectionVersionReader baseReader = DriftCollectionVersionReader(db);
    final CollectionVersionReader effectiveReader =
        wrapReader?.call(baseReader) ?? baseReader;
    final SyncVersionSource baseVersions = CachedCollectionVersionSource(
      baseReader,
    );
    final SyncVersionSource effectiveVersions =
        wrapVersions?.call(baseVersions) ?? baseVersions;
    final SyncE2EKeyAccessor accessor = SyncE2EKeyProvider(secretStore: secrets)
        .accessor;
    final SyncEngine engine =
        buildEngine?.call(
          userID: id,
          accessor: accessor,
          staging: driftStaging,
        ) ??
        SyncEngine(
          userID: id,
          keyAccessor: accessor,
          stagingStore: driftStaging,
        );
    final SyncCoordinator coordinator = SyncCoordinator.forTesting(
      engine: engine,
      backend: backend,
      versionSource: effectiveVersions,
      versionReader: effectiveReader,
      metadataStore: SyncMetadataStore(db),
      verifier: PostFlushReadbackVerifier(effectiveReader),
      credentialProvider: CredentialProvider(
        database: db,
        secretStore: secrets,
      ),
      repairGate: SyncRepairGate.forDatabase(db),
      secretStore: secrets,
      ledger: ledger,
      persistenceProcessor: driftProcessor,
      stagingStore: driftStaging,
    );
    return _DriftSetup(
      coordinator: coordinator,
      staging: driftStaging,
      store: driftStore,
      device: id,
      effectiveStore: effectiveStore,
      effectiveVersions: effectiveVersions,
    );
  }

  Future<void> seedDriftHolder(
    String accountID,
    PersistenceProcessor processor,
  ) async {
    ledger.addAccount(
      Account(id: accountID, name: 'holder', type: AccountType.cash),
    );
    await processor.flush();
  }

  Entry driftEntry(String id, String sourceID, {String name = 'Coffee'}) =>
      Entry(
        id: id,
        date: DateTime.utc(2024, 3, 15),
        amount: Decimal.parse('-12.50'),
        name: name,
        sourceID: sourceID,
        includeInAnalysis: true,
      );

  Future<_PushSetup> pushSetup({
    _FakeSyncBackend? backend,
    bool enableWrites = true,
    PassFailureHandler? onPassFailure,
  }) async {
    final effective = backend ?? _FakeSyncBackend();
    final reader = InMemoryCollectionVersionReader();
    final versions = InMemorySyncVersionSource();
    final staging = InMemorySyncStagingStore();
    final coordinator = await pullCoordinator(
      backend: effective,
      versionSource: versions,
      staging: staging,
      e2eKey: _freshKey(),
      versionReader: reader,
      onPassFailure: onPassFailure,
    );
    if (enableWrites) {
      await coordinator.metadataStore.enterReconciliationComplete();
      await coordinator.metadataStore.enterGateEnabled();
    }
    return _PushSetup(
      coordinator: coordinator,
      backend: effective,
      reader: reader,
      versions: versions,
      staging: staging,
    );
  }

  group('custom backend', () {
    test('a coherent pair with a valid custom endpoint returns an idle '
        'coordinator with no eager work', () async {
      await SyncMetadataStore(db).setBackendSelection(
        backend: SyncBackendKind.custom,
        endpoint: 'https://sync.example.com',
      );

      final coordinator = await create();

      expect(coordinator.backend, isA<CustomEndpointSyncBackend>());
      expect(coordinator.status, const SyncIdle());
      expect(secrets.reads, isEmpty);
      expect(httpSpy.requests, 0);
      expect(store.calls, isEmpty);
      expect(store.isStarted, isFalse);
      expect(
        coordinator.versionSource.readRowVersion(
          SyncRowID.of(
            SyncCollection.entries,
            '33333333-3333-3333-3333-333333333333',
          ),
        ),
        isNull,
      );
    });
  });

  group('supabase backend', () {
    test('a valid SupabaseConfig resolves to a supabase backend', () async {
      await SyncMetadataStore(db)
          .setBackendSelection(backend: SyncBackendKind.supabase);
      final config = SupabaseConfig(
        projectUrl: Uri.parse('https://demo.supabase.co'),
        anonKey: 'anon-key',
      );

      final coordinator = await create(supabaseConfig: config);

      expect(coordinator.backend, isA<SupabaseSyncBackend>());
      expect(coordinator.status, const SyncIdle());
      expect(secrets.reads, isEmpty);
      expect(httpSpy.requests, 0);
      expect(store.calls, isEmpty);
    });
  });

  group('never enrolled', () {
    test('no backend selection yields a null backend, not a throw', () async {
      final coordinator = await create();

      expect(coordinator.backend, isNull);
      expect(coordinator.status, const SyncIdle());
    });
  });

  group('wiring invariant', () {
    test(
      'distinct buses throw SyncCoordinatorWiringException before any I/O',
      () async {
        final otherBus = EventBus();
        final mismatchedLedger = Ledger(bus: otherBus);
        addTearDown(() async {
          await otherBus.dispose();
          mismatchedLedger.dispose();
        });
        await SyncMetadataStore(db).setBackendSelection(
          backend: SyncBackendKind.custom,
          endpoint: 'https://sync.example.com',
        );

        await expectLater(
          SyncCoordinator.create(
            database: db,
            ledger: mismatchedLedger,
            persistenceProcessor: processor,
            httpClient: httpSpy,
            secretStore: secrets,
          ),
          throwsA(isA<SyncCoordinatorWiringException>()),
        );
        expect(secrets.reads, isEmpty);
        expect(httpSpy.requests, 0);
        expect(store.calls, isEmpty);
        expect(store.isStarted, isFalse);
      },
    );

    test('the wiring failure names the mismatch without internals', () {
      expect(
        const SyncCoordinatorWiringException().toString(),
        contains('bus'),
      );
    });
  });

  group('scoped E2E key access', () {
    test(
      'the E2E key is read lazily through the engine, not at create',
      () async {
        final coordinator = await create();
        expect(secrets.reads, isEmpty);

        await secrets.write(syncE2EKeySecretKey, _encodeKey(_freshKey()));
        final result = await coordinator.engine.reconcile(
          const <SyncEnvelope>[],
        );

        expect(result.changes, isEmpty);
        expect(secrets.reads, [syncE2EKeySecretKey]);
      },
    );

    test('a missing E2E key surfaces through the engine accessor', () async {
      final coordinator = await create();

      await expectLater(
        coordinator.engine.reconcile(const <SyncEnvelope>[]),
        throwsA(isA<SyncE2EKeyUnavailableException>()),
      );
    });
  });

  group('device identity', () {
    test('the engine userID equals deviceID for the same database', () async {
      final coordinator = await create();

      expect(coordinator.engine.userID, await deviceID(db));
    });
  });

  group('status', () {
    test('status is idle immediately after create and stays idle', () async {
      final coordinator = await create();

      expect(coordinator.status, const SyncIdle());
      expect(coordinator.status, const SyncIdle());
      expect(coordinator.status.hashCode, const SyncIdle().hashCode);
    });
  });

  group('public API shape', () {
    test('exposed collaborators are engine-scoped values, never secrets or '
        'credentials', () async {
      final coordinator = await create();

      expect(coordinator.engine, isA<SyncEngine>());
      expect(coordinator.versionSource, isA<CachedCollectionVersionSource>());
      expect(coordinator.metadataStore, isA<SyncMetadataStore>());
      expect(coordinator.status, isA<SyncStatus>());
    });
  });

  group('injected collaborators untouched', () {
    test(
      'construction never starts the processor nor mutates the ledger',
      () async {
        await SyncMetadataStore(db).setBackendSelection(
          backend: SyncBackendKind.custom,
          endpoint: 'https://sync.example.com',
        );

        final coordinator = await create();

        expect(store.calls, isEmpty);
        expect(store.isStarted, isFalse);
        expect(store.enqueuedBatches, isEmpty);
        expect(identical(coordinator.ledger, ledger), isTrue);
        expect(identical(coordinator.persistenceProcessor, processor), isTrue);
      },
    );
  });

  group('processPullPage: duplicate/dominated pages (TS1)', () {
    test('equal vectors commit watermark and acknowledgement, publish and '
        'enqueue nothing', () async {
      const rowID = '11111111-1111-1111-1111-111111111111';
      final key = _freshKey();
      final vector = VersionVector(<String, int>{'deva': 1});
      final envelope = await _pullEnvelope(
        key: key,
        rowID: rowID,
        version: vector,
        change: UpsertEntry(_pullTestEntry(rowID)),
      );
      final backend = _FakeSyncBackend(
        pages: {
          SyncCollection.entries: _pullPage(<SyncEnvelope>[
            envelope,
          ], 'cursor-1'),
        },
      );
      final staging = InMemorySyncStagingStore();
      final versions = InMemorySyncVersionSource(<SyncRowID, RowVersion>{
        SyncRowID.of(SyncCollection.entries, rowID): RowVersion(
          versionVector: vector,
          lifecycle: SiblingLifecycle.live,
        ),
      });
      final coordinator = await pullCoordinator(
        backend: backend,
        versionSource: versions,
        staging: staging,
        e2eKey: key,
      );

      final publications = await collectPublications(
        () => coordinator.processPullPage(SyncCollection.entries),
      );

      expect(backend.pulls.single.cursor, isNull);
      await expectDuplicatePageCommit(
        coordinator,
        backend,
        'cursor-1',
        publications,
      );
      expect(staging.pendingConflicts, isEmpty);
    });

    test(
      'strictly dominated vectors commit watermark and acknowledgement',
      () async {
        const rowID = '22222222-2222-2222-2222-222222222222';
        final key = _freshKey();
        final stored = VersionVector(<String, int>{'deva': 2});
        final pulled = VersionVector(<String, int>{'deva': 1});
        final envelope = await _pullEnvelope(
          key: key,
          rowID: rowID,
          version: pulled,
          change: UpsertEntry(_pullTestEntry(rowID)),
        );
        final backend = _FakeSyncBackend(
          pages: {
            SyncCollection.entries: _pullPage(<SyncEnvelope>[
              envelope,
            ], 'cursor-2'),
          },
        );
        final staging = InMemorySyncStagingStore();
        final versions = InMemorySyncVersionSource(<SyncRowID, RowVersion>{
          SyncRowID.of(SyncCollection.entries, rowID): RowVersion(
            versionVector: stored,
            lifecycle: SiblingLifecycle.live,
          ),
        });
        final coordinator = await pullCoordinator(
          backend: backend,
          versionSource: versions,
          staging: staging,
          e2eKey: key,
        );

        final publications = await collectPublications(
          () => coordinator.processPullPage(SyncCollection.entries),
        );

        await expectDuplicatePageCommit(
          coordinator,
          backend,
          'cursor-2',
          publications,
        );
        expect(staging.pendingConflicts, isEmpty);
      },
    );

    test('an empty page still commits watermark and acknowledgement', () async {
      final key = _freshKey();
      final backend = _FakeSyncBackend(
        pages: {
          SyncCollection.entries: _pullPage(const <SyncEnvelope>[], 'cursor-3'),
        },
      );
      final staging = InMemorySyncStagingStore();
      final coordinator = await pullCoordinator(
        backend: backend,
        versionSource: InMemorySyncVersionSource(),
        staging: staging,
        e2eKey: key,
      );

      final publications = await collectPublications(
        () => coordinator.processPullPage(SyncCollection.entries),
      );

      await expectDuplicatePageCommit(
        coordinator,
        backend,
        'cursor-3',
        publications,
      );
    });

    test(
      'the coordinator refreshes the cached source before classifying',
      () async {
        const rowID = '44444444-4444-4444-4444-444444444444';
        final key = _freshKey();
        final vector = VersionVector(<String, int>{'deva': 1});
        final envelope = await _pullEnvelope(
          key: key,
          rowID: rowID,
          version: vector,
          change: UpsertEntry(_pullTestEntry(rowID)),
        );
        final backend = _FakeSyncBackend(
          pages: {
            SyncCollection.entries: _pullPage(<SyncEnvelope>[
              envelope,
            ], 'cursor-4'),
          },
        );
        final reader = InMemoryCollectionVersionReader();
        reader.upsert(
          SyncRowID.of(SyncCollection.entries, rowID),
          RowVersion(versionVector: vector, lifecycle: SiblingLifecycle.live),
        );
        final cached = CachedCollectionVersionSource(reader);
        expect(
          cached.readRowVersion(SyncRowID.of(SyncCollection.entries, rowID)),
          isNull,
        );
        final staging = InMemorySyncStagingStore();
        final coordinator = await pullCoordinator(
          backend: backend,
          versionSource: cached,
          staging: staging,
          e2eKey: key,
        );

        final publications = await collectPublications(
          () => coordinator.processPullPage(SyncCollection.entries),
        );

        await expectDuplicatePageCommit(
          coordinator,
          backend,
          'cursor-4',
          publications,
        );
      },
    );
  });

  group('processPullPage: direct-apply and fold-in pages', () {
    test(
      'a genuinely new row is direct-applied, verified, and acknowledged',
      () async {
        const holderID = 'aaaaaaaa-0000-1111-2222-333333333333';
        const rowID = '55555555-5555-5555-5555-555555555555';
        final key = _freshKey();
        final vector = VersionVector(<String, int>{'deva': 1});
        final envelope = await _pullEnvelope(
          key: key,
          rowID: rowID,
          version: vector,
          change: UpsertEntry(driftEntry(rowID, holderID, name: 'Remote')),
        );
        final backend = _FakeSyncBackend(
          pages: {
            SyncCollection.entries: _pullPage(<SyncEnvelope>[
              envelope,
            ], 'cursor-direct'),
          },
        );
        final setup = await driftSetup(backend: backend, e2eKey: key);
        final coordinator = setup.coordinator;
        await seedDriftHolder(holderID, coordinator.persistenceProcessor);

        final publications = await collectPublications(
          () => coordinator.processPullPage(SyncCollection.entries),
        );

        expect(publications, hasLength(1));
        expect(ledger.state.entries[rowID]?.name, 'Remote');
        expect(await coordinator.metadataStore.acknowledgedVectors(), {
          SyncRowID.of(SyncCollection.entries, rowID): vector,
        });
        final snapshot = await coordinator.metadataStore.snapshot();
        expect(snapshot.watermarks[SyncCollection.entries], 'cursor-direct');
        expect(
          await coordinator.metadataStore.pendingAcknowledgement(
            SyncCollection.entries,
          ),
          'cursor-direct',
        );
      },
    );

    test(
      'a remote-newer row wins fold-in and records its pulled vector',
      () async {
        const holderID = 'aaaaaaaa-0000-1111-2222-333333333333';
        const rowID = '66666666-6666-6666-6666-666666666666';
        final key = _freshKey();
        final backend = _FakeSyncBackend();
        final setup = await driftSetup(backend: backend, e2eKey: key);
        final coordinator = setup.coordinator;
        await seedDriftHolder(holderID, coordinator.persistenceProcessor);
        ledger.addEntry(driftEntry(rowID, holderID, name: 'Local'));
        await coordinator.persistenceProcessor.flush();
        final remoteVector = VersionVector(<String, int>{
          setup.device: 1,
          'remotedev': 1,
        });
        final envelope = await _pullEnvelope(
          key: key,
          rowID: rowID,
          version: remoteVector,
          change: UpsertEntry(driftEntry(rowID, holderID, name: 'Remote')),
        );
        backend.pages[SyncCollection.entries] = _pullPage(<SyncEnvelope>[
          envelope,
        ], 'cursor-newer');

        await coordinator.processPullPage(SyncCollection.entries);

        expect(ledger.state.entries[rowID]?.name, 'Remote');
        expect(await coordinator.metadataStore.acknowledgedVectors(), {
          SyncRowID.of(SyncCollection.entries, rowID): remoteVector,
        });
        final snapshot = await coordinator.metadataStore.snapshot();
        expect(snapshot.watermarks[SyncCollection.entries], 'cursor-newer');
      },
    );

    test('a concurrent local row folds into a staged conflict without being '
        'overwritten, and the page defers', () async {
      const holderID = 'aaaaaaaa-0000-1111-2222-333333333333';
      const rowID = '77777777-7777-7777-7777-777777777777';
      final key = _freshKey();
      final backend = _FakeSyncBackend();
      final setup = await driftSetup(backend: backend, e2eKey: key);
      final coordinator = setup.coordinator;
      await seedDriftHolder(holderID, coordinator.persistenceProcessor);
      ledger.addEntry(driftEntry(rowID, holderID, name: 'Local'));
      await coordinator.persistenceProcessor.flush();
      final envelope = await _pullEnvelope(
        key: key,
        rowID: rowID,
        version: VersionVector(<String, int>{'remotedev': 1}),
        change: UpsertEntry(driftEntry(rowID, holderID, name: 'Remote')),
      );
      backend.pages[SyncCollection.entries] = _pullPage(<SyncEnvelope>[
        envelope,
      ], 'cursor-concurrent');

      final publications = await collectPublications(
        () => coordinator.processPullPage(SyncCollection.entries),
      );

      expect(publications, isEmpty);
      expect(ledger.state.entries[rowID]?.name, 'Local');
      expect(setup.staging.pendingConflicts, hasLength(1));
      expect(
        setup.staging.pendingConflicts.single.row,
        SyncRowID.of(SyncCollection.entries, rowID),
      );
      final snapshot = await coordinator.metadataStore.snapshot();
      expect(snapshot.watermarks[SyncCollection.entries], isNull);
      expect(
        await coordinator.metadataStore.pendingAcknowledgement(
          SyncCollection.entries,
        ),
        isNull,
      );
      expect(await coordinator.metadataStore.acknowledgedVectors(), isEmpty);
    });

    test('a staging-only page still records watermark and pending '
        'acknowledgement', () async {
      const holderID = 'aaaaaaaa-0000-1111-2222-333333333333';
      const rowID = '88888888-8888-8888-8888-888888888888';
      final key = _freshKey();
      final first = await _pullEnvelope(
        key: key,
        rowID: rowID,
        version: VersionVector(<String, int>{'deva': 1}),
        change: UpsertEntry(driftEntry(rowID, holderID, name: 'First')),
      );
      final second = await _pullEnvelope(
        key: key,
        rowID: rowID,
        version: VersionVector(<String, int>{'devb': 1}),
        change: UpsertEntry(driftEntry(rowID, holderID, name: 'Second')),
      );
      final backend = _FakeSyncBackend(
        pages: {
          SyncCollection.entries: _pullPage(<SyncEnvelope>[
            first,
            second,
          ], 'cursor-staged'),
        },
      );
      final setup = await driftSetup(backend: backend, e2eKey: key);
      final coordinator = setup.coordinator;
      await seedDriftHolder(holderID, coordinator.persistenceProcessor);

      final publications = await collectPublications(
        () => coordinator.processPullPage(SyncCollection.entries),
      );

      expect(publications, isEmpty);
      expect(setup.staging.pendingConflicts, hasLength(1));
      final snapshot = await coordinator.metadataStore.snapshot();
      expect(snapshot.watermarks[SyncCollection.entries], 'cursor-staged');
      expect(
        await coordinator.metadataStore.pendingAcknowledgement(
          SyncCollection.entries,
        ),
        'cursor-staged',
      );
      expect(await coordinator.metadataStore.acknowledgedVectors(), isEmpty);
    });

    test('a failed pull throws without committing anything', () async {
      final key = _freshKey();
      final backend = _FakeSyncBackend(
        failure: const NetworkUnavailable<PullResponse>(message: 'down'),
      );
      final staging = InMemorySyncStagingStore();
      final coordinator = await pullCoordinator(
        backend: backend,
        versionSource: InMemorySyncVersionSource(),
        staging: staging,
        e2eKey: key,
      );

      await expectLater(
        coordinator.processPullPage(SyncCollection.entries),
        throwsA(isA<StateError>()),
      );
      final snapshot = await coordinator.metadataStore.snapshot();
      expect(snapshot.watermarks[SyncCollection.entries], isNull);
    });

    test('an envelope declaring a different collection throws without '
        'committing anything', () async {
      final key = _freshKey();
      final rowID = '11111111-1111-1111-1111-111111111111';
      final vector = VersionVector(<String, int>{'deva': 1});
      final wrongCollectionEnvelope = await _pullEnvelope(
        key: key,
        rowID: rowID,
        version: vector,
        collection: SyncCollection.categories,
      );
      final backend = _FakeSyncBackend(
        pages: {
          SyncCollection.entries: _pullPage(<SyncEnvelope>[
            wrongCollectionEnvelope,
          ], 'cursor-1'),
        },
      );
      final coordinator = await pullCoordinator(
        backend: backend,
        versionSource: InMemorySyncVersionSource(),
        staging: InMemorySyncStagingStore(),
        e2eKey: key,
      );

      await expectLater(
        coordinator.processPullPage(SyncCollection.entries),
        throwsA(isA<StateError>()),
      );
      final snapshot = await coordinator.metadataStore.snapshot();
      expect(snapshot.watermarks[SyncCollection.entries], isNull);
    });
  });

  group('processPullPage: races, retries, and deferral', () {
    test('a pending debounced local edit before fold-in is folded in, not '
        'overwritten', () async {
      const holderID = 'aaaaaaaa-0000-1111-2222-333333333333';
      const rowID = '99999999-9999-9999-9999-999999999999';
      final key = _freshKey();
      final envelope = await _pullEnvelope(
        key: key,
        rowID: rowID,
        version: VersionVector(<String, int>{'remotedev': 1}),
        change: UpsertEntry(driftEntry(rowID, holderID, name: 'Remote')),
      );
      final backend = _FakeSyncBackend(
        pages: {
          SyncCollection.entries: _pullPage(<SyncEnvelope>[
            envelope,
          ], 'cursor-pending'),
        },
      );
      _HookLedgerStore? hooked;
      final setup = await driftSetup(
        backend: backend,
        e2eKey: key,
        wrapStore: (inner) {
          hooked = _HookLedgerStore(inner);
          return hooked!;
        },
      );
      final coordinator = setup.coordinator;
      await seedDriftHolder(holderID, coordinator.persistenceProcessor);
      ledger.addEntry(driftEntry(rowID, holderID, name: 'Local'));
      hooked?.flushCalls = 0;

      await coordinator.processPullPage(SyncCollection.entries);

      expect(hooked?.flushCalls, 3);
      expect(ledger.state.entries[rowID]?.name, 'Local');
      expect(setup.staging.pendingConflicts, hasLength(1));
      final snapshot = await coordinator.metadataStore.snapshot();
      expect(snapshot.watermarks[SyncCollection.entries], isNull);
      expect(await coordinator.metadataStore.acknowledgedVectors(), isEmpty);
    });

    test(
      'a local edit during the persistence flush retries, then applies',
      () async {
        const holderID = 'aaaaaaaa-0000-1111-2222-333333333333';
        const rowID = '10101010-1010-1010-1010-101010101010';
        const intruderID = '20202020-2020-2020-2020-202020202020';
        final key = _freshKey();
        final vector = VersionVector(<String, int>{'deva': 1});
        final envelope = await _pullEnvelope(
          key: key,
          rowID: rowID,
          version: vector,
          change: UpsertEntry(driftEntry(rowID, holderID, name: 'Remote')),
        );
        final backend = _FakeSyncBackend(
          pages: {
            SyncCollection.entries: _pullPage(<SyncEnvelope>[
              envelope,
            ], 'cursor-flush-race'),
          },
        );
        _HookLedgerStore? hooked;
        final setup = await driftSetup(
          backend: backend,
          e2eKey: key,
          wrapStore: (inner) {
            hooked = _HookLedgerStore(inner);
            return hooked!;
          },
        );
        final coordinator = setup.coordinator;
        await seedDriftHolder(holderID, coordinator.persistenceProcessor);
        var hookRuns = 0;
        var intrusions = 0;
        hooked?.onFlushNow = () async {
          hookRuns += 1;
          if (hookRuns == 1) {
            intrusions += 1;
            ledger.addEntry(driftEntry(intruderID, holderID, name: 'Intruder'));
          }
        };

        await coordinator.processPullPage(SyncCollection.entries);

        expect(hookRuns, 3);
        expect(intrusions, 1);
        expect(ledger.state.entries[rowID]?.name, 'Remote');
        expect(ledger.state.entries[intruderID]?.name, 'Intruder');
        expect(await coordinator.metadataStore.acknowledgedVectors(), {
          SyncRowID.of(SyncCollection.entries, rowID): vector,
        });
        final snapshot = await coordinator.metadataStore.snapshot();
        expect(
          snapshot.watermarks[SyncCollection.entries],
          'cursor-flush-race',
        );
      },
    );

    test(
      'a local edit during the refresh await window retries, then applies',
      () async {
        const holderID = 'aaaaaaaa-0000-1111-2222-333333333333';
        const rowID = '30303030-3030-3030-3030-303030303030';
        const intruderID = '40404040-4040-4040-4040-404040404040';
        final key = _freshKey();
        final vector = VersionVector(<String, int>{'deva': 1});
        final envelope = await _pullEnvelope(
          key: key,
          rowID: rowID,
          version: vector,
          change: UpsertEntry(driftEntry(rowID, holderID, name: 'Remote')),
        );
        final backend = _FakeSyncBackend(
          pages: {
            SyncCollection.entries: _pullPage(<SyncEnvelope>[
              envelope,
            ], 'cursor-refresh-race'),
          },
        );
        final setup = await driftSetup(
          backend: backend,
          e2eKey: key,
          wrapVersions: (inner) => _HookVersionSource(inner),
        );
        final coordinator = setup.coordinator;
        await seedDriftHolder(holderID, coordinator.persistenceProcessor);
        final hooked = setup.effectiveVersions as _HookVersionSource;
        hooked.onRefresh = () async {
          ledger.addEntry(driftEntry(intruderID, holderID, name: 'Intruder'));
        };

        await coordinator.processPullPage(SyncCollection.entries);

        expect(hooked.refreshCalls, greaterThanOrEqualTo(2));
        expect(ledger.state.entries[rowID]?.name, 'Remote');
        expect(await coordinator.metadataStore.acknowledgedVectors(), {
          SyncRowID.of(SyncCollection.entries, rowID): vector,
        });
        final snapshot = await coordinator.metadataStore.snapshot();
        expect(
          snapshot.watermarks[SyncCollection.entries],
          'cursor-refresh-race',
        );
      },
    );

    test('a local edit after reconciliation but before apply retries, then '
        'applies', () async {
      const holderID = 'aaaaaaaa-0000-1111-2222-333333333333';
      const rowID = '50505050-5050-5050-5050-505050505050';
      const otherID = '60606060-6060-6060-6060-606060606060';
      const intruderID = '70707070-7070-7070-7070-707070707070';
      final key = _freshKey();
      Future<SyncEnvelope> envelopeFor(String id) => _pullEnvelope(
        key: key,
        rowID: id,
        version: VersionVector(<String, int>{'deva': 1}),
        change: UpsertEntry(driftEntry(id, holderID, name: 'Remote $id')),
      );
      final backend = _FakeSyncBackend(
        pages: {
          SyncCollection.entries: _pullPage(<SyncEnvelope>[
            await envelopeFor(rowID),
            await envelopeFor(otherID),
          ], 'cursor-reconcile-race'),
        },
      );
      final setup = await driftSetup(
        backend: backend,
        e2eKey: key,
        buildEngine:
            ({
              required String userID,
              required SyncE2EKeyAccessor accessor,
              required SyncStagingStore staging,
            }) => _HookEngine(
              userID: userID,
              keyAccessor: accessor,
              stagingStore: staging,
            ),
      );
      final coordinator = setup.coordinator;
      await seedDriftHolder(holderID, coordinator.persistenceProcessor);
      final engine = coordinator.engine as _HookEngine;
      engine.onFoldInReconcile = () async {
        ledger.addEntry(driftEntry(intruderID, holderID, name: 'Intruder'));
      };

      await coordinator.processPullPage(SyncCollection.entries);

      expect(ledger.state.entries[rowID]?.name, 'Remote $rowID');
      expect(ledger.state.entries[otherID]?.name, 'Remote $otherID');
      expect(await coordinator.metadataStore.acknowledgedVectors(), {
        SyncRowID.of(SyncCollection.entries, rowID): VersionVector(
          <String, int>{'deva': 1},
        ),
        SyncRowID.of(SyncCollection.entries, otherID): VersionVector(
          <String, int>{'deva': 1},
        ),
      });
      final snapshot = await coordinator.metadataStore.snapshot();
      expect(
        snapshot.watermarks[SyncCollection.entries],
        'cursor-reconcile-race',
      );
    });

    test(
      'repeated edits exhaust the retry budget and defer silently',
      () async {
        const holderID = 'aaaaaaaa-0000-1111-2222-333333333333';
        const rowID = '80808080-8080-8080-8080-808080808080';
        final key = _freshKey();
        final envelope = await _pullEnvelope(
          key: key,
          rowID: rowID,
          version: VersionVector(<String, int>{'deva': 1}),
          change: UpsertEntry(driftEntry(rowID, holderID, name: 'Remote')),
        );
        final backend = _FakeSyncBackend(
          pages: {
            SyncCollection.entries: _pullPage(<SyncEnvelope>[
              envelope,
            ], 'cursor-defer'),
          },
        );
        _HookLedgerStore? hooked;
        final setup = await driftSetup(
          backend: backend,
          e2eKey: key,
          wrapStore: (inner) {
            hooked = _HookLedgerStore(inner);
            return hooked!;
          },
        );
        final coordinator = setup.coordinator;
        await seedDriftHolder(holderID, coordinator.persistenceProcessor);
        hooked?.flushCalls = 0;
        var intrusions = 0;
        hooked?.onFlushNow = () async {
          intrusions += 1;
          ledger.addEntry(
            driftEntry(
              'intrusion-$intrusions-0000-0000-000000000000',
              holderID,
              name: 'Intruder $intrusions',
            ),
          );
        };

        await coordinator.processPullPage(SyncCollection.entries);

        expect(intrusions, 3);
        expect(hooked?.flushCalls, 3);
        expect(ledger.state.entries.containsKey(rowID), isFalse);
        final snapshot = await coordinator.metadataStore.snapshot();
        expect(snapshot.watermarks[SyncCollection.entries], isNull);
        expect(
          await coordinator.metadataStore.pendingAcknowledgement(
            SyncCollection.entries,
          ),
          isNull,
        );
        expect(await coordinator.metadataStore.acknowledgedVectors(), isEmpty);
      },
    );

    test('a direct-apply row created locally mid-attempt is never silently '
        'overwritten', () async {
      const holderID = 'aaaaaaaa-0000-1111-2222-333333333333';
      const rowID = '90909090-9090-9090-9090-909090909090';
      final key = _freshKey();
      final envelope = await _pullEnvelope(
        key: key,
        rowID: rowID,
        version: VersionVector(<String, int>{'remotedev': 1}),
        change: UpsertEntry(driftEntry(rowID, holderID, name: 'Remote')),
      );
      final backend = _FakeSyncBackend(
        pages: {
          SyncCollection.entries: _pullPage(<SyncEnvelope>[
            envelope,
          ], 'cursor-direct-race'),
        },
      );
      _HookLedgerStore? hooked;
      final setup = await driftSetup(
        backend: backend,
        e2eKey: key,
        wrapStore: (inner) {
          hooked = _HookLedgerStore(inner);
          return hooked!;
        },
      );
      final coordinator = setup.coordinator;
      await seedDriftHolder(holderID, coordinator.persistenceProcessor);
      hooked?.onFlushNow = () async {
        hooked?.onFlushNow = null;
        ledger.addEntry(driftEntry(rowID, holderID, name: 'Local'));
      };

      await coordinator.processPullPage(SyncCollection.entries);

      expect(ledger.state.entries[rowID]?.name, 'Local');
      expect(setup.staging.pendingConflicts, hasLength(1));
      final snapshot = await coordinator.metadataStore.snapshot();
      expect(snapshot.watermarks[SyncCollection.entries], isNull);
      expect(await coordinator.metadataStore.acknowledgedVectors(), isEmpty);
    });

    test('a Stage-4 exclusion races the whole attempt instead of committing '
        'a sibling', () async {
      const directID = 'c1c1c1c1-c1c1-c1c1-c1c1-c1c1c1c1c1c1';
      const driftID = 'd2d2d2d2-d2d2-d2d2-d2d2-d2d2d2d2d2d2';
      final key = _freshKey();
      final directVector = VersionVector(<String, int>{'deva': 1});
      final concurrentLocal = VersionVector(<String, int>{'localdev': 1});
      final pulledRemote = VersionVector(<String, int>{
        'localdev': 1,
        'remotedev': 1,
      });
      final driftedLocal = VersionVector(<String, int>{'localdev': 2});
      Future<SyncEnvelope> envelopeFor(String id, VersionVector version) =>
          _pullEnvelope(
            key: key,
            rowID: id,
            version: version,
            change: UpsertEntry(_pullTestEntry(id)),
          );
      final backend = _FakeSyncBackend(
        pages: {
          SyncCollection.entries: _pullPage(<SyncEnvelope>[
            await envelopeFor(directID, directVector),
            await envelopeFor(driftID, pulledRemote),
          ], 'cursor-stage4-race'),
        },
      );
      final versions = _CyclingVersionSource({
        SyncRowID.of(SyncCollection.entries, directID): const [null],
        SyncRowID.of(SyncCollection.entries, driftID): [
          RowVersion(
            versionVector: concurrentLocal,
            lifecycle: SiblingLifecycle.live,
          ),
          RowVersion(
            versionVector: concurrentLocal,
            lifecycle: SiblingLifecycle.live,
          ),
          RowVersion(
            versionVector: concurrentLocal,
            lifecycle: SiblingLifecycle.live,
          ),
          RowVersion(
            versionVector: driftedLocal,
            lifecycle: SiblingLifecycle.live,
          ),
        ],
      });
      final setup = await driftSetup(
        backend: backend,
        e2eKey: key,
        wrapVersions: (_) => versions,
      );
      final coordinator = setup.coordinator;
      await seedDriftHolder(
        'aaaaaaaa-0000-1111-2222-333333333333',
        coordinator.persistenceProcessor,
      );

      final publications = await collectPublications(
        () => coordinator.processPullPage(SyncCollection.entries),
      );

      expect(versions.refreshCalls, 6);
      expect(publications, isEmpty);
      expect(ledger.state.entries.containsKey(directID), isFalse);
      expect(ledger.state.entries.containsKey(driftID), isFalse);
      expect(setup.staging.pendingConflicts, isEmpty);
      final snapshot = await coordinator.metadataStore.snapshot();
      expect(snapshot.watermarks[SyncCollection.entries], isNull);
      expect(
        await coordinator.metadataStore.pendingAcknowledgement(
          SyncCollection.entries,
        ),
        isNull,
      );
      expect(await coordinator.metadataStore.acknowledgedVectors(), isEmpty);
    });
  });

  group('processPullPage: fold-in batch outcomes', () {
    test(
      'a local input that wins fold-in is neither applied nor acknowledged',
      () async {
        const rowID = 'a1a1a1a1-a1a1-a1a1-a1a1-a1a1a1a1a1a1';
        final key = _freshKey();
        final pulled = VersionVector(<String, int>{'remotedev': 1});
        final envelope = await _pullEnvelope(
          key: key,
          rowID: rowID,
          version: pulled,
          change: UpsertEntry(_pullTestEntry(rowID)),
        );
        final backend = _FakeSyncBackend(
          pages: {
            SyncCollection.entries: _pullPage(<SyncEnvelope>[
              envelope,
            ], 'cursor-local-wins'),
          },
        );
        final staging = InMemorySyncStagingStore();
        final versions = _ScriptedVersionSource(
          first: RowVersion(
            versionVector: VersionVector(<String, int>{'localdev': 1}),
            lifecycle: SiblingLifecycle.live,
          ),
          later: RowVersion(
            versionVector: VersionVector(<String, int>{
              'localdev': 1,
              'remotedev': 1,
            }),
            lifecycle: SiblingLifecycle.live,
          ),
        );
        final coordinator = await pullCoordinator(
          backend: backend,
          versionSource: versions,
          staging: staging,
          e2eKey: key,
        );

        final publications = await collectPublications(
          () => coordinator.processPullPage(SyncCollection.entries),
        );

        expect(publications, isEmpty);
        expect(staging.pendingConflicts, isEmpty);
        expect(await coordinator.metadataStore.acknowledgedVectors(), isEmpty);
        final snapshot = await coordinator.metadataStore.snapshot();
        expect(
          snapshot.watermarks[SyncCollection.entries],
          'cursor-local-wins',
        );
        expect(
          await coordinator.metadataStore.pendingAcknowledgement(
            SyncCollection.entries,
          ),
          'cursor-local-wins',
        );
      },
    );

    test('a mixed batch applies the winner and stages the conflict', () async {
      const holderID = 'aaaaaaaa-0000-1111-2222-333333333333';
      const directID = 'b2b2b2b2-b2b2-b2b2-b2b2-b2b2b2b2b2b2';
      const conflictID = 'c3c3c3c3-c3c3-c3c3-c3c3-c3c3c3c3c3c3';
      final key = _freshKey();
      final directVector = VersionVector(<String, int>{'deva': 1});
      final direct = await _pullEnvelope(
        key: key,
        rowID: directID,
        version: directVector,
        change: UpsertEntry(driftEntry(directID, holderID, name: 'Remote')),
      );
      final conflicted = await _pullEnvelope(
        key: key,
        rowID: conflictID,
        version: VersionVector(<String, int>{'remotedev': 1}),
        change: UpsertEntry(driftEntry(conflictID, holderID, name: 'Remote')),
      );
      final backend = _FakeSyncBackend(
        pages: {
          SyncCollection.entries: _pullPage(<SyncEnvelope>[
            direct,
            conflicted,
          ], 'cursor-mixed'),
        },
      );
      final setup = await driftSetup(backend: backend, e2eKey: key);
      final coordinator = setup.coordinator;
      await seedDriftHolder(holderID, coordinator.persistenceProcessor);
      ledger.addEntry(driftEntry(conflictID, holderID, name: 'Local'));
      await coordinator.persistenceProcessor.flush();

      await coordinator.processPullPage(SyncCollection.entries);

      expect(ledger.state.entries[directID]?.name, 'Remote');
      expect(ledger.state.entries[conflictID]?.name, 'Local');
      expect(await coordinator.metadataStore.acknowledgedVectors(), {
        SyncRowID.of(SyncCollection.entries, directID): directVector,
      });
      expect(setup.staging.pendingConflicts, hasLength(1));
      expect(
        setup.staging.pendingConflicts.single.row,
        SyncRowID.of(SyncCollection.entries, conflictID),
      );
      final snapshot = await coordinator.metadataStore.snapshot();
      expect(snapshot.watermarks[SyncCollection.entries], 'cursor-mixed');
    });

    test('a mixed page preserves conflict-free and staged siblings across '
        'reconstruction', () async {
      const holderID = 'aaaaaaaa-0000-1111-2222-333333333333';
      const conflictID = 'd4d4d4d4-d4d4-d4d4-d4d4-d4d4d4d4d4d4';
      const directID = 'e5e5e5e5-e5e5-e5e5-e5e5-e5e5e5e5e5e5';
      final key = _freshKey();
      final firstVector = VersionVector(<String, int>{'deva': 1});
      final secondVector = VersionVector(<String, int>{'devb': 1});
      final directVector = VersionVector(<String, int>{'devc': 1});
      final first = await _pullEnvelope(
        key: key,
        rowID: conflictID,
        version: firstVector,
        change: UpsertEntry(driftEntry(conflictID, holderID, name: 'First')),
      );
      final second = await _pullEnvelope(
        key: key,
        rowID: conflictID,
        version: secondVector,
        change: UpsertEntry(driftEntry(conflictID, holderID, name: 'Second')),
      );
      final direct = await _pullEnvelope(
        key: key,
        rowID: directID,
        version: directVector,
        change: UpsertEntry(driftEntry(directID, holderID, name: 'Remote')),
      );
      final backend = _FakeSyncBackend(
        pages: {
          SyncCollection.entries: _pullPage(<SyncEnvelope>[
            first,
            second,
            direct,
          ], 'cursor-reconstruct'),
        },
      );
      final setup = await driftSetup(backend: backend, e2eKey: key);
      final coordinator = setup.coordinator;
      await seedDriftHolder(holderID, coordinator.persistenceProcessor);

      await coordinator.processPullPage(SyncCollection.entries);

      final reloaded = await DriftSyncStagingStore.open(db);
      expect(reloaded.pendingConflicts, hasLength(1));
      final group = reloaded.pendingConflicts.single;
      expect(group.row, SyncRowID.of(SyncCollection.entries, conflictID));
      expect(
        group.siblings.map((sibling) => sibling.versionVector),
        containsAll([firstVector, secondVector]),
      );
      expect(ledger.state.entries[directID]?.name, 'Remote');
      expect(await coordinator.metadataStore.acknowledgedVectors(), {
        SyncRowID.of(SyncCollection.entries, directID): directVector,
      });
      final snapshot = await coordinator.metadataStore.snapshot();
      expect(snapshot.watermarks[SyncCollection.entries], 'cursor-reconstruct');
    });
  });

  group('processPullPage: durability gates', () {
    test('a persistence barrier failure aborts metadata advancement', () async {
      const holderID = 'aaaaaaaa-0000-1111-2222-333333333333';
      const rowID = 'f6f6f6f6-f6f6-f6f6-f6f6-f6f6f6f6f6f6';
      final key = _freshKey();
      final envelope = await _pullEnvelope(
        key: key,
        rowID: rowID,
        version: VersionVector(<String, int>{'deva': 1}),
        change: UpsertEntry(driftEntry(rowID, holderID, name: 'Remote')),
      );
      final backend = _FakeSyncBackend(
        pages: {
          SyncCollection.entries: _pullPage(<SyncEnvelope>[
            envelope,
          ], 'cursor-barrier'),
        },
      );
      _HookLedgerStore? hooked;
      final setup = await driftSetup(
        backend: backend,
        e2eKey: key,
        wrapStore: (inner) {
          hooked = _HookLedgerStore(inner);
          return hooked!;
        },
      );
      final coordinator = setup.coordinator;
      await seedDriftHolder(holderID, coordinator.persistenceProcessor);
      hooked?.onFlushNow = () => throw PersistenceBarrierFailure(
        'injected barrier failure for the coordinator gate test',
      );

      await coordinator.processPullPage(SyncCollection.entries);

      final snapshot = await coordinator.metadataStore.snapshot();
      expect(snapshot.watermarks[SyncCollection.entries], isNull);
      expect(
        await coordinator.metadataStore.pendingAcknowledgement(
          SyncCollection.entries,
        ),
        isNull,
      );
      expect(await coordinator.metadataStore.acknowledgedVectors(), isEmpty);
      expect(ledger.state.entries.containsKey(rowID), isFalse);
    });

    test(
      'a mid-reconcile failure still leaves earlier staging durable',
      () async {
        const holderID = 'aaaaaaaa-0000-1111-2222-333333333333';
        const conflictID = 'a7a7a7a7-a7a7-a7a7-a7a7-a7a7a7a7a7a7';
        const poisonedID = 'b8b8b8b8-b8b8-b8b8-b8b8-b8b8b8b8b8b8';
        final key = _freshKey();
        final first = await _pullEnvelope(
          key: key,
          rowID: conflictID,
          version: VersionVector(<String, int>{'deva': 1}),
          change: UpsertEntry(driftEntry(conflictID, holderID, name: 'First')),
        );
        final second = await _pullEnvelope(
          key: key,
          rowID: conflictID,
          version: VersionVector(<String, int>{'devb': 1}),
          change: UpsertEntry(driftEntry(conflictID, holderID, name: 'Second')),
        );
        final poisonedVector = VersionVector(<String, int>{'devc': 1});
        final poisonedFirst = await _pullEnvelope(
          key: key,
          rowID: poisonedID,
          version: poisonedVector,
          change: UpsertEntry(
            driftEntry(poisonedID, holderID, name: 'Poisoned one'),
          ),
        );
        final poisonedSecond = await _pullEnvelope(
          key: key,
          rowID: poisonedID,
          version: poisonedVector,
          change: UpsertEntry(
            driftEntry(poisonedID, holderID, name: 'Poisoned two'),
          ),
        );
        final backend = _FakeSyncBackend(
          pages: {
            SyncCollection.entries: _pullPage(<SyncEnvelope>[
              first,
              second,
              poisonedFirst,
              poisonedSecond,
            ], 'cursor-corrupt'),
          },
        );
        final setup = await driftSetup(backend: backend, e2eKey: key);
        final coordinator = setup.coordinator;
        await seedDriftHolder(holderID, coordinator.persistenceProcessor);

        await expectLater(
          coordinator.processPullPage(SyncCollection.entries),
          throwsA(isA<SyncPayloadIdentityError>()),
        );

        final snapshot = await coordinator.metadataStore.snapshot();
        expect(snapshot.watermarks[SyncCollection.entries], isNull);
        expect(
          await coordinator.metadataStore.pendingAcknowledgement(
            SyncCollection.entries,
          ),
          isNull,
        );
        final reloaded = await DriftSyncStagingStore.open(db);
        expect(reloaded.pendingConflicts, hasLength(1));
        expect(
          reloaded.pendingConflicts.single.row,
          SyncRowID.of(SyncCollection.entries, conflictID),
        );
      },
    );

    test('a staging-flush failure propagates and blocks metadata', () async {
      final key = _freshKey();
      final backend = _FakeSyncBackend(
        pages: {
          SyncCollection.entries: _pullPage(const <SyncEnvelope>[], 'cursor-9'),
        },
      );
      final coordinator = await pullCoordinator(
        backend: backend,
        versionSource: InMemorySyncVersionSource(),
        staging: _FailingFlushStaging(InMemorySyncStagingStore()),
        e2eKey: key,
      );

      await expectLater(
        coordinator.processPullPage(SyncCollection.entries),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('staging flush failed'),
          ),
        ),
      );
      final snapshot = await coordinator.metadataStore.snapshot();
      expect(snapshot.watermarks[SyncCollection.entries], isNull);
      expect(
        await coordinator.metadataStore.pendingAcknowledgement(
          SyncCollection.entries,
        ),
        isNull,
      );
    });

    test('a readback verification failure blocks the whole batch', () async {
      const holderID = 'aaaaaaaa-0000-1111-2222-333333333333';
      const passingID = 'c9c9c9c9-c9c9-c9c9-c9c9-c9c9c9c9c9c9';
      const missingID = 'd0d0d0d0-d0d0-d0d0-d0d0-d0d0d0d0d0d0';
      final key = _freshKey();
      final passingVector = VersionVector(<String, int>{'deva': 1});
      final missingVector = VersionVector(<String, int>{'devb': 1});
      Future<SyncEnvelope> envelopeFor(String id, VersionVector vector) =>
          _pullEnvelope(
            key: key,
            rowID: id,
            version: vector,
            change: UpsertEntry(_pullTestEntry(id)),
          );
      final backend = _FakeSyncBackend(
        pages: {
          SyncCollection.entries: _pullPage(<SyncEnvelope>[
            await envelopeFor(passingID, passingVector),
            await envelopeFor(missingID, missingVector),
          ], 'cursor-verify'),
        },
      );
      final staging = InMemorySyncStagingStore();
      final reader = _MapReader(<SyncRowID, RowVersion>{
        SyncRowID.of(SyncCollection.entries, passingID): RowVersion(
          versionVector: passingVector,
          lifecycle: SiblingLifecycle.live,
        ),
      });
      final coordinator = await pullCoordinator(
        backend: backend,
        versionSource: InMemorySyncVersionSource(),
        staging: staging,
        e2eKey: key,
        reader: reader,
      );
      ledger.addAccount(
        Account(id: holderID, name: 'holder', type: AccountType.cash),
      );

      await coordinator.processPullPage(SyncCollection.entries);

      expect(ledger.state.entries.containsKey(passingID), isTrue);
      expect(ledger.state.entries.containsKey(missingID), isTrue);
      final snapshot = await coordinator.metadataStore.snapshot();
      expect(snapshot.watermarks[SyncCollection.entries], isNull);
      expect(
        await coordinator.metadataStore.pendingAcknowledgement(
          SyncCollection.entries,
        ),
        isNull,
      );
      expect(await coordinator.metadataStore.acknowledgedVectors(), isEmpty);
    });

    test('a throwing lock holder does not block the next pull for the same '
        'collection', () async {
      final key = _freshKey();
      final backend = _FakeSyncBackend(
        failure: const NetworkUnavailable<PullResponse>(message: 'down'),
      );
      final coordinator = await pullCoordinator(
        backend: backend,
        versionSource: InMemorySyncVersionSource(),
        staging: InMemorySyncStagingStore(),
        e2eKey: key,
      );

      await expectLater(
        coordinator.processPullPage(SyncCollection.entries),
        throwsA(isA<StateError>()),
      );

      backend.failure = null;
      backend.pages[SyncCollection.entries] = _pullPage(
        const <SyncEnvelope>[],
        'cursor-after-throw',
      );
      await coordinator.processPullPage(SyncCollection.entries);

      final snapshot = await coordinator.metadataStore.snapshot();
      expect(snapshot.watermarks[SyncCollection.entries], 'cursor-after-throw');
    });
  });

  group('recoverPendingAcknowledgements (TS5)', () {
    test(
      'a pending acknowledgement is retried and cleared on success',
      () async {
        final backend = _FakeSyncBackend();
        final coordinator = await pullCoordinator(
          backend: backend,
          versionSource: InMemorySyncVersionSource(),
          staging: InMemorySyncStagingStore(),
          e2eKey: _freshKey(),
        );
        await coordinator.metadataStore.setPendingAcknowledgement(
          SyncCollection.entries,
          'cursor-1',
        );

        await coordinator.recoverPendingAcknowledgements();

        expect(backend.acknowledges, hasLength(1));
        expect(backend.acknowledges.single.collection, SyncCollection.entries);
        expect(backend.acknowledges.single.checkpoint, 'cursor-1');
        expect(
          await coordinator.metadataStore.pendingAcknowledgement(
            SyncCollection.entries,
          ),
          isNull,
        );
      },
    );

    test('a failure leaves the pending row durable and retries on the next '
        'invocation', () async {
      final backend = _FakeSyncBackend(
        acknowledgeOutcomes: {
          SyncCollection.entries: const NetworkUnavailable<AcknowledgeResponse>(
            message: 'down',
          ),
        },
      );
      final coordinator = await pullCoordinator(
        backend: backend,
        versionSource: InMemorySyncVersionSource(),
        staging: InMemorySyncStagingStore(),
        e2eKey: _freshKey(),
      );
      await coordinator.metadataStore.setPendingAcknowledgement(
        SyncCollection.entries,
        'cursor-1',
      );

      await coordinator.recoverPendingAcknowledgements();

      expect(backend.acknowledges, hasLength(1));
      expect(
        await coordinator.metadataStore.pendingAcknowledgement(
          SyncCollection.entries,
        ),
        'cursor-1',
      );

      await coordinator.recoverPendingAcknowledgements();

      expect(backend.acknowledges, hasLength(2));
      expect(
        await coordinator.metadataStore.pendingAcknowledgement(
          SyncCollection.entries,
        ),
        'cursor-1',
      );
    });

    test('no pending acknowledgement means zero acknowledge calls', () async {
      final backend = _FakeSyncBackend();
      final coordinator = await pullCoordinator(
        backend: backend,
        versionSource: InMemorySyncVersionSource(),
        staging: InMemorySyncStagingStore(),
        e2eKey: _freshKey(),
      );

      await coordinator.recoverPendingAcknowledgements();

      expect(backend.acknowledges, isEmpty);
    });

    test('a mixed outcome clears only the succeeding collection', () async {
      final backend = _FakeSyncBackend(
        acknowledgeOutcomes: {
          SyncCollection.categories:
              const NetworkUnavailable<AcknowledgeResponse>(message: 'down'),
        },
      );
      final coordinator = await pullCoordinator(
        backend: backend,
        versionSource: InMemorySyncVersionSource(),
        staging: InMemorySyncStagingStore(),
        e2eKey: _freshKey(),
      );
      await coordinator.metadataStore.setPendingAcknowledgement(
        SyncCollection.entries,
        'cursor-entries',
      );
      await coordinator.metadataStore.setPendingAcknowledgement(
        SyncCollection.categories,
        'cursor-categories',
      );

      await coordinator.recoverPendingAcknowledgements();

      expect(backend.acknowledges, hasLength(2));
      expect(
        backend.acknowledges.map((request) => request.collection),
        containsAll([SyncCollection.entries, SyncCollection.categories]),
      );
      expect(
        await coordinator.metadataStore.pendingAcknowledgement(
          SyncCollection.entries,
        ),
        isNull,
      );
      expect(
        await coordinator.metadataStore.pendingAcknowledgement(
          SyncCollection.categories,
        ),
        'cursor-categories',
      );
    });

    test('acknowledgement waits while a conflict in the collection is '
        'unresolved', () async {
      const rowID = 'e1e1e1e1-e1e1-e1e1-e1e1-e1e1e1e1e1e1';
      final key = _freshKey();
      final first = await _pullEnvelope(
        key: key,
        rowID: rowID,
        version: VersionVector(<String, int>{'deva': 1}),
        change: UpsertEntry(_pullTestEntry(rowID)),
      );
      final second = await _pullEnvelope(
        key: key,
        rowID: rowID,
        version: VersionVector(<String, int>{'devb': 1}),
        change: UpsertEntry(_pullTestEntry(rowID)),
      );
      final backend = _FakeSyncBackend(
        pages: {
          SyncCollection.entries: _pullPage(<SyncEnvelope>[
            first,
            second,
          ], 'cursor-conflict'),
        },
      );
      final staging = InMemorySyncStagingStore();
      final coordinator = await pullCoordinator(
        backend: backend,
        versionSource: InMemorySyncVersionSource(),
        staging: staging,
        e2eKey: key,
      );
      await coordinator.processPullPage(SyncCollection.entries);
      expect(staging.pendingConflicts, hasLength(1));
      await coordinator.metadataStore.setPendingAcknowledgement(
        SyncCollection.categories,
        'cursor-categories',
      );

      await coordinator.recoverPendingAcknowledgements();

      expect(
        backend.acknowledges.map((request) => request.collection),
        contains(SyncCollection.categories),
      );
      expect(
        backend.acknowledges.where(
          (request) => request.collection == SyncCollection.entries,
        ),
        isEmpty,
      );
      expect(
        await coordinator.metadataStore.pendingAcknowledgement(
          SyncCollection.entries,
        ),
        'cursor-conflict',
      );
      expect(
        await coordinator.metadataStore.pendingAcknowledgement(
          SyncCollection.categories,
        ),
        isNull,
      );

      staging.resolve(staging.pendingConflicts.single);
      await coordinator.recoverPendingAcknowledgements();

      expect(
        backend.acknowledges.map((request) => request.collection),
        contains(SyncCollection.entries),
      );
      expect(
        await coordinator.metadataStore.pendingAcknowledgement(
          SyncCollection.entries,
        ),
        isNull,
      );
    });

    test('a success for a stale checkpoint does not clear a newer pending '
        'checkpoint recorded for the same collection', () async {
      final backend = _FakeSyncBackend();
      final coordinator = await pullCoordinator(
        backend: backend,
        versionSource: InMemorySyncVersionSource(),
        staging: InMemorySyncStagingStore(),
        e2eKey: _freshKey(),
      );
      await coordinator.metadataStore.setPendingAcknowledgement(
        SyncCollection.entries,
        'cursor-old',
      );

      await coordinator.metadataStore.setPendingAcknowledgement(
        SyncCollection.entries,
        'cursor-new',
      );
      await coordinator.metadataStore.clearPendingAcknowledgementIfMatches(
        SyncCollection.entries,
        'cursor-old',
      );

      expect(
        await coordinator.metadataStore.pendingAcknowledgement(
          SyncCollection.entries,
        ),
        'cursor-new',
      );
    });
  });

  group('pushCollection: write gate (TS4)', () {
    test('a closed gate throws StateError before any backend call', () async {
      final setup = await pushSetup(enableWrites: false);
      await setup.seedRow(
        '11111111-1111-1111-1111-111111111111',
        VersionVector(<String, int>{'dev': 1}),
      );

      await expectLater(
        setup.coordinator.pushCollection(SyncCollection.entries),
        throwsA(isA<StateError>()),
      );
      expect(setup.backend.pushes, isEmpty);
      expect(setup.backend.acknowledges, isEmpty);
      expect(
        await setup.coordinator.metadataStore.acknowledgedVectors(),
        isEmpty,
      );
    });

    test('an open gate submits the candidate and retires its vector', () async {
      final setup = await pushSetup();
      setup.backend.onPush = _appliedPush;
      const rowID = '22222222-2222-2222-2222-222222222222';
      final stored = VersionVector(<String, int>{'dev': 1});
      await setup.seedRow(rowID, stored);

      final result = await setup.coordinator.pushCollection(
        SyncCollection.entries,
      );

      expect(setup.backend.pushes, hasLength(1));
      expect(result, isA<PushFullyAcknowledged>());
      expect((result as PushFullyAcknowledged).acknowledged, {
        SyncRowID.of(SyncCollection.entries, rowID),
      });
      expect(await setup.coordinator.metadataStore.acknowledgedVectors(), {
        SyncRowID.of(SyncCollection.entries, rowID): stored,
      });
    });
  });

  group('pushCollection: candidate derivation (TS1)', () {
    test('a newer stored vector is pushed', () async {
      final setup = await pushSetup();
      setup.backend.onPush = _appliedPush;
      const rowID = '33333333-3333-3333-3333-333333333333';
      final stored = VersionVector(<String, int>{'dev': 2});
      await setup.seedRow(
        rowID,
        stored,
        acknowledged: VersionVector(<String, int>{'dev': 1}),
      );

      final result = await setup.coordinator.pushCollection(
        SyncCollection.entries,
      );

      expect(setup.backend.pushes, hasLength(1));
      expect(result, isA<PushFullyAcknowledged>());
      expect(
        setup.backend.pushes.single.envelopes.map((envelope) => envelope.rowID),
        [normalizedID(rowID)],
      );
      expect(await setup.coordinator.metadataStore.acknowledgedVectors(), {
        SyncRowID.of(SyncCollection.entries, rowID): stored,
      });
    });

    test('an equal stored vector is dominated and never submitted', () async {
      final setup = await pushSetup();
      setup.backend.onPush = _appliedPush;
      final vector = VersionVector(<String, int>{'dev': 1});
      await setup.seedRow(
        '44444444-4444-4444-4444-444444444444',
        vector,
        acknowledged: vector,
      );

      final result = await setup.coordinator.pushCollection(
        SyncCollection.entries,
      );

      expect(result, isA<PushNoop>());
      expect(setup.backend.pushes, isEmpty);
      expect(await setup.coordinator.metadataStore.acknowledgedVectors(), {
        SyncRowID.of(
          SyncCollection.entries,
          '44444444-4444-4444-4444-444444444444',
        ): vector,
      });
    });

    test('a strictly dominated stored vector is never submitted', () async {
      final setup = await pushSetup();
      setup.backend.onPush = _appliedPush;
      await setup.seedRow(
        '55555555-5555-5555-5555-555555555555',
        VersionVector(<String, int>{'dev': 1}),
        acknowledged: VersionVector(<String, int>{'dev': 1, 'other': 1}),
      );

      final result = await setup.coordinator.pushCollection(
        SyncCollection.entries,
      );

      expect(result, isA<PushNoop>());
      expect(setup.backend.pushes, isEmpty);
    });

    test('a row without acknowledgement is eligible', () async {
      final setup = await pushSetup();
      setup.backend.onPush = _appliedPush;
      const rowID = '66666666-6666-6666-6666-666666666666';
      final stored = VersionVector(<String, int>{'dev': 1});
      await setup.seedRow(rowID, stored);

      final result = await setup.coordinator.pushCollection(
        SyncCollection.entries,
      );

      expect(result, isA<PushFullyAcknowledged>());
      expect(setup.backend.pushes, hasLength(1));
      expect(await setup.coordinator.metadataStore.acknowledgedVectors(), {
        SyncRowID.of(SyncCollection.entries, rowID): stored,
      });
    });

    test('only eligible rows are submitted', () async {
      final setup = await pushSetup();
      setup.backend.onPush = _appliedPush;
      const eligibleID = '77777777-7777-7777-7777-777777777777';
      const dominatedID = '88888888-8888-8888-8888-888888888888';
      final eligibleVector = VersionVector(<String, int>{'dev': 2});
      final dominatedVector = VersionVector(<String, int>{'dev': 1});
      await setup.seedRow(eligibleID, eligibleVector);
      await setup.seedRow(
        dominatedID,
        dominatedVector,
        acknowledged: dominatedVector,
      );

      final result = await setup.coordinator.pushCollection(
        SyncCollection.entries,
      );

      expect(result, isA<PushFullyAcknowledged>());
      expect(setup.backend.pushes, hasLength(1));
      expect(setup.backend.pushes.single.envelopes, hasLength(1));
      expect(
        setup.backend.pushes.single.envelopes.single.rowID,
        normalizedID(eligibleID),
      );
      expect(await setup.coordinator.metadataStore.acknowledgedVectors(), {
        SyncRowID.of(SyncCollection.entries, eligibleID): eligibleVector,
        SyncRowID.of(SyncCollection.entries, dominatedID): dominatedVector,
      });
    });

    test('an orphan tombstone pushes as a tombstone delete', () async {
      final setup = await pushSetup();
      setup.backend.onPush = _appliedPush;
      const rowID = '99999999-9999-9999-9999-999999999999';
      final stored = VersionVector(<String, int>{'dev': 1});
      await setup.seedRow(
        rowID,
        stored,
        inLedger: false,
        lifecycle: SiblingLifecycle.tombstone,
      );

      final result = await setup.coordinator.pushCollection(
        SyncCollection.entries,
      );

      expect(result, isA<PushFullyAcknowledged>());
      expect(setup.backend.pushes, hasLength(1));
      final envelope = setup.backend.pushes.single.envelopes.single;
      expect(envelope.lifecycle, SiblingLifecycle.tombstone);
      expect(await setup.coordinator.metadataStore.acknowledgedVectors(), {
        SyncRowID.of(SyncCollection.entries, rowID): stored,
      });
    });
  });

  group('pushCollection: snapshot consistency', () {
    test('a debounced edit not yet flushed pushes new content under the new '
        'vector', () async {
      const holderID = 'aaaaaaaa-0000-1111-2222-333333333333';
      const rowID = 'f1f1f1f1-f1f1-f1f1-f1f1-f1f1f1f1f1f1';
      final key = _freshKey();
      final backend = _FakeSyncBackend();
      backend.onPush = _appliedPush;
      final setup = await driftSetup(backend: backend, e2eKey: key);
      final coordinator = setup.coordinator;
      await seedDriftHolder(holderID, coordinator.persistenceProcessor);
      ledger.addEntry(driftEntry(rowID, holderID, name: 'Original'));
      await coordinator.persistenceProcessor.flush();
      await coordinator.metadataStore.enterReconciliationComplete();
      await coordinator.metadataStore.enterGateEnabled();
      ledger.updateEntry(driftEntry(rowID, holderID, name: 'Edited'));

      final result = await coordinator.pushCollection(SyncCollection.entries);

      expect(result, isA<PushFullyAcknowledged>());
      expect(backend.pushes, hasLength(1));
      expect(backend.pushes.single.envelopes, hasLength(1));
      final envelope = backend.pushes.single.envelopes.single;
      expect(envelope.rowID, normalizedID(rowID));
      final plaintext = await const SyncCipher().decrypt(
        key: key,
        ciphertext: envelope.ciphertext,
        aad: envelope.aadBytes(),
      );
      final change = const PayloadCodec().decodeChange(plaintext);
      expect(change, isA<UpsertEntry>());
      expect((change as UpsertEntry).entry.name, 'Edited');
      await coordinator.persistenceProcessor.flush();
      final durable = await DriftCollectionVersionReader(db)
          .readRowVersions(SyncCollection.entries);
      final row = SyncRowID.of(SyncCollection.entries, rowID);
      expect(envelope.versionVector, durable[row]!.versionVector);
      expect(
        envelope.siblingID,
        computeSiblingID(
          userID: setup.device,
          collection: SyncCollection.entries,
          rowID: normalizedID(rowID),
          versionVector: durable[row]!.versionVector,
        ),
      );
      expect(await coordinator.metadataStore.acknowledgedVectors(), {
        row: envelope.versionVector,
      });
    });
  });

  group('pushCollection: recovery-before-push ordering (TS2)', () {
    test('a pending acknowledgement is recovered and cleared before the push '
        'query', () async {
      final backend = _FakeSyncBackend();
      final setup = await pushSetup(backend: backend);
      backend.onPush = _appliedPush;
      await setup.seedRow(
        'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
        VersionVector(<String, int>{'dev': 1}),
      );
      await setup.coordinator.metadataStore.setPendingAcknowledgement(
        SyncCollection.entries,
        'cursor-1',
      );

      final result = await setup.coordinator.pushCollection(
        SyncCollection.entries,
      );

      expect(result, isA<PushFullyAcknowledged>());
      expect(backend.acknowledges, hasLength(1));
      expect(backend.acknowledges.single.checkpoint, 'cursor-1');
      expect(
        await setup.coordinator.metadataStore.pendingAcknowledgement(
          SyncCollection.entries,
        ),
        isNull,
      );
      expect(backend.pushes, hasLength(1));
    });

    test('the version cache refreshes before candidates are encoded', () async {
      final backend = _FakeSyncBackend();
      backend.onPush = _appliedPush;
      final reader = InMemoryCollectionVersionReader();
      final cached = CachedCollectionVersionSource(reader);
      final coordinator = await pullCoordinator(
        backend: backend,
        versionSource: cached,
        staging: InMemorySyncStagingStore(),
        e2eKey: _freshKey(),
        versionReader: reader,
      );
      await coordinator.metadataStore.enterReconciliationComplete();
      await coordinator.metadataStore.enterGateEnabled();
      const holderID = 'aaaaaaaa-0000-1111-2222-333333333333';
      const rowID = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
      ledger.addAccount(
        Account(id: holderID, name: 'holder', type: AccountType.cash),
      );
      ledger.addEntry(driftEntry(rowID, holderID));
      final row = SyncRowID.of(SyncCollection.entries, rowID);
      reader.upsert(
        row,
        RowVersion(
          versionVector: VersionVector(<String, int>{'dev': 1}),
          lifecycle: SiblingLifecycle.live,
        ),
      );
      expect(cached.readRowVersion(row), isNull);

      final result = await coordinator.pushCollection(SyncCollection.entries);

      expect(result, isA<PushFullyAcknowledged>());
      expect(backend.pushes, hasLength(1));
    });
  });

  group('pushCollection: recovery-not-cleared deferral (TS8)', () {
    test('a failed recovery defers silently with no push query', () async {
      final backend = _FakeSyncBackend(
        acknowledgeOutcomes: {
          SyncCollection.entries: const NetworkUnavailable<AcknowledgeResponse>(
            message: 'down',
          ),
        },
      );
      final setup = await pushSetup(backend: backend);
      backend.onPush = _appliedPush;
      await setup.seedRow(
        'cccccccc-cccc-cccc-cccc-cccccccccccc',
        VersionVector(<String, int>{'dev': 1}),
      );
      await setup.coordinator.metadataStore.setPendingAcknowledgement(
        SyncCollection.entries,
        'cursor-1',
      );

      final result = await setup.coordinator.pushCollection(
        SyncCollection.entries,
      );

      expect(result, isA<PushDeferred>());
      expect(backend.acknowledges, hasLength(1));
      expect(backend.pushes, isEmpty);
      expect(
        await setup.coordinator.metadataStore.pendingAcknowledgement(
          SyncCollection.entries,
        ),
        'cursor-1',
      );
      expect(
        await setup.coordinator.metadataStore.acknowledgedVectors(),
        isEmpty,
      );
    });

    test('a conflict-blocked pending acknowledgement defers until the conflict '
        'resolves', () async {
      const conflictID = 'dddddddd-dddd-dddd-dddd-dddddddddddd';
      final key = _freshKey();
      final first = await _pullEnvelope(
        key: key,
        rowID: conflictID,
        version: VersionVector(<String, int>{'deva': 1}),
        change: UpsertEntry(_pullTestEntry(conflictID)),
      );
      final second = await _pullEnvelope(
        key: key,
        rowID: conflictID,
        version: VersionVector(<String, int>{'devb': 1}),
        change: UpsertEntry(_pullTestEntry(conflictID)),
      );
      final backend = _FakeSyncBackend(
        pages: {
          SyncCollection.entries: _pullPage(<SyncEnvelope>[
            first,
            second,
          ], 'cursor-conflict'),
        },
      );
      final setup = await pushSetup(backend: backend);
      backend.onPush = _appliedPush;
      await setup.coordinator.processPullPage(SyncCollection.entries);
      expect(setup.staging.pendingConflicts, hasLength(1));
      const pushID = 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee';
      final stored = VersionVector(<String, int>{'dev': 1});
      await setup.seedRow(pushID, stored);

      final deferred = await setup.coordinator.pushCollection(
        SyncCollection.entries,
      );

      expect(deferred, isA<PushDeferred>());
      expect(backend.pushes, isEmpty);
      expect(
        await setup.coordinator.metadataStore.pendingAcknowledgement(
          SyncCollection.entries,
        ),
        'cursor-conflict',
      );

      setup.staging.resolve(setup.staging.pendingConflicts.single);
      final result = await setup.coordinator.pushCollection(
        SyncCollection.entries,
      );

      expect(result, isA<PushFullyAcknowledged>());
      expect(backend.pushes, hasLength(1));
      expect(
        await setup.coordinator.metadataStore.pendingAcknowledgement(
          SyncCollection.entries,
        ),
        isNull,
      );
      expect(await setup.coordinator.metadataStore.acknowledgedVectors(), {
        SyncRowID.of(SyncCollection.entries, pushID): stored,
      });
    });
  });

  group('pushCollection: response classification (TS3)', () {
    test(
      'applied commits the submitted vector, never the response frontier',
      () async {
        final setup = await pushSetup();
        const rowID = 'ffffffff-ffff-ffff-ffff-ffffffffffff';
        final stored = VersionVector(<String, int>{'dev': 1});
        setup.backend.onPush = (request) async => SyncSuccess<PushResponse>(
          _pushRowsResponse(
            request.envelopes,
            frontier: VersionVector(<String, int>{'server': 9}),
          ),
        );
        await setup.seedRow(rowID, stored);

        final result = await setup.coordinator.pushCollection(
          SyncCollection.entries,
        );

        expect(result, isA<PushFullyAcknowledged>());
        expect((result as PushFullyAcknowledged).acknowledged, {
          SyncRowID.of(SyncCollection.entries, rowID),
        });
        expect(await setup.coordinator.metadataStore.acknowledgedVectors(), {
          SyncRowID.of(SyncCollection.entries, rowID): stored,
        });
      },
    );

    test('already_present commits the submitted vector', () async {
      final setup = await pushSetup();
      const rowID = '10101010-1010-1010-1010-101010101010';
      final stored = VersionVector(<String, int>{'dev': 1});
      setup.backend.onPush = (request) async => SyncSuccess<PushResponse>(
        _pushRowsResponse(request.envelopes, status: 'already_present'),
      );
      await setup.seedRow(rowID, stored);

      final result = await setup.coordinator.pushCollection(
        SyncCollection.entries,
      );

      expect(result, isA<PushFullyAcknowledged>());
      expect(await setup.coordinator.metadataStore.acknowledgedVectors(), {
        SyncRowID.of(SyncCollection.entries, rowID): stored,
      });
    });

    test('rejected leaves the row eligible for the next push', () async {
      final setup = await pushSetup();
      setup.backend.onPush = (request) async => SyncSuccess<PushResponse>(
        _pushRowsResponse(request.envelopes, status: 'rejected'),
      );
      const rowID = '20202020-2020-2020-2020-202020202020';
      await setup.seedRow(rowID, VersionVector(<String, int>{'dev': 1}));

      final first = await setup.coordinator.pushCollection(
        SyncCollection.entries,
      );
      final second = await setup.coordinator.pushCollection(
        SyncCollection.entries,
      );

      expect(first, isA<PushUnresolvedRows>());
      expect((first as PushUnresolvedRows).unresolved, {
        SyncRowID.of(SyncCollection.entries, rowID),
      });
      expect(second, isA<PushUnresolvedRows>());
      expect(setup.backend.pushes, hasLength(2));
      expect(
        await setup.coordinator.metadataStore.acknowledgedVectors(),
        isEmpty,
      );
    });

    test('a sibling-ID mismatch commits nothing', () async {
      final setup = await pushSetup();
      setup.backend.onPush = (request) async {
        final envelope = request.envelopes.single;
        return SyncSuccess<PushResponse>(
          PushResponse(<String, Object?>{
            'rows': [
              <String, Object?>{
                'row_id': envelope.rowID,
                'collection': envelope.collection.wireName,
                'sibling_id': 'wrong-sibling',
                'status': 'applied',
                'version_vector': envelope.versionVector.toWireCounters(),
              },
            ],
          }),
        );
      };
      await setup.seedRow(
        '30303030-3030-3030-3030-303030303030',
        VersionVector(<String, int>{'dev': 1}),
      );

      final result = await setup.coordinator.pushCollection(
        SyncCollection.entries,
      );

      expect(result, isA<PushUnresolvedRows>());
      expect((result as PushUnresolvedRows).unresolved, {
        SyncRowID.of(
          SyncCollection.entries,
          '30303030-3030-3030-3030-303030303030',
        ),
      });
      expect(setup.backend.pushes, hasLength(1));
      expect(
        await setup.coordinator.metadataStore.acknowledgedVectors(),
        isEmpty,
      );
    });

    test('a missing response entry commits nothing without throwing', () async {
      final setup = await pushSetup();
      setup.backend.onPush = (request) async => SyncSuccess<PushResponse>(
        PushResponse(<String, Object?>{'rows': const <Object?>[]}),
      );
      await setup.seedRow(
        '40404040-4040-4040-4040-404040404040',
        VersionVector(<String, int>{'dev': 1}),
      );

      final result = await setup.coordinator.pushCollection(
        SyncCollection.entries,
      );

      expect(result, isA<PushUnresolvedRows>());
      expect((result as PushUnresolvedRows).unresolved, {
        SyncRowID.of(
          SyncCollection.entries,
          '40404040-4040-4040-4040-404040404040',
        ),
      });
      expect(setup.backend.pushes, hasLength(1));
      expect(
        await setup.coordinator.metadataStore.acknowledgedVectors(),
        isEmpty,
      );
    });

    test('a push failure throws StateError and writes nothing', () async {
      final setup = await pushSetup();
      setup.backend.onPush = (request) async =>
          const NetworkUnavailable<PushResponse>(message: 'down');
      await setup.seedRow(
        '50505050-5050-5050-5050-505050505050',
        VersionVector(<String, int>{'dev': 1}),
      );

      await expectLater(
        setup.coordinator.pushCollection(SyncCollection.entries),
        throwsA(isA<StateError>()),
      );
      expect(setup.backend.pushes, hasLength(1));
      expect(
        await setup.coordinator.metadataStore.acknowledgedVectors(),
        isEmpty,
      );
    });

    test('a mid-flight version change cannot move the commit off the submitted '
        'vector', () async {
      final setup = await pushSetup();
      const rowID = '60606060-6060-6060-6060-606060606060';
      final row = SyncRowID.of(SyncCollection.entries, rowID);
      final submitted = VersionVector(<String, int>{'dev': 1});
      final midFlight = VersionVector(<String, int>{'dev': 2});
      setup.backend.onPush = (request) async {
        setup.versions.upsert(
          row,
          RowVersion(
            versionVector: midFlight,
            lifecycle: SiblingLifecycle.live,
          ),
        );
        return SyncSuccess<PushResponse>(_pushRowsResponse(request.envelopes));
      };
      await setup.seedRow(rowID, submitted);

      final result = await setup.coordinator.pushCollection(
        SyncCollection.entries,
      );

      expect(result, isA<PushFullyAcknowledged>());
      expect(await setup.coordinator.metadataStore.acknowledgedVectors(), {
        row: submitted,
      });
    });

    test('a malformed response leaves every submitted row eligible', () async {
      final setup = await pushSetup();
      setup.backend.onPush = (request) async => SyncSuccess<PushResponse>(
        PushResponse(<String, Object?>{
          'rows': [
            <String, Object?>{
              'row_id': request.envelopes.single.rowID,
              'collection': request.envelopes.single.collection.wireName,
              'sibling_id': request.envelopes.single.siblingID,
            },
          ],
        }),
      );
      const rowID = 'b0b0b0b0-b0b0-b0b0-b0b0-b0b0b0b0b0b0';
      await setup.seedRow(rowID, VersionVector(<String, int>{'dev': 1}));

      final result = await setup.coordinator.pushCollection(
        SyncCollection.entries,
      );

      expect(result, isA<PushUnresolvedRows>());
      expect((result as PushUnresolvedRows).unresolved, {
        SyncRowID.of(SyncCollection.entries, rowID),
      });
      expect(setup.backend.pushes, hasLength(1));
      expect(
        await setup.coordinator.metadataStore.acknowledgedVectors(),
        isEmpty,
      );
    });
  });

  group('pushCollection: structured result', () {
    test(
      'no eligible candidates report PushNoop with no backend call',
      () async {
        final setup = await pushSetup();
        setup.backend.onPush = _appliedPush;

        final result = await setup.coordinator.pushCollection(
          SyncCollection.entries,
        );

        expect(result, isA<PushNoop>());
        expect(setup.backend.pushes, isEmpty);
      },
    );

    test(
      'an uncleared recovery reports PushDeferred with no push query',
      () async {
        final backend = _FakeSyncBackend(
          acknowledgeOutcomes: {
            SyncCollection.entries:
                const NetworkUnavailable<AcknowledgeResponse>(message: 'down'),
          },
        );
        final setup = await pushSetup(backend: backend);
        backend.onPush = _appliedPush;
        await setup.seedRow(
          'd1d1d1d1-d1d1-d1d1-d1d1-d1d1d1d1d1d1',
          VersionVector(<String, int>{'dev': 1}),
        );
        await setup.coordinator.metadataStore.setPendingAcknowledgement(
          SyncCollection.entries,
          'cursor-deferred',
        );

        final result = await setup.coordinator.pushCollection(
          SyncCollection.entries,
        );

        expect(result, isA<PushDeferred>());
        expect(backend.pushes, isEmpty);
        expect(
          await setup.coordinator.metadataStore.pendingAcknowledgement(
            SyncCollection.entries,
          ),
          'cursor-deferred',
        );
      },
    );

    test(
      'a recovery that clears then pushes reports PushFullyAcknowledged',
      () async {
        final backend = _FakeSyncBackend();
        final setup = await pushSetup(backend: backend);
        backend.onPush = _appliedPush;
        const rowID = 'd2d2d2d2-d2d2-d2d2-d2d2-d2d2d2d2d2d2';
        final stored = VersionVector(<String, int>{'dev': 1});
        await setup.seedRow(rowID, stored);
        await setup.coordinator.metadataStore.setPendingAcknowledgement(
          SyncCollection.entries,
          'cursor-cleared',
        );

        final result = await setup.coordinator.pushCollection(
          SyncCollection.entries,
        );

        expect(result, isA<PushFullyAcknowledged>());
        expect((result as PushFullyAcknowledged).acknowledged, {
          SyncRowID.of(SyncCollection.entries, rowID),
        });
        expect(
          await setup.coordinator.metadataStore.pendingAcknowledgement(
            SyncCollection.entries,
          ),
          isNull,
        );
        expect(backend.pushes, hasLength(1));
        expect(await setup.coordinator.metadataStore.acknowledgedVectors(), {
          SyncRowID.of(SyncCollection.entries, rowID): stored,
        });
      },
    );

    test('a partial-batch rejection reports PushUnresolvedRows with only the '
        'rejected row, which stays eligible', () async {
      final setup = await pushSetup();
      const appliedID = 'd3d3d3d3-d3d3-d3d3-d3d3-d3d3d3d3d3d3';
      const rejectedID = 'd4d4d4d4-d4d4-d4d4-d4d4-d4d4d4d4d4d4';
      final appliedVector = VersionVector(<String, int>{'dev': 1});
      final rejectedVector = VersionVector(<String, int>{'dev': 2});
      setup.backend.onPush = (request) async {
        expect(request.envelopes, hasLength(2));
        return SyncSuccess<PushResponse>(
          PushResponse(<String, Object?>{
            'rows': [
              for (final envelope in request.envelopes)
                <String, Object?>{
                  'row_id': envelope.rowID,
                  'collection': envelope.collection.wireName,
                  'sibling_id': envelope.siblingID,
                  'status': envelope.rowID == normalizedID(appliedID)
                      ? 'applied'
                      : 'rejected',
                  if (envelope.rowID == normalizedID(appliedID))
                    'version_vector': envelope.versionVector.toWireCounters(),
                },
            ],
          }),
        );
      };
      await setup.seedRow(appliedID, appliedVector);
      await setup.seedRow(rejectedID, rejectedVector);

      final result = await setup.coordinator.pushCollection(
        SyncCollection.entries,
      );

      expect(result, isA<PushUnresolvedRows>());
      expect((result as PushUnresolvedRows).unresolved, {
        SyncRowID.of(SyncCollection.entries, rejectedID),
      });
      expect(await setup.coordinator.metadataStore.acknowledgedVectors(), {
        SyncRowID.of(SyncCollection.entries, appliedID): appliedVector,
      });

      setup.backend.onPush = _appliedPush;
      final retry = await setup.coordinator.pushCollection(
        SyncCollection.entries,
      );

      expect(retry, isA<PushFullyAcknowledged>());
      expect(
        setup.backend.pushes.last.envelopes.single.rowID,
        normalizedID(rejectedID),
      );
      expect(await setup.coordinator.metadataStore.acknowledgedVectors(), {
        SyncRowID.of(SyncCollection.entries, appliedID): appliedVector,
        SyncRowID.of(SyncCollection.entries, rejectedID): rejectedVector,
      });
    });

    test(
      'a missing entry reports PushUnresolvedRows and stays eligible',
      () async {
        final setup = await pushSetup();
        setup.backend.onPush = (request) async => SyncSuccess<PushResponse>(
          PushResponse(<String, Object?>{'rows': const <Object?>[]}),
        );
        const rowID = 'd5d5d5d5-d5d5-d5d5-d5d5-d5d5d5d5d5d5';
        await setup.seedRow(rowID, VersionVector(<String, int>{'dev': 1}));

        final result = await setup.coordinator.pushCollection(
          SyncCollection.entries,
        );

        expect(result, isA<PushUnresolvedRows>());
        expect((result as PushUnresolvedRows).unresolved, {
          SyncRowID.of(SyncCollection.entries, rowID),
        });
        expect(
          await setup.coordinator.metadataStore.acknowledgedVectors(),
          isEmpty,
        );
      },
    );
  });

  group('pushCollection: lock interaction (TS5)', () {
    test(
      'overlapping pushes for one collection serialize without deadlock',
      () async {
        final setup = await pushSetup();
        setup.backend.onPush = (request) async => SyncSuccess<PushResponse>(
          _pushRowsResponse(request.envelopes, status: 'rejected'),
        );
        await setup.seedRow(
          '70707070-7070-7070-7070-707070707070',
          VersionVector(<String, int>{'dev': 1}),
        );

        await Future.wait([
          setup.coordinator.pushCollection(SyncCollection.entries),
          setup.coordinator.pushCollection(SyncCollection.entries),
        ]);

        expect(setup.backend.pushes, hasLength(2));
      },
    );

    test('overlapping pushes report their own outcomes', () async {
      final setup = await pushSetup();
      setup.backend.onPush = _appliedPush;
      const rowID = '71717171-7171-7171-7171-717171717171';
      await setup.seedRow(rowID, VersionVector(<String, int>{'dev': 1}));

      final results = await Future.wait([
        setup.coordinator.pushCollection(SyncCollection.entries),
        setup.coordinator.pushCollection(SyncCollection.entries),
      ]);

      expect(results[0], isA<PushFullyAcknowledged>());
      expect(results[1], isA<PushNoop>());
      expect(setup.backend.pushes, hasLength(1));
    });
  });

  group('pushCollection: write-proof pass-through (TS7)', () {
    test('writeProof reaches the push request unchanged', () async {
      final setup = await pushSetup();
      setup.backend.onPush = (request) async => SyncSuccess<PushResponse>(
        _pushRowsResponse(request.envelopes, status: 'rejected'),
      );
      await setup.seedRow(
        '80808080-8080-8080-8080-808080808080',
        VersionVector(<String, int>{'dev': 1}),
      );

      await setup.coordinator.pushCollection(SyncCollection.entries);
      final proofed = await setup.coordinator.pushCollection(
        SyncCollection.entries,
        writeProof: 'proof-1',
      );

      expect(proofed, isA<PushUnresolvedRows>());
      expect(setup.backend.pushes, hasLength(2));
      expect(setup.backend.pushes[0].writeProof, isNull);
      expect(setup.backend.pushes[1].writeProof, 'proof-1');
    });
  });

  group('scheduling integration: status transitions (TS2)', () {
    test('idle at construction, running during a pass, idle after', () async {
      final backend = _TimelineBackend(pages: _emptyPages('ts2-idle'));
      final setup = await pushSetup(backend: backend);
      final coordinator = setup.coordinator;
      final observed = <SyncStatus>[];
      coordinator.addListener(() => observed.add(coordinator.status));

      expect(coordinator.status, const SyncIdle());

      final gate = Completer<void>();
      var pullCalls = 0;
      backend.onPull = () {
        pullCalls += 1;
        if (pullCalls <= SyncCollection.values.length) return gate.future;
        return Future<void>.value();
      };

      coordinator.requestSync();
      expect(await _settled(() => pullCalls == 5), isTrue);
      expect(coordinator.status, const SyncRunning());
      expect(observed, [const SyncRunning()]);

      gate.complete();
      expect(
        await _settled(() => coordinator.status == const SyncIdle()),
        isTrue,
      );
      expect(observed, [const SyncRunning(), const SyncIdle()]);
      expect(backend.pulls, hasLength(5));
    });

    test(
      'a trailing pass chains with no intermediate idle notification',
      () async {
        final backend = _TimelineBackend(pages: _emptyPages('ts2-chain'));
        final setup = await pushSetup(backend: backend);
        final coordinator = setup.coordinator;
        final observed = <SyncStatus>[];
        coordinator.addListener(() => observed.add(coordinator.status));

        final gate = Completer<void>();
        var pullCalls = 0;
        backend.onPull = () {
          pullCalls += 1;
          if (pullCalls <= SyncCollection.values.length) return gate.future;
          return Future<void>.value();
        };

        coordinator.requestSync();
        expect(await _settled(() => pullCalls == 5), isTrue);
        expect(observed, [const SyncRunning()]);

        coordinator.requestSync();
        for (var i = 0; i < 5; i++) {
          await Future<void>.delayed(Duration.zero);
        }
        expect(observed, [const SyncRunning()]);

        gate.complete();
        expect(
          await _settled(() => coordinator.status == const SyncIdle()),
          isTrue,
        );
        expect(observed, [const SyncRunning(), const SyncIdle()]);
        expect(backend.pulls, hasLength(10));
      },
    );
  });

  group('scheduling integration: run composition (TS3)', () {
    test('recovery runs once before any pull or push; every collection pulls '
        'exactly once, then pushes exactly once after its own pull', () async {
      final backend = _TimelineBackend(pages: _emptyPages('ts3'));
      final seenFailures = <Object>[];
      final setup = await pushSetup(
        backend: backend,
        onPassFailure: seenFailures.add,
      );
      backend.onPush = _appliedPush;
      for (final collection in SyncCollection.values) {
        final row = SyncRowID.of(collection, _ts3RowID(collection));
        final version = RowVersion(
          versionVector: VersionVector(<String, int>{'dev': 1}),
          lifecycle: SiblingLifecycle.live,
        );
        setup.reader.upsert(row, version);
        setup.versions.upsert(row, version);
      }
      await setup.coordinator.metadataStore.setPendingAcknowledgement(
        SyncCollection.entries,
        'cursor-seeded',
      );

      await setup.coordinator.syncNow();

      expect(seenFailures, isEmpty);
      expect(backend.events.first, 'ack:entries');
      expect(backend.pulls, hasLength(5));
      expect(
        backend.pulls.map((request) => request.collection).toSet(),
        SyncCollection.values.toSet(),
      );
      expect(backend.pushes, hasLength(5));
      expect(
        backend.pushes
            .map((request) => request.envelopes.single.collection)
            .toSet(),
        SyncCollection.values.toSet(),
      );
      for (final collection in SyncCollection.values) {
        final pullEnd = backend.events.indexOf('pull-end:${collection.name}');
        final push = backend.events.indexOf('push:${collection.name}');
        expect(pullEnd, isNot(-1), reason: collection.name);
        expect(push, isNot(-1), reason: collection.name);
        expect(pullEnd, lessThan(push), reason: collection.name);
      }
    });
  });

  group('scheduling integration: failure handling (TS4)', () {
    test('a StateError reports via onPassFailure exactly once and settles '
        'idle', () async {
      final backend = _FakeSyncBackend(
        failure: const NetworkUnavailable<PullResponse>(message: 'down'),
      );
      final failures = <Object>[];
      final setup = await pushSetup(
        backend: backend,
        onPassFailure: failures.add,
      );
      final coordinator = setup.coordinator;
      final observed = <SyncStatus>[];
      coordinator.addListener(() => observed.add(coordinator.status));

      coordinator.requestSync();
      expect(
        await _settled(
          () => coordinator.status == const SyncIdle() && failures.isNotEmpty,
        ),
        isTrue,
      );

      expect(failures, hasLength(1));
      expect(failures.single, isA<StateError>());
      expect(observed, [const SyncRunning(), const SyncIdle()]);
    });

    test(
      'a syncNow joined to a StateError-failing pass resolves normally',
      () async {
        final backend = _FakeSyncBackend(
          failure: const NetworkUnavailable<PullResponse>(message: 'down'),
        );
        final failures = <Object>[];
        final setup = await pushSetup(
          backend: backend,
          onPassFailure: failures.add,
        );

        await setup.coordinator.syncNow();

        expect(failures, hasLength(1));
        expect(failures.single, isA<StateError>());
        expect(setup.coordinator.status, const SyncIdle());
      },
    );

    test('a non-StateError from a requestSync-only pass escapes to the zone '
        'without invoking onPassFailure', () async {
      final backend = _TimelineBackend(pages: _emptyPages('ts4-zone'));
      final failures = <Object>[];
      final setup = await pushSetup(
        backend: backend,
        onPassFailure: failures.add,
      );
      backend.onPush = (request) async => throw FormatException('boom');
      await setup.seedRow(
        'aaaaaaaa-1111-2222-3333-444444444444',
        VersionVector(<String, int>{'dev': 1}),
      );
      final zoneErrors = <Object>[];

      await runZonedGuarded(() async {
        setup.coordinator.requestSync();
        expect(await _settled(() => backend.pushes.isNotEmpty), isTrue);
        expect(
          await _settled(() => setup.coordinator.status == const SyncIdle()),
          isTrue,
        );
        for (var i = 0; i < 10; i++) {
          await Future<void>.delayed(Duration.zero);
        }
      }, (Object error, StackTrace stackTrace) => zoneErrors.add(error));

      expect(zoneErrors, hasLength(1));
      expect(zoneErrors.single, isA<FormatException>());
      expect(failures, isEmpty);
      expect(setup.coordinator.status, const SyncIdle());
    });

    test('a non-StateError from a syncNow-joined pass rethrows to the caller '
        'without invoking onPassFailure', () async {
      final backend = _TimelineBackend(pages: _emptyPages('ts4-rethrow'));
      final failures = <Object>[];
      final setup = await pushSetup(
        backend: backend,
        onPassFailure: failures.add,
      );
      backend.onPush = (request) async => throw FormatException('boom');
      await setup.seedRow(
        'bbbbbbbb-1111-2222-3333-444444444444',
        VersionVector(<String, int>{'dev': 1}),
      );

      await expectLater(
        setup.coordinator.syncNow(),
        throwsA(isA<FormatException>()),
      );

      expect(failures, isEmpty);
      expect(setup.coordinator.status, const SyncIdle());
    });

    test(
      'a trigger after a failure starts and completes a fresh pass',
      () async {
        final backend = _FakeSyncBackend(
          failure: const NetworkUnavailable<PullResponse>(message: 'down'),
        );
        final failures = <Object>[];
        final setup = await pushSetup(
          backend: backend,
          onPassFailure: failures.add,
        );
        final coordinator = setup.coordinator;

        coordinator.requestSync();
        expect(
          await _settled(
            () => coordinator.status == const SyncIdle() && failures.isNotEmpty,
          ),
          isTrue,
        );
        expect(failures, hasLength(1));

        backend.failure = null;
        backend.pages.addAll(_emptyPages('ts4-retry'));
        coordinator.requestSync();
        expect(await _settled(() => backend.pulls.length == 10), isTrue);
        expect(
          await _settled(() => coordinator.status == const SyncIdle()),
          isTrue,
        );

        expect(failures, hasLength(1));
      },
    );
  });

  group('scheduling integration: scheduler delegation (TS6)', () {
    test('rapid requestSync calls during an in-flight pass collapse to at '
        'most one trailing pass', () async {
      final backend = _TimelineBackend(pages: _emptyPages('ts6-collapse'));
      final setup = await pushSetup(backend: backend);
      final coordinator = setup.coordinator;
      final observed = <SyncStatus>[];
      coordinator.addListener(() => observed.add(coordinator.status));

      final gate = Completer<void>();
      var pullCalls = 0;
      backend.onPull = () {
        pullCalls += 1;
        if (pullCalls <= SyncCollection.values.length) return gate.future;
        return Future<void>.value();
      };

      coordinator.requestSync();
      expect(await _settled(() => pullCalls == 5), isTrue);
      coordinator.requestSync();
      coordinator.requestSync();
      coordinator.requestSync();

      gate.complete();
      expect(
        await _settled(() => coordinator.status == const SyncIdle()),
        isTrue,
      );

      expect(backend.pulls, hasLength(10));
      expect(observed, [const SyncRunning(), const SyncIdle()]);
    });

    test('syncNow during an in-flight pass resolves only after the trailing '
        'pass completes', () async {
      final backend = _TimelineBackend(pages: _emptyPages('ts6-join'));
      final setup = await pushSetup(backend: backend);
      final coordinator = setup.coordinator;

      final firstGate = Completer<void>();
      final trailingGate = Completer<void>();
      var pullCalls = 0;
      backend.onPull = () {
        pullCalls += 1;
        if (pullCalls <= SyncCollection.values.length) {
          return firstGate.future;
        }
        if (pullCalls <= 2 * SyncCollection.values.length) {
          return trailingGate.future;
        }
        return Future<void>.value();
      };

      coordinator.requestSync();
      expect(await _settled(() => pullCalls == 5), isTrue);

      var resolved = false;
      final pending = coordinator.syncNow();
      unawaited(
        pending.then((_) {
          resolved = true;
        }),
      );
      for (var i = 0; i < 5; i++) {
        await Future<void>.delayed(Duration.zero);
      }

      firstGate.complete();
      expect(await _settled(() => pullCalls == 10), isTrue);
      expect(resolved, isFalse);

      trailingGate.complete();
      await pending;
      expect(resolved, isTrue);
      expect(backend.pulls, hasLength(10));
      expect(coordinator.status, const SyncIdle());
    });
  });

  group('scheduling integration: dispose', () {
    test('dispose when idle completes without error', () async {
      final setup = await pushSetup();

      expect(setup.coordinator.dispose, returnsNormally);
    });

    test('a pass settling after dispose does not notify listeners', () async {
      final backend = _TimelineBackend(pages: _emptyPages('dispose-gated'));
      final setup = await pushSetup(backend: backend);
      final coordinator = setup.coordinator;

      final gate = Completer<void>();
      var pullCalls = 0;
      backend.onPull = () {
        pullCalls += 1;
        if (pullCalls <= SyncCollection.values.length) return gate.future;
        return Future<void>.value();
      };

      coordinator.requestSync();
      expect(await _settled(() => pullCalls == 5), isTrue);
      expect(coordinator.status, const SyncRunning());

      coordinator.dispose();
      gate.complete();
      expect(
        await _settled(
          () =>
              backend.events
                  .where((event) => event.startsWith('pull-end:'))
                  .length ==
              5,
        ),
        isTrue,
      );
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(coordinator.status, const SyncRunning());
    });

    test('requestSync is a no-op after dispose', () async {
      final backend = _TimelineBackend(pages: _emptyPages('dispose-request'));
      final setup = await pushSetup(backend: backend);
      final coordinator = setup.coordinator;

      coordinator.dispose();
      coordinator.requestSync();
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(Duration.zero);
      }

      expect(backend.events, isEmpty);
    });

    test('syncNow throws after dispose', () async {
      final setup = await pushSetup();
      final coordinator = setup.coordinator;

      coordinator.dispose();

      expect(coordinator.syncNow, throwsStateError);
    });
  });

  group('bound RPCs and repair routing (TS6)', () {
    test(
      'pull, acknowledge, and push each present a BoundDeviceCredential',
      () async {
        final backend = _FakeSyncBackend(
          pages: {
            SyncCollection.entries: _pullPage(
              const <SyncEnvelope>[],
              'cursor-bound',
            ),
          },
        );
        final setup = await pushSetup(backend: backend);
        backend.onPush = _appliedPush;
        final coordinator = setup.coordinator;

        await coordinator.processPullPage(SyncCollection.entries);
        await coordinator.recoverPendingAcknowledgements();
        await setup.seedRow(
          '99990000-9999-9999-9999-999999999999',
          VersionVector(<String, int>{'dev': 1}),
        );
        await coordinator.pushCollection(SyncCollection.entries);

        expect(backend.pullCredentials, hasLength(1));
        expect(backend.pullCredentials.single, isA<BoundDeviceCredential>());
        expect(backend.acknowledgeCredentials, hasLength(1));
        expect(
          backend.acknowledgeCredentials.single,
          isA<BoundDeviceCredential>(),
        );
        expect(backend.pushCredentials, hasLength(1));
        expect(backend.pushCredentials.single, isA<BoundDeviceCredential>());
      },
    );

    test(
      'a 401 acknowledgement enters session reauth with its resume phase',
      () async {
        final backend = _FakeSyncBackend(
          acknowledgeOutcomes: {
            SyncCollection.entries:
                const CredentialExpired<AcknowledgeResponse>(
                  message: 'bearer expired',
                ),
          },
        );
        final setup = await pushSetup(backend: backend);
        final coordinator = setup.coordinator;
        await coordinator.metadataStore.setPendingAcknowledgement(
          SyncCollection.entries,
          'cursor-401',
        );

        await expectLater(
          coordinator.recoverPendingAcknowledgements(),
          throwsA(isA<StateError>()),
        );

        final snapshot = await coordinator.metadataStore.snapshot();
        expect(snapshot.deviceBindingState, SyncDeviceBindingState.bound);
        expect(snapshot.phase, SyncEnrollmentPhase.sessionReauthRequired);
        expect(snapshot.reauthResumePhase, SyncEnrollmentPhase.gateEnabled);
        expect(snapshot.writeEnabled, isFalse);
        expect(
          await coordinator.metadataStore.pendingAcknowledgement(
            SyncCollection.entries,
          ),
          'cursor-401',
        );
      },
    );

    test(
      'a matching 428 acknowledgement enters binding repair instead',
      () async {
        final backend = _FakeSyncBackend(
          acknowledgeOutcomes: {
            SyncCollection.entries:
                const DeviceAuthorizationRequired<AcknowledgeResponse>(
                  message: 'rebind required',
                ),
          },
        );
        final setup = await pushSetup(backend: backend);
        final coordinator = setup.coordinator;
        await coordinator.metadataStore.setPendingAcknowledgement(
          SyncCollection.entries,
          'cursor-428',
        );

        await expectLater(
          coordinator.recoverPendingAcknowledgements(),
          throwsA(isA<StateError>()),
        );

        final snapshot = await coordinator.metadataStore.snapshot();
        expect(
          snapshot.deviceBindingState,
          SyncDeviceBindingState.authorizationRequired,
        );
        expect(
          snapshot.phase,
          SyncEnrollmentPhase.bindingAuthorizationRequired,
        );
        expect(snapshot.reauthResumePhase, isNull);
        expect(snapshot.writeEnabled, isFalse);
        expect(await secrets.read(syncDeviceSecretKey), isNull);
      },
    );

    test(
      'concurrent 401s from every collection plus a pending acknowledge '
      'yield one session-reauth transition and stop further bound RPCs',
      () async {
        final backend = _FakeSyncBackend(
          failure: const CredentialExpired<PullResponse>(message: 'expired'),
          acknowledgeOutcomes: {
            SyncCollection.entries:
                const CredentialExpired<AcknowledgeResponse>(
                  message: 'expired',
                ),
          },
        );
        final setup = await pushSetup(backend: backend);
        final coordinator = setup.coordinator;
        await coordinator.metadataStore.setPendingAcknowledgement(
          SyncCollection.entries,
          'cursor-pending',
        );

        await expectLater(
          Future.wait(<Future<void>>[
            for (final collection in SyncCollection.values)
              coordinator.processPullPage(collection),
            coordinator.recoverPendingAcknowledgements(),
          ]),
          throwsA(isA<StateError>()),
        );

        // Pulls admitted before a sibling's latch send and fail; ones still
        // preparing when the gate closes are refused instead, so the count
        // varies with scheduling while the durable outcome stays single.
        expect(backend.pulls.length, greaterThanOrEqualTo(1));
        expect(
          backend.pulls.length,
          lessThanOrEqualTo(SyncCollection.values.length),
        );
        // The pending acknowledge shares its collection lock with that
        // collection's pull, so it may be refused post-repair without sending.
        final sentPulls = backend.pulls.length;
        final sentAcknowledges = backend.acknowledges.length;
        expect(sentAcknowledges, lessThanOrEqualTo(1));
        final snapshot = await coordinator.metadataStore.snapshot();
        expect(snapshot.deviceBindingState, SyncDeviceBindingState.bound);
        expect(snapshot.phase, SyncEnrollmentPhase.sessionReauthRequired);
        expect(snapshot.reauthResumePhase, SyncEnrollmentPhase.gateEnabled);
        expect(snapshot.writeEnabled, isFalse);
        expect(coordinator.repairGate.isOpen, isFalse);

        await expectLater(
          coordinator.processPullPage(SyncCollection.entries),
          throwsA(isA<StateError>()),
        );
        await expectLater(
          coordinator.recoverPendingAcknowledgements(),
          throwsA(isA<StateError>()),
        );
        expect(backend.pulls, hasLength(sentPulls));
        expect(backend.acknowledges, hasLength(sentAcknowledges));
      },
    );

    test(
      'a 401 completing before a matching 428 still ends in binding repair',
      () async {
        final backend = _FakeSyncBackend();
        final setup = await pushSetup(backend: backend);
        final coordinator = setup.coordinator;
        final arrivals = <SyncCollection>[];
        final entriesGate = Completer<SyncOutcome<PullResponse>>();
        final categoriesGate = Completer<SyncOutcome<PullResponse>>();
        backend.onPullRequest = (PullRequest request) {
          arrivals.add(request.collection);
          if (request.collection == SyncCollection.entries) {
            return entriesGate.future;
          }
          if (request.collection == SyncCollection.categories) {
            return categoriesGate.future;
          }
          throw StateError(
            'No gated outcome for pull of ${request.collection}.',
          );
        };
        Future<Object?> capture(Future<void> work) async {
          try {
            await work;
            return null;
          } catch (error) {
            return error;
          }
        }

        final first = capture(
          coordinator.processPullPage(SyncCollection.entries),
        );
        final second = capture(
          coordinator.processPullPage(SyncCollection.categories),
        );
        expect(await _settled(() => arrivals.length == 2), isTrue);

        entriesGate.complete(
          const CredentialExpired<PullResponse>(message: 'expired'),
        );
        expect(await first, isA<StateError>());
        var snapshot = await coordinator.metadataStore.snapshot();
        expect(snapshot.phase, SyncEnrollmentPhase.sessionReauthRequired);
        expect(snapshot.reauthResumePhase, SyncEnrollmentPhase.gateEnabled);

        categoriesGate.complete(
          const DeviceAuthorizationRequired<PullResponse>(
            message: 'rebind required',
          ),
        );
        expect(await second, isA<StateError>());
        snapshot = await coordinator.metadataStore.snapshot();
        expect(
          snapshot.deviceBindingState,
          SyncDeviceBindingState.authorizationRequired,
        );
        expect(
          snapshot.phase,
          SyncEnrollmentPhase.bindingAuthorizationRequired,
        );
        expect(snapshot.reauthResumePhase, isNull);
        expect(snapshot.writeEnabled, isFalse);
        expect(await secrets.read(syncDeviceSecretKey), isNull);
      },
    );

    test(
      'a matching 428 completing before a 401 still ends in binding repair',
      () async {
        final backend = _FakeSyncBackend();
        final setup = await pushSetup(backend: backend);
        final coordinator = setup.coordinator;
        final arrivals = <SyncCollection>[];
        final entriesGate = Completer<SyncOutcome<PullResponse>>();
        final categoriesGate = Completer<SyncOutcome<PullResponse>>();
        backend.onPullRequest = (PullRequest request) {
          arrivals.add(request.collection);
          if (request.collection == SyncCollection.entries) {
            return entriesGate.future;
          }
          if (request.collection == SyncCollection.categories) {
            return categoriesGate.future;
          }
          throw StateError(
            'No gated outcome for pull of ${request.collection}.',
          );
        };
        Future<Object?> capture(Future<void> work) async {
          try {
            await work;
            return null;
          } catch (error) {
            return error;
          }
        }

        final first = capture(
          coordinator.processPullPage(SyncCollection.entries),
        );
        final second = capture(
          coordinator.processPullPage(SyncCollection.categories),
        );
        expect(await _settled(() => arrivals.length == 2), isTrue);

        entriesGate.complete(
          const DeviceAuthorizationRequired<PullResponse>(
            message: 'rebind required',
          ),
        );
        expect(await first, isA<StateError>());
        var snapshot = await coordinator.metadataStore.snapshot();
        expect(
          snapshot.deviceBindingState,
          SyncDeviceBindingState.authorizationRequired,
        );
        expect(
          snapshot.phase,
          SyncEnrollmentPhase.bindingAuthorizationRequired,
        );

        categoriesGate.complete(
          const CredentialExpired<PullResponse>(message: 'expired'),
        );
        expect(await second, isA<StateError>());
        snapshot = await coordinator.metadataStore.snapshot();
        expect(
          snapshot.deviceBindingState,
          SyncDeviceBindingState.authorizationRequired,
        );
        expect(
          snapshot.phase,
          SyncEnrollmentPhase.bindingAuthorizationRequired,
        );
        expect(snapshot.reauthResumePhase, isNull);
        expect(snapshot.writeEnabled, isFalse);
      },
    );

    test('a late 428 for an already-rotated secret deletes nothing and '
        'repairs nothing', () async {
      final backend = _FakeSyncBackend();
      final setup = await pushSetup(backend: backend);
      final coordinator = setup.coordinator;
      final rotated = _deviceSecret(9);
      backend.onPullRequest = (PullRequest request) async {
        await secrets.write(syncDeviceSecretKey, rotated);
        return const DeviceAuthorizationRequired<PullResponse>(
          message: 'rebind required',
        );
      };

      await expectLater(
        coordinator.processPullPage(SyncCollection.entries),
        throwsA(isA<StateError>()),
      );

      expect(await secrets.read(syncDeviceSecretKey), rotated);
      final snapshot = await coordinator.metadataStore.snapshot();
      expect(snapshot.deviceBindingState, SyncDeviceBindingState.bound);
      expect(snapshot.phase, SyncEnrollmentPhase.gateEnabled);
      expect(snapshot.writeEnabled, isTrue);
      expect(coordinator.repairGate.isOpen, isTrue);
    });

    test('a reopened coordinator shares the latched gate until a durable '
        'repair exit', () async {
      final firstBackend = _FakeSyncBackend(
        failure: const CredentialExpired<PullResponse>(message: 'expired'),
      );
      final first = await pushSetup(backend: firstBackend);
      await expectLater(
        first.coordinator.processPullPage(SyncCollection.entries),
        throwsA(isA<StateError>()),
      );
      expect(first.coordinator.repairGate.isOpen, isFalse);
      final recomposed = await create();
      expect(
        identical(first.coordinator.repairGate, recomposed.repairGate),
        isTrue,
      );
      expect(recomposed.repairGate.isOpen, isFalse);

      final secondBackend = _FakeSyncBackend(
        pages: {
          SyncCollection.entries: _pullPage(
            const <SyncEnvelope>[],
            'cursor-reopen',
          ),
        },
      );
      final reopened = await pullCoordinator(
        backend: secondBackend,
        versionSource: InMemorySyncVersionSource(),
        staging: InMemorySyncStagingStore(),
        e2eKey: _freshKey(),
      );
      expect(
        identical(first.coordinator.repairGate, reopened.repairGate),
        isTrue,
      );
      expect(reopened.repairGate.isOpen, isFalse);
      await reopened.metadataStore.enterSessionReauthRequired();
      await expectLater(
        reopened.processPullPage(SyncCollection.entries),
        throwsA(isA<StateError>()),
      );
      expect(secondBackend.pulls, isEmpty);

      await reopened.metadataStore.restoreFromSessionReauth();
      // The service releases the gate when it commits the exit; this test
      // drives the store directly, so it releases explicitly.
      await reopened.repairGate.release(
        await reopened.repairGate.repairEpisode(),
      );
      await reopened.processPullPage(SyncCollection.entries);
      expect(secondBackend.pulls, hasLength(1));
      expect(reopened.repairGate.isOpen, isTrue);
    });

    test('a missing device secret routes pull into binding repair without '
        'sending', () async {
      final backend = _FakeSyncBackend();
      final setup = await pushSetup(backend: backend);
      await secrets.delete(syncDeviceSecretKey);

      await expectLater(
        setup.coordinator.processPullPage(SyncCollection.entries),
        throwsA(isA<StateError>()),
      );

      expect(backend.pulls, isEmpty);
      final snapshot = await setup.coordinator.metadataStore.snapshot();
      expect(
        snapshot.deviceBindingState,
        SyncDeviceBindingState.authorizationRequired,
      );
      expect(snapshot.phase, SyncEnrollmentPhase.bindingAuthorizationRequired);
      expect(snapshot.reauthResumePhase, isNull);
      expect(snapshot.writeEnabled, isFalse);
    });

    test('repair exit waits for malformed-secret transition', () async {
      final backend = _FakeSyncBackend();
      final heldSecrets = _BlockingDeleteSecretStore(secrets);
      final coordinator = await pullCoordinator(
        backend: backend,
        versionSource: InMemorySyncVersionSource(),
        staging: InMemorySyncStagingStore(),
        e2eKey: _freshKey(),
        credentialSecrets: heldSecrets,
      );
      await secrets.write(syncDeviceSecretKey, 'malformed');
      final priorGeneration = await coordinator.repairGate.repairEpisode();
      final repair = coordinator.processPullPage(SyncCollection.entries);
      await heldSecrets.deleteStarted.future;
      expect(await _settled(() => !coordinator.repairGate.isOpen), isTrue);

      var exitCompleted = false;
      final exit = coordinator.repairGate
          .release(priorGeneration + 1)
          .then((_) => exitCompleted = true);
      await Future<void>.delayed(Duration.zero);
      expect(exitCompleted, isFalse);
      expect(coordinator.repairGate.isOpen, isFalse);

      heldSecrets.releaseDelete.complete();
      await expectLater(repair, throwsStateError);
      await exit;
      expect(exitCompleted, isTrue);
      final snapshot = await coordinator.metadataStore.snapshot();
      expect(snapshot.phase, SyncEnrollmentPhase.bindingAuthorizationRequired);
    });

    test('a superseded missing-secret read enters no repair', () async {
      final backend = _FakeSyncBackend();
      final rotating = _RotatingMissingSecretStore(
        secrets,
        SyncRepairGate.forDatabase(db),
      );
      final coordinator = await pullCoordinator(
        backend: backend,
        versionSource: InMemorySyncVersionSource(),
        staging: InMemorySyncStagingStore(),
        e2eKey: _freshKey(),
        credentialSecrets: rotating,
      );

      await expectLater(
        coordinator.processPullPage(SyncCollection.entries),
        throwsStateError,
      );
      expect(rotating.replaced, isTrue);
      expect(backend.pulls, isEmpty);
      expect(coordinator.repairGate.isOpen, isTrue);
      final snapshot = await coordinator.metadataStore.snapshot();
      expect(snapshot.phase, SyncEnrollmentPhase.snapshotInProgress);
    });

    test(
      'a malformed device secret is deleted before entering binding repair',
      () async {
        final backend = _FakeSyncBackend();
        final setup = await pushSetup(backend: backend);
        await secrets.write(syncDeviceSecretKey, 'not-a-secret');

        await expectLater(
          setup.coordinator.processPullPage(SyncCollection.entries),
          throwsA(isA<StateError>()),
        );

        expect(backend.pulls, isEmpty);
        expect(await secrets.read(syncDeviceSecretKey), isNull);
        final snapshot = await setup.coordinator.metadataStore.snapshot();
        expect(
          snapshot.phase,
          SyncEnrollmentPhase.bindingAuthorizationRequired,
        );
      },
    );

    test('a missing bearer with a valid secret routes pull into session '
        'reauth without sending', () async {
      final backend = _FakeSyncBackend();
      final setup = await pushSetup(backend: backend);
      await secrets.delete(syncCredentialSecretKey);

      await expectLater(
        setup.coordinator.processPullPage(SyncCollection.entries),
        throwsA(isA<StateError>()),
      );

      expect(backend.pulls, isEmpty);
      final snapshot = await setup.coordinator.metadataStore.snapshot();
      expect(snapshot.deviceBindingState, SyncDeviceBindingState.bound);
      expect(snapshot.phase, SyncEnrollmentPhase.sessionReauthRequired);
      expect(snapshot.reauthResumePhase, SyncEnrollmentPhase.gateEnabled);
      expect(snapshot.writeEnabled, isFalse);
    });

    test('a storage failure stops the pull without entering repair', () async {
      final backend = _FakeSyncBackend(
        pages: {
          SyncCollection.entries: _pullPage(
            const <SyncEnvelope>[],
            'cursor-storage',
          ),
        },
      );
      final setup = await pushSetup(backend: backend);
      secrets.readFailure = StateError('secure storage unavailable');

      await expectLater(
        setup.coordinator.processPullPage(SyncCollection.entries),
        throwsA(isA<CredentialUnavailableException>()),
      );

      expect(backend.pulls, isEmpty);
      final snapshot = await setup.coordinator.metadataStore.snapshot();
      expect(snapshot.deviceBindingState, SyncDeviceBindingState.bound);
      expect(snapshot.phase, SyncEnrollmentPhase.gateEnabled);
      expect(snapshot.writeEnabled, isTrue);
      expect(setup.coordinator.repairGate.isOpen, isTrue);
    });

    test('a 401 push enters session reauth with its resume phase', () async {
      final backend = _FakeSyncBackend();
      backend.onPush = (PushRequest request) async =>
          const CredentialExpired<PushResponse>(message: 'expired');
      final setup = await pushSetup(backend: backend);
      await setup.seedRow(
        '12121212-1212-1212-1212-121212121212',
        VersionVector(<String, int>{'dev': 1}),
      );

      await expectLater(
        setup.coordinator.pushCollection(SyncCollection.entries),
        throwsA(isA<StateError>()),
      );

      expect(backend.pushCredentials.single, isA<BoundDeviceCredential>());
      final snapshot = await setup.coordinator.metadataStore.snapshot();
      expect(snapshot.deviceBindingState, SyncDeviceBindingState.bound);
      expect(snapshot.phase, SyncEnrollmentPhase.sessionReauthRequired);
      expect(snapshot.reauthResumePhase, SyncEnrollmentPhase.gateEnabled);
      expect(snapshot.writeEnabled, isFalse);
      expect(
        await setup.coordinator.metadataStore.acknowledgedVectors(),
        isEmpty,
      );
    });

    test('a legal binding-repair state refuses new bound RPCs', () async {
      final backend = _FakeSyncBackend(
        pages: {
          SyncCollection.entries: _pullPage(
            const <SyncEnvelope>[],
            'cursor-repair-refused',
          ),
        },
      );
      final setup = await pushSetup(backend: backend);
      await setup.coordinator.metadataStore.enterBindingAuthorizationRequired();

      await expectLater(
        setup.coordinator.processPullPage(SyncCollection.entries),
        throwsA(isA<StateError>()),
      );

      expect(backend.pulls, isEmpty);
      expect(setup.coordinator.repairGate.isOpen, isFalse);
    });

    test('an illegal hosted row refuses bound RPCs before any send', () async {
      final backend = _FakeSyncBackend(
        pages: {
          SyncCollection.entries: _pullPage(
            const <SyncEnvelope>[],
            'cursor-illegal',
          ),
        },
      );
      final setup = await pushSetup(backend: backend);
      await setup.coordinator.metadataStore.setEnrollmentPhase(
        SyncEnrollmentPhase.sessionReauthRequired,
      );

      await expectLater(
        setup.coordinator.processPullPage(SyncCollection.entries),
        throwsA(isA<StateError>()),
      );

      expect(backend.pulls, isEmpty);
    });

    test('a gate closed during credential resolution sends nothing and '
        'enters no repair', () async {
      final backend = _FakeSyncBackend(
        pages: {
          SyncCollection.entries: _pullPage(
            const <SyncEnvelope>[],
            'cursor-pre-send',
          ),
        },
      );
      final latching = _LatchingSecretStore(
        secrets,
        SyncRepairGate.forDatabase(db),
      );
      final coordinator = await pullCoordinator(
        backend: backend,
        versionSource: InMemorySyncVersionSource(),
        staging: InMemorySyncStagingStore(),
        e2eKey: _freshKey(),
        credentialSecrets: latching,
      );

      await expectLater(
        coordinator.processPullPage(SyncCollection.entries),
        throwsA(isA<StateError>()),
      );

      expect(latching.latched, isTrue);
      expect(backend.pulls, isEmpty);
      final snapshot = await coordinator.metadataStore.snapshot();
      expect(snapshot.deviceBindingState, SyncDeviceBindingState.bound);
      expect(snapshot.phase, SyncEnrollmentPhase.snapshotInProgress);
      expect(coordinator.repairGate.isOpen, isFalse);
    });

    test('a success arriving after the gate closes commits nothing', () async {
      final backend = _FakeSyncBackend();
      final setup = await pushSetup(backend: backend);
      final coordinator = setup.coordinator;
      final responseGate = Completer<SyncOutcome<PullResponse>>();
      var sent = false;
      backend.onPullRequest = (PullRequest request) {
        sent = true;
        return responseGate.future;
      };

      final pending = coordinator.processPullPage(SyncCollection.entries);
      expect(await _settled(() => sent), isTrue);
      await coordinator.repairGate.latch();
      await coordinator.metadataStore.enterSessionReauthRequired();
      responseGate.complete(
        SyncSuccess<PullResponse>(
          _pullPage(const <SyncEnvelope>[], 'cursor-late'),
        ),
      );

      await expectLater(pending, throwsA(isA<StateError>()));
      final snapshot = await coordinator.metadataStore.snapshot();
      expect(snapshot.watermarks[SyncCollection.entries], isNull);
      expect(
        await coordinator.metadataStore.pendingAcknowledgement(
          SyncCollection.entries,
        ),
        isNull,
      );
      expect(await coordinator.metadataStore.acknowledgedVectors(), isEmpty);
      expect(snapshot.phase, SyncEnrollmentPhase.sessionReauthRequired);
    });

    test('pull closure during staging flush cannot record a page', () async {
      final backend = _FakeSyncBackend(
        pages: {
          SyncCollection.entries: _pullPage(const <SyncEnvelope>[], 'late'),
        },
      );
      final staging = _BlockingFlushStaging(InMemorySyncStagingStore());
      final coordinator = await pullCoordinator(
        backend: backend,
        versionSource: InMemorySyncVersionSource(),
        staging: staging,
        e2eKey: _freshKey(),
      );
      final pending = coordinator.processPullPage(SyncCollection.entries);
      await staging.firstFlushStarted.future;
      await coordinator.repairGate.latch();
      staging.releaseFirstFlush.complete();

      await expectLater(pending, throwsStateError);
      final snapshot = await coordinator.metadataStore.snapshot();
      expect(snapshot.watermarks[SyncCollection.entries], isNull);
      expect(
        await coordinator.metadataStore.pendingAcknowledgement(
          SyncCollection.entries,
        ),
        isNull,
      );
    });

    test(
      'enrollment repair closes a pull lease before page metadata',
      () async {
        final backend = _FakeSyncBackend(
          pages: {
            SyncCollection.entries: _pullPage(const <SyncEnvelope>[], 'late'),
          },
        );
        backend.onReconcile = (credential, request) async =>
            const CredentialExpired<ReconcileResponse>(message: 'expired');
        final staging = _BlockingFlushStaging(InMemorySyncStagingStore());
        final coordinator = await pullCoordinator(
          backend: backend,
          versionSource: InMemorySyncVersionSource(),
          staging: staging,
          e2eKey: _freshKey(),
        );
        final unused = _UnusedEnrollmentCollaborators();
        final enrollment = SyncEnrollmentService(
          authenticator: unused,
          backend: backend,
          metadataStore: coordinator.metadataStore,
          secretStore: secrets,
          database: db,
          buildBeginRequest: () => BeginEnrollmentRequest(const {}),
          buildCompleteRequest: (challenge) async =>
              CompleteEnrollmentRequest(const {}),
          resolveE2EKey: () async => _freshKey(),
          buildSnapshotHasher: (credential) => ReconciliationSnapshotHasher(
            backend: backend,
            credential: credential,
          ),
          bindingAuthorizer: unused,
          bindingIdentifier: 'user@example.com',
          resolveBindingOtp: (challenge) async => 'unused',
        );

        final pendingPull = coordinator.processPullPage(SyncCollection.entries);
        await staging.firstFlushStarted.future;
        await expectLater(
          enrollment.enroll(),
          throwsA(isA<SyncEnrollmentException>()),
        );
        expect(coordinator.repairGate.isOpen, isFalse);
        staging.releaseFirstFlush.complete();
        await expectLater(pendingPull, throwsStateError);
        final snapshot = await coordinator.metadataStore.snapshot();
        expect(snapshot.phase, SyncEnrollmentPhase.sessionReauthRequired);
        expect(snapshot.watermarks[SyncCollection.entries], isNull);
      },
    );

    test(
      'acknowledgement closure after response cannot clear checkpoint',
      () async {
        final backend = _FakeSyncBackend();
        final setup = await pushSetup(backend: backend);
        final coordinator = setup.coordinator;
        await coordinator.metadataStore.setPendingAcknowledgement(
          SyncCollection.entries,
          'checkpoint',
        );
        final releaseQueue = Completer<void>();
        final responded = Completer<void>();
        backend.onAcknowledge = (request) async {
          await _queueLatchBehindHeldGate(coordinator.repairGate, releaseQueue);
          responded.complete();
          return SyncSuccess<AcknowledgeResponse>(
            AcknowledgeResponse(<String, Object?>{}),
          );
        };

        final pending = coordinator.recoverPendingAcknowledgements();
        await responded.future;
        await Future<void>.delayed(Duration.zero);
        releaseQueue.complete();
        await expectLater(pending, throwsStateError);
        expect(
          await coordinator.metadataStore.pendingAcknowledgement(
            SyncCollection.entries,
          ),
          'checkpoint',
        );
      },
    );

    test('push closure after response cannot acknowledge a row', () async {
      final backend = _FakeSyncBackend();
      final setup = await pushSetup(backend: backend);
      const rowID = '79797979-7979-7979-7979-797979797979';
      await setup.seedRow(rowID, VersionVector(<String, int>{'dev': 1}));
      final releaseQueue = Completer<void>();
      final responded = Completer<void>();
      backend.onPush = (request) async {
        await _queueLatchBehindHeldGate(
          setup.coordinator.repairGate,
          releaseQueue,
        );
        responded.complete();
        return SyncSuccess<PushResponse>(_pushRowsResponse(request.envelopes));
      };

      final pending = setup.coordinator.pushCollection(SyncCollection.entries);
      await responded.future;
      await Future<void>.delayed(Duration.zero);
      releaseQueue.complete();
      await expectLater(pending, throwsStateError);
      expect(
        await setup.coordinator.metadataStore.acknowledgedVectors(),
        isEmpty,
      );
    });

    test('device-secret rotation preserves expired-bearer reauth', () async {
      final backend = _FakeSyncBackend();
      final setup = await pushSetup(backend: backend);
      backend.onPullRequest = (request) async {
        await setup.coordinator.repairGate.withSecretMutationLock(
          () => secrets.write(syncDeviceSecretKey, _deviceSecret(9)),
        );
        return const CredentialExpired<PullResponse>(message: 'expired');
      };

      await expectLater(
        setup.coordinator.processPullPage(SyncCollection.entries),
        throwsStateError,
      );
      final snapshot = await setup.coordinator.metadataStore.snapshot();
      expect(snapshot.phase, SyncEnrollmentPhase.sessionReauthRequired);
      expect(setup.coordinator.repairGate.isOpen, isFalse);
    });

    test(
      'duplicate expired-bearer responses share one repair episode',
      () async {
        final backend = _FakeSyncBackend();
        final setup = await pushSetup(backend: backend);
        final firstResponse = Completer<SyncOutcome<PullResponse>>();
        final secondResponse = Completer<SyncOutcome<PullResponse>>();
        backend.onPullRequest = (request) => switch (request.collection) {
          SyncCollection.entries => firstResponse.future,
          SyncCollection.categories => secondResponse.future,
          _ => throw StateError('Unexpected collection.'),
        };

        final first = setup.coordinator.processPullPage(SyncCollection.entries);
        final second = setup.coordinator.processPullPage(
          SyncCollection.categories,
        );
        expect(await _settled(() => backend.pulls.length == 2), isTrue);
        firstResponse.complete(
          const CredentialExpired<PullResponse>(message: 'expired'),
        );
        await expectLater(first, throwsStateError);
        final episode = await setup.coordinator.repairGate.repairEpisode();
        secondResponse.complete(
          const CredentialExpired<PullResponse>(message: 'expired'),
        );
        await expectLater(second, throwsStateError);
        expect(await setup.coordinator.repairGate.repairEpisode(), episode);
        await setup.coordinator.repairGate.release(episode);
        expect(setup.coordinator.repairGate.isOpen, isTrue);
      },
    );

    test(
      'queued bearer replacement wins before expired-bearer comparison',
      () async {
        final backend = _FakeSyncBackend();
        final setup = await pushSetup(backend: backend);
        final coordinator = setup.coordinator;
        final releaseQueue = Completer<void>();
        final enteredQueue = Completer<void>();
        backend.onPullRequest = (request) async {
          unawaited(
            coordinator.repairGate.withSecretMutationLock(() async {
              enteredQueue.complete();
              await releaseQueue.future;
              final id = await deviceID(db);
              await secrets.write(
                syncCredentialSecretKey,
                _credentialPayload(id, 'replacement'),
              );
            }),
          );
          await enteredQueue.future;
          return const CredentialExpired<PullResponse>(message: 'expired');
        };

        final pending = coordinator.processPullPage(SyncCollection.entries);
        expect(await _settled(() => backend.pulls.isNotEmpty), isTrue);
        await Future<void>.delayed(Duration.zero);
        releaseQueue.complete();
        await expectLater(pending, throwsStateError);
        final snapshot = await coordinator.metadataStore.snapshot();
        expect(snapshot.phase, SyncEnrollmentPhase.gateEnabled);
        expect(coordinator.repairGate.isOpen, isTrue);
      },
    );

    test('a 401 for a superseded bearer enters no repair', () async {
      final backend = _FakeSyncBackend();
      final setup = await pushSetup(backend: backend);
      final coordinator = setup.coordinator;
      backend.onPullRequest = (PullRequest request) async {
        final id = await deviceID(db);
        await secrets.write(
          syncCredentialSecretKey,
          _credentialPayload(id, 'rotated-bearer'),
        );
        return const CredentialExpired<PullResponse>(message: 'expired');
      };

      await expectLater(
        coordinator.processPullPage(SyncCollection.entries),
        throwsA(isA<StateError>()),
      );

      expect(backend.pulls, hasLength(1));
      final snapshot = await coordinator.metadataStore.snapshot();
      expect(snapshot.deviceBindingState, SyncDeviceBindingState.bound);
      expect(snapshot.phase, SyncEnrollmentPhase.gateEnabled);
      expect(snapshot.writeEnabled, isTrue);
      expect(coordinator.repairGate.isOpen, isTrue);
    });
  });
}

PushResponse _pushRowsResponse(
  List<SyncEnvelope> submitted, {
  String status = 'applied',
  VersionVector? frontier,
}) => PushResponse(<String, Object?>{
  'rows': [
    for (final envelope in submitted)
      <String, Object?>{
        'row_id': envelope.rowID,
        'collection': envelope.collection.wireName,
        'sibling_id': envelope.siblingID,
        'status': status,
        if (status != 'rejected')
          'version_vector': (frontier ?? envelope.versionVector)
              .toWireCounters(),
      },
  ],
});

Future<SyncOutcome<PushResponse>> _appliedPush(PushRequest request) async =>
    SyncSuccess<PushResponse>(_pushRowsResponse(request.envelopes));

final class _PushSetup {
  _PushSetup({
    required this.coordinator,
    required this.backend,
    required this.reader,
    required this.versions,
    required this.staging,
  });

  final SyncCoordinator coordinator;
  final _FakeSyncBackend backend;
  final InMemoryCollectionVersionReader reader;
  final InMemorySyncVersionSource versions;
  final InMemorySyncStagingStore staging;

  final Set<String> _holders = <String>{};

  Future<void> seedRow(
    String rowID,
    VersionVector vector, {
    String holderID = 'aaaaaaaa-0000-1111-2222-333333333333',
    bool inLedger = true,
    SiblingLifecycle lifecycle = SiblingLifecycle.live,
    VersionVector? acknowledged,
  }) async {
    final row = SyncRowID.of(SyncCollection.entries, rowID);
    if (inLedger) {
      if (_holders.add(holderID)) {
        coordinator.ledger.addAccount(
          Account(id: holderID, name: 'holder', type: AccountType.cash),
        );
      }
      coordinator.ledger.addEntry(
        Entry(
          id: rowID,
          date: DateTime.utc(2024, 3, 15),
          amount: Decimal.parse('-12.50'),
          name: 'Local',
          sourceID: holderID,
          includeInAnalysis: true,
        ),
      );
    }
    final version = RowVersion(versionVector: vector, lifecycle: lifecycle);
    reader.upsert(row, version);
    versions.upsert(row, version);
    if (acknowledged != null) {
      await coordinator.metadataStore.setAcknowledgedVector(row, acknowledged);
    }
  }
}

final class _DriftSetup {
  _DriftSetup({
    required this.coordinator,
    required this.staging,
    required this.store,
    required this.device,
    required this.effectiveStore,
    required this.effectiveVersions,
  });

  final SyncCoordinator coordinator;
  final DriftSyncStagingStore staging;
  final DriftLedgerStore store;

  final String device;
  final LedgerStore effectiveStore;
  final SyncVersionSource effectiveVersions;
}

final class _HookLedgerStore implements LedgerStore {
  _HookLedgerStore(this._inner);

  final LedgerStore _inner;

  Future<void> Function()? onFlushNow;

  int flushCalls = 0;

  @override
  Future<LedgerState> load() => _inner.load();

  @override
  Future<void> seedIfFirstLaunch(List<LedgerChange> changes) =>
      _inner.seedIfFirstLaunch(changes);

  @override
  Future<void> start() => _inner.start();

  @override
  void enqueue(List<LedgerChange> changes) => _inner.enqueue(changes);

  @override
  void enqueueStamped(
    List<LedgerChange> changes,
    Map<SyncRowID, VersionVector> stamps,
  ) => _inner.enqueueStamped(changes, stamps);

  @override
  Future<void> setErrorHandler(SaveErrorHandler handler) =>
      _inner.setErrorHandler(handler);

  @override
  Future<void> flushNow() async {
    flushCalls += 1;
    final hook = onFlushNow;
    if (hook != null) await hook();
    await _inner.flushNow();
  }
}

final class _HookVersionSource implements SyncVersionSource {
  _HookVersionSource(this._inner);

  final SyncVersionSource _inner;

  Future<void> Function()? onRefresh;

  int refreshCalls = 0;

  @override
  RowVersion? readRowVersion(SyncRowID rowID) => _inner.readRowVersion(rowID);

  @override
  Future<void> refresh() async {
    refreshCalls += 1;
    final hook = onRefresh;
    if (hook != null) {
      onRefresh = null;
      await hook();
    }
    await _inner.refresh();
  }
}

final class _HookEngine extends SyncEngine {
  _HookEngine({
    required super.userID,
    required super.keyAccessor,
    super.stagingStore,
  });

  Future<void> Function()? onFoldInReconcile;

  @override
  Future<ReconcileResult> reconcile(Iterable<SyncEnvelope> envelopes) async {
    final List<SyncEnvelope> inputs = envelopes.toList();
    final hook = onFoldInReconcile;
    if (inputs.length == 2 && hook != null) {
      onFoldInReconcile = null;
      await hook();
    }
    return super.reconcile(envelopes);
  }
}

final class _ScriptedVersionSource implements SyncVersionSource {
  _ScriptedVersionSource({required this.first, required this.later});

  final RowVersion first;
  final RowVersion later;

  int _reads = 0;

  @override
  RowVersion? readRowVersion(SyncRowID rowID) {
    _reads += 1;
    return _reads == 1 ? first : later;
  }

  @override
  Future<void> refresh() async {}
}

final class _CyclingVersionSource implements SyncVersionSource {
  _CyclingVersionSource(this._scripts);

  final Map<SyncRowID, List<RowVersion?>> _scripts;

  final Map<SyncRowID, int> _reads = {};

  int refreshCalls = 0;

  @override
  RowVersion? readRowVersion(SyncRowID rowID) {
    final script = _scripts[rowID];
    if (script == null || script.isEmpty) return null;
    final count = _reads[rowID] ?? 0;
    _reads[rowID] = count + 1;
    return script[count % script.length];
  }

  @override
  Future<void> refresh() async {
    refreshCalls += 1;
  }
}

final class _MapReader implements CollectionVersionReader {
  _MapReader(this._rows);

  final Map<SyncRowID, RowVersion> _rows;

  @override
  Future<Map<SyncRowID, RowVersion>> readRowVersions(
    SyncCollection collection,
  ) async => {
    for (final entry in _rows.entries)
      if (entry.key.collection == collection) entry.key: entry.value,
  };
}

final class _FailingFlushStaging implements SyncStagingStore {
  _FailingFlushStaging(this._inner);

  final SyncStagingStore _inner;

  @override
  void stage(StagedConflict conflict) => _inner.stage(conflict);

  @override
  List<StagedConflict> get pendingConflicts => _inner.pendingConflicts;

  @override
  void resolve(StagedConflict conflict) => _inner.resolve(conflict);

  @override
  Future<List<StagedConflict>> pendingConflictList() =>
      _inner.pendingConflictList();

  @override
  Future<void> flush() => throw StateError('staging flush failed');
}

final class _BlockingFlushStaging implements SyncStagingStore {
  _BlockingFlushStaging(this._inner);

  final SyncStagingStore _inner;
  final firstFlushStarted = Completer<void>();
  final releaseFirstFlush = Completer<void>();
  var _first = true;

  @override
  void stage(StagedConflict conflict) => _inner.stage(conflict);

  @override
  List<StagedConflict> get pendingConflicts => _inner.pendingConflicts;

  @override
  void resolve(StagedConflict conflict) => _inner.resolve(conflict);

  @override
  Future<List<StagedConflict>> pendingConflictList() =>
      _inner.pendingConflictList();

  @override
  Future<void> flush() async {
    if (_first) {
      _first = false;
      firstFlushStarted.complete();
      await releaseFirstFlush.future;
    }
    await _inner.flush();
  }
}

Future<void> _queueLatchBehindHeldGate(
  SyncRepairGate gate,
  Completer<void> releaseQueue,
) async {
  final enteredQueue = Completer<void>();
  unawaited(
    gate.withSecretMutationLock(() async {
      enteredQueue.complete();
      await releaseQueue.future;
    }),
  );
  await enteredQueue.future;
  unawaited(gate.latch());
}

final class _ManualClock {
  final List<_ArmedTimer> _armed = [];

  int get armedCount => _armed.length;

  StoreTimer arm(Duration delay, void Function() onFire) {
    final armed = _ArmedTimer(delay, onFire, this);
    _armed.add(armed);
    return armed;
  }

  void fire() {
    final due = List<_ArmedTimer>.of(_armed);
    _armed.clear();
    for (final timer in due) {
      timer.onFire();
    }
  }
}

final class _ArmedTimer implements StoreTimer {
  _ArmedTimer(this.delay, this.onFire, this.owner);

  final Duration delay;
  final void Function() onFire;
  final _ManualClock owner;

  @override
  void cancel() => owner._armed.remove(this);
}

Future<bool> _settled(bool Function() done) async {
  for (var i = 0; i < 200 && !done(); i++) {
    await Future<void>.delayed(Duration.zero);
  }
  return done();
}

final class _TimelineBackend extends _FakeSyncBackend {
  _TimelineBackend({super.pages});

  final List<String> events = [];

  Future<void> Function()? onPull;

  @override
  Future<SyncOutcome<PullResponse>> pull(
    SyncCredential credential,
    PullRequest request,
  ) async {
    events.add('pull-start:${request.collection.name}');
    final hook = onPull;
    if (hook != null) await hook();
    final outcome = await super.pull(credential, request);
    events.add('pull-end:${request.collection.name}');
    return outcome;
  }

  @override
  Future<SyncOutcome<PushResponse>> push(
    SyncCredential credential,
    PushRequest request,
  ) async {
    final names = request.envelopes.map((envelope) => envelope.collection.name);
    events.add('push:${names.join('+')}');
    return super.push(credential, request);
  }

  @override
  Future<SyncOutcome<AcknowledgeResponse>> acknowledge(
    SyncCredential credential,
    AcknowledgeRequest request,
  ) async {
    events.add('ack:${request.collection.name}');
    return super.acknowledge(credential, request);
  }
}

Map<SyncCollection, PullResponse> _emptyPages(String prefix) => {
  for (final collection in SyncCollection.values)
    collection: _pullPage(const <SyncEnvelope>[], '$prefix-${collection.name}'),
};

String _ts3RowID(SyncCollection collection) {
  switch (collection) {
    case SyncCollection.moneySources:
      return '10000000-0000-1111-2222-333333333333';
    case SyncCollection.entries:
      return '20000000-0000-1111-2222-333333333333';
    case SyncCollection.categories:
      return '30000000-0000-1111-2222-333333333333';
    case SyncCollection.plans:
      return '40000000-0000-1111-2222-333333333333';
    case SyncCollection.budgets:
      return '50000000-0000-1111-2222-333333333333';
  }
}
