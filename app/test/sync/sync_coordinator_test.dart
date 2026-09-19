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
import 'package:spendwise/sync/sync_backend_resolver.dart';
import 'package:spendwise/sync/sync_coordinator.dart';
import 'package:spendwise/sync/sync_e2e_key_provider.dart';
import 'package:spendwise/sync/sync_metadata_store.dart';
import 'package:spendwise/sync/sync_secret_keys.dart';
import 'package:spendwise/sync/sync_status.dart';
import 'package:sync/sync.dart';

import '../support/recording_ledger_store.dart';
import 'in_memory_secret_store.dart';

/// Unpadded base64url, matching this repo's on-the-wire envelope convention.
String _encodeKey(List<int> bytes) =>
    base64Url.encode(bytes).replaceAll('=', '');

Uint8List _freshKey() =>
    Uint8List.fromList(List<int>.generate(32, (index) => index));

/// Records outbound requests without touching the network, so the test can
/// prove assembly performed no backend I/O.
final class _RecordingHttpClient extends http.BaseClient {
  int requests = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    requests++;
    throw StateError('No network in SyncCoordinator tests.');
  }
}

/// Hand-written fake backend serving one stubbed pull page per collection,
/// one stubbed acknowledge outcome per collection, and a scriptable push
/// handler.
///
/// `pull` serves [pages] (or [failure]); `acknowledge` records and serves
/// [acknowledgeOutcomes] defaulting to success; `push` records every request
/// in [pushes] and delegates to [onPush], which each push test scripts.
/// `reconcile` throws because no coordinator test needs it. An optional
/// [failure] makes `pull` return a typed failure instead of a page.
final class _FakeSyncBackend implements SyncBackend {
  _FakeSyncBackend({
    Map<SyncCollection, PullResponse>? pages,
    this.failure,
    Map<SyncCollection, SyncOutcome<AcknowledgeResponse>>? acknowledgeOutcomes,
  }) : pages = Map<SyncCollection, PullResponse>.of(pages ?? const {}),
       acknowledgeOutcomes = acknowledgeOutcomes ?? const {};

  final Map<SyncCollection, PullResponse> pages;

  /// Mutable so a test can fail one call and succeed the next on the same
  /// coordinator (for example to prove the collection lock is not poisoned
  /// by a throwing first holder).
  SyncOutcome<PullResponse>? failure;
  final Map<SyncCollection, SyncOutcome<AcknowledgeResponse>>
  acknowledgeOutcomes;
  final List<PullRequest> pulls = [];
  final List<AcknowledgeRequest> acknowledges = [];
  final List<PushRequest> pushes = [];

  /// Scripted per-test push behavior. Unset means the test expects no push
  /// call: [push] throws instead of silently succeeding.
  Future<SyncOutcome<PushResponse>> Function(PushRequest request)? onPush;

  @override
  Future<SyncOutcome<PullResponse>> pull(
    SyncCredential credential,
    PullRequest request,
  ) async {
    pulls.add(request);
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
  ) => throw UnimplementedError(
    'Reconcile RPC is out of scope for coordinator tests.',
  );

  @override
  Future<SyncOutcome<AcknowledgeResponse>> acknowledge(
    SyncCredential credential,
    AcknowledgeRequest request,
  ) async {
    acknowledges.add(request);
    return acknowledgeOutcomes[request.collection] ??
        SyncSuccess<AcknowledgeResponse>(
          AcknowledgeResponse(<String, Object?>{}),
        );
  }
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

/// Builds a live entries envelope encrypted under [key], mirroring the
/// envelope-construction pattern in packages/sync's engine tests.
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

  /// Assembles a coordinator over fakes for pull-page tests: a stubbed
  /// backend, a pre-seeded version source, a real credential provider backed
  /// by an enrolled test credential, and a real engine whose staging store
  /// the test keeps a handle to.
  Future<SyncCoordinator> pullCoordinator({
    required SyncBackend backend,
    required SyncVersionSource versionSource,
    required SyncStagingStore staging,
    required Uint8List e2eKey,
    CollectionVersionReader? reader,
    CollectionVersionReader? versionReader,
  }) async {
    final id = await deviceID(db);
    await secrets.write(
      syncCredentialSecretKey,
      _credentialPayload(id, 'test-bearer'),
    );
    await secrets.write(syncE2EKeySecretKey, _encodeKey(e2eKey));
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
        secretStore: secrets,
      ),
      ledger: ledger,
      persistenceProcessor: processor,
      stagingStore: staging,
    );
  }

  /// Pins the duplicate/dominated-page contract: watermark and pending
  /// acknowledgement advance to [cursor], no vectors are recorded, and
  /// nothing reaches the ledger bus or the persistence store.
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

  /// Subscribes to the ledger bus, runs [work], then returns everything
  /// published while it ran.
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

  /// A drift-backed coordinator setup: the real [DriftLedgerStore], a real
  /// [DriftSyncStagingStore], and a cached version source plus readback
  /// verifier both reading the same real database, so pulled rows genuinely
  /// persist with their stamps and verify equal. The shared in-memory
  /// [ledger] (on the shared [bus]) fronts the store, exactly like production.
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
    // A manual clock: the barrier path never needs a timer to fire, and no
    // stray debounce can outlive the test's database close.
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
    // The processor must be started: otherwise publications never reach the
    // store and every barrier flush is a no-op over an empty queue.
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

  /// Seeds the holder account every drift-test entry references, through the
  /// ledger and [processor] so memory and the database agree before a pull.
  Future<void> seedDriftHolder(
    String accountID,
    PersistenceProcessor processor,
  ) async {
    ledger.addAccount(
      Account(id: accountID, name: 'holder', type: AccountType.cash),
    );
    await processor.flush();
  }

  /// An entry without a category (coherence only constrains present
  /// categories), so drift tests need no category seed.
  Entry driftEntry(String id, String sourceID, {String name = 'Coffee'}) =>
      Entry(
        id: id,
        date: DateTime.utc(2024, 3, 15),
        amount: Decimal.parse('-12.50'),
        name: name,
        sourceID: sourceID,
        includeInAnalysis: true,
      );

  /// Push-test assembly: a fake backend, an in-memory candidate reader and
  /// version source, and an enabled write gate, so pushCollection reaches
  /// the backend unless the test opts out with [enableWrites] false.
  Future<_PushSetup> pushSetup({
    _FakeSyncBackend? backend,
    bool enableWrites = true,
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
    );
    if (enableWrites) {
      await coordinator.metadataStore.setEnrollmentPhase(
        SyncEnrollmentPhase.reconciliationComplete,
      );
      await coordinator.metadataStore.setWriteEnabled(true);
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
      // Assembly is lazy: no secret reads, no backend I/O, no store start,
      // and an empty version cache until the run slice calls refresh().
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
        // The wiring check runs before any I/O: no secret reads, no backend
        // requests, and the store was never started.
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

      // The full reachable surface from outside: engine, backend,
      // versionSource, metadataStore, verifier, ledger,
      // persistenceProcessor, and status. None of these getters returns a
      // SecretStore, CredentialProvider, or DeviceCredential; the
      // credential provider is held privately with no getter, which this
      // file verifies by construction: there is simply no member to call.
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

      // The first pull carries no watermark yet.
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
        // The version lives only in the reader; the cache starts empty. The
        // page commits only if processPullPage refreshes the cache first.
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

        // The pulled row lands in memory with remote content, durably with
        // its pulled stamp, and the page advances with that vector recorded.
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

        // The pulled winner causally supersedes the local content, so the
        // local row is replaced and the pulled vector is acknowledged.
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

      // Neither side dominates: the conflict stages, the local content
      // stays put, and the page defers with the watermark held so the row
      // is retried instead of skipped.
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
      // The debounced edit sits in the store queue, unpublished to the
      // database: classification sees no version, the attempt's own barrier
      // flush lands it, and the retry folds it in.
      ledger.addEntry(driftEntry(rowID, holderID, name: 'Local'));
      hooked?.flushCalls = 0;

      await coordinator.processPullPage(SyncCollection.entries);

      // All three attempts ran their barrier flush (and never a post-apply
      // one): the first classified the row direct-apply and excluded it at
      // Stage 4, the next two folded it into a staged conflict. The local
      // content survived and the conflict staged durably.
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

        // The first attempt retried on the fence trip; the second ran clean
        // and the pulled row applied with its vector acknowledged. The hook
        // ran on both barrier flushes plus the post-apply flush.
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

        // The edit landed after the fence snapshot but before the commit
        // decision, so the first attempt retried and the page still applied.
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
      // Two new rows so the page takes the fold-in path with a two-input
      // reconcile per row, giving the hook its injection point.
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

      // The edit landed inside the fold-in awaits, so Stage 4 saw a dirty
      // fence, retried, and both rows applied on the clean pass.
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
          // Every barrier flush trips the fence again, so no attempt ever
          // runs clean.
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

        // Exactly three barrier flushes (one per attempt, never a post-apply
        // one), no throw, and nothing advanced: the next pull retries fresh.
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

      // Classification saw no version, the barrier window created one, and
      // the retry folded it in as a conflict instead of overwriting it.
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
      // The drifting row reads concurrent through classification, capture,
      // and encode, then drifted at the Stage-4 check, on every attempt: the
      // exclusion races instead of committing the surviving sibling, and the
      // budget exhausts into a defer.
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
      // Drift-backed with a started processor, so an applied batch would
      // genuinely persist, verify, and advance metadata: the watermark and
      // acknowledgement assertions below only hold because Stage 4 raced.
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

      // All three attempts ran their two refreshes and raced at Stage 4, so
      // neither remote change applied and nothing advanced.
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
        // Classification observes a concurrent local vector; every later read
        // observes a dominating one, simulating a local edit that lands and
        // flushes durably between classification and the fold-in encode.
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

        // The local envelope won the two-input reconcile (index 1), so nothing
        // was applied and the dominating local vector was never recorded as
        // pulled — while the page itself still finalized.
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

      // The conflict-free row applied and acknowledged; the concurrent row
      // staged with its local content intact; the page watermark advanced
      // over both.
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

      // The staged group survives a fresh store reload with both siblings,
      // and the conflict-free row applied and acknowledged alongside it.
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

      // A barrier failure is a hard stop for the page, not a throw: the
      // caller observes a quiet return with nothing advanced.
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
        // Reconcile decodes every input before grouping, so a decrypt throw
        // can never follow a staging: the abort-with-prior-staging case is a
        // grouping-loop throw instead. Two authenticated envelopes sharing
        // one vector with different content trip the engine's identity guard
        // after the earlier row already staged.
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

        // Nothing advanced, but the choke-point flush made the earlier
        // row's staged conflict durable: a fresh reload still sees it.
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
        // The readback observes only the passing row: the missing row fails
        // the whole batch even though its sibling verified.
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
      // The holder the pulled entries reference must exist in memory for the
      // apply to pass ledger invariants; only the readback is scripted.
      ledger.addAccount(
        Account(id: holderID, name: 'holder', type: AccountType.cash),
      );

      await coordinator.processPullPage(SyncCollection.entries);

      // Both rows applied in memory, but neither advanced: one failing row
      // blocks metadata for the whole batch.
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

      // Both collections were attempted: no short-circuit on failure.
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
      // The conflicting page stages and leaves a pending acknowledgement
      // for entries behind.
      await coordinator.processPullPage(SyncCollection.entries);
      expect(staging.pendingConflicts, hasLength(1));
      await coordinator.metadataStore.setPendingAcknowledgement(
        SyncCollection.categories,
        'cursor-categories',
      );

      await coordinator.recoverPendingAcknowledgements();

      // Entries keeps its pending checkpoint while its conflict is staged;
      // the clean collection still acknowledges.
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

      // Simulates a newer checkpoint landing (e.g. via processPullPage)
      // after this stale success was already in flight.
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

      await setup.coordinator.pushCollection(SyncCollection.entries);

      expect(setup.backend.pushes, hasLength(1));
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

      await setup.coordinator.pushCollection(SyncCollection.entries);

      expect(setup.backend.pushes, hasLength(1));
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

      await setup.coordinator.pushCollection(SyncCollection.entries);

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

      await setup.coordinator.pushCollection(SyncCollection.entries);

      expect(setup.backend.pushes, isEmpty);
    });

    test('a row without acknowledgement is eligible', () async {
      final setup = await pushSetup();
      setup.backend.onPush = _appliedPush;
      const rowID = '66666666-6666-6666-6666-666666666666';
      final stored = VersionVector(<String, int>{'dev': 1});
      await setup.seedRow(rowID, stored);

      await setup.coordinator.pushCollection(SyncCollection.entries);

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

      await setup.coordinator.pushCollection(SyncCollection.entries);

      expect(setup.backend.pushes, hasLength(1));
      expect(setup.backend.pushes.single.envelopes, hasLength(1));
      expect(
        setup.backend.pushes.single.envelopes.single.rowID,
        normalizedID(eligibleID),
      );
      // The dominated row's pre-existing acknowledgement is untouched; only
      // the eligible row's submitted vector is newly retired.
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

      await setup.coordinator.pushCollection(SyncCollection.entries);

      expect(setup.backend.pushes, hasLength(1));
      final envelope = setup.backend.pushes.single.envelopes.single;
      expect(envelope.lifecycle, SiblingLifecycle.tombstone);
      expect(await setup.coordinator.metadataStore.acknowledgedVectors(), {
        SyncRowID.of(SyncCollection.entries, rowID): stored,
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

      // Completing at all proves the inline recovery did not re-enter the
      // held collection lock: the public recovery would self-deadlock here.
      await setup.coordinator.pushCollection(SyncCollection.entries);

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
      // The cache starts empty; the row lives only in the reader.
      final cached = CachedCollectionVersionSource(reader);
      final coordinator = await pullCoordinator(
        backend: backend,
        versionSource: cached,
        staging: InMemorySyncStagingStore(),
        e2eKey: _freshKey(),
        versionReader: reader,
      );
      await coordinator.metadataStore.setEnrollmentPhase(
        SyncEnrollmentPhase.reconciliationComplete,
      );
      await coordinator.metadataStore.setWriteEnabled(true);
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

      await coordinator.pushCollection(SyncCollection.entries);

      // Encode observed the row only because refresh ran first: without it
      // encode throws SyncUntrackedRowError.
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

      await setup.coordinator.pushCollection(SyncCollection.entries);

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

      await setup.coordinator.pushCollection(SyncCollection.entries);

      expect(backend.pushes, isEmpty);
      expect(
        await setup.coordinator.metadataStore.pendingAcknowledgement(
          SyncCollection.entries,
        ),
        'cursor-conflict',
      );

      setup.staging.resolve(setup.staging.pendingConflicts.single);
      await setup.coordinator.pushCollection(SyncCollection.entries);

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

        await setup.coordinator.pushCollection(SyncCollection.entries);

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

      await setup.coordinator.pushCollection(SyncCollection.entries);

      expect(await setup.coordinator.metadataStore.acknowledgedVectors(), {
        SyncRowID.of(SyncCollection.entries, rowID): stored,
      });
    });

    test('rejected leaves the row eligible for the next push', () async {
      final setup = await pushSetup();
      setup.backend.onPush = (request) async => SyncSuccess<PushResponse>(
        _pushRowsResponse(request.envelopes, status: 'rejected'),
      );
      await setup.seedRow(
        '20202020-2020-2020-2020-202020202020',
        VersionVector(<String, int>{'dev': 1}),
      );

      await setup.coordinator.pushCollection(SyncCollection.entries);
      await setup.coordinator.pushCollection(SyncCollection.entries);

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

      await setup.coordinator.pushCollection(SyncCollection.entries);

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

      await setup.coordinator.pushCollection(SyncCollection.entries);

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
        // A concurrent refresh lands a newer vector after encode: the
        // commit must still retire the encode-time-captured vector.
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

      await setup.coordinator.pushCollection(SyncCollection.entries);

      expect(await setup.coordinator.metadataStore.acknowledgedVectors(), {
        row: submitted,
      });
    });
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

        // Rejected rows stay eligible, so both serialized holders submitted.
        expect(setup.backend.pushes, hasLength(2));
      },
    );
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
      await setup.coordinator.pushCollection(
        SyncCollection.entries,
        writeProof: 'proof-1',
      );

      expect(setup.backend.pushes, hasLength(2));
      expect(setup.backend.pushes[0].writeProof, isNull);
      expect(setup.backend.pushes[1].writeProof, 'proof-1');
    });
  });
}

/// Builds a push wire response marking every submitted envelope with
/// [status] under its own sibling ID. The resulting frontier defaults to a
/// vector distinct from every submitted vector, so a test proves the commit
/// retires the encode-time-captured vector, never the response frontier.
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

/// A push handler answering every submission as applied under the submitted
/// sibling IDs.
Future<SyncOutcome<PushResponse>> _appliedPush(PushRequest request) async =>
    SyncSuccess<PushResponse>(_pushRowsResponse(request.envelopes));

/// One push-test assembly: the coordinator under test with handles to its
/// scriptable backend, candidate reader, encode version source, and staging
/// store.
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

  /// Seeds one local entries row across the ledger, the candidate reader,
  /// and the encode version source, with an optional pre-existing
  /// acknowledgement. A row omitted from the ledger ([inLedger] false)
  /// pushes as a tombstone delete.
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

/// One drift-backed coordinator assembly with handles to the spies a race
/// test installs around it.
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

  /// The device ID backing [deviceID] for the setup's database: local version
  /// bumps carry this counter.
  final String device;
  final LedgerStore effectiveStore;
  final SyncVersionSource effectiveVersions;
}

/// [LedgerStore] decorator running a one-shot or recurring hook before
/// delegating a barrier flush, so a test can land a local edit inside the
/// attempt's own persistence window.
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

/// [SyncVersionSource] decorator running a hook around refresh, so a test
/// can land a local edit inside the attempt's refresh await window.
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

/// [SyncEngine] that runs a hook before delegating a two-input (fold-in)
/// reconcile, so a test can land a local edit after reconciliation inputs
/// are decided but before the commit decision.
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

/// [SyncVersionSource] serving one scripted vector on its first read and a
/// different one afterwards, simulating a local edit that lands (and flushes
/// durably) between classification and the fold-in encode.
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

/// [SyncVersionSource] replaying a per-row read script cyclically, so a test
/// can script different vectors for classification, encode, and the Stage-4
/// check within one attempt. Rows without a script always read null.
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

/// [CollectionVersionReader] serving a fixed map, so a test can script what
/// the post-flush readback observes independently of the version source used
/// for classification.
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

/// [SyncStagingStore] decorator whose flush always throws, proving a
/// staging-durability failure propagates and blocks page metadata.
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

/// Hands out timers the store arms for its debounce and retry backoff, so no
/// real time elapses and no stray timer can outlive a test's database close.
/// Flushes never need a timer to fire: [DriftLedgerStore.flushNow] saves
/// directly and cancels the armed debounce.
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
