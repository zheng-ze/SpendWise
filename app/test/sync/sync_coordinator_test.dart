import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:spendwise/ledger/event_bus.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/persistence/device_identity.dart';
import 'package:spendwise/persistence/ledger_database.dart'
    hide Account, SubPocket, Entry, Budget;
import 'package:spendwise/persistence/persistence_processor.dart';
import 'package:spendwise/sync/cached_collection_version_source.dart';
import 'package:spendwise/sync/collection_version_reader.dart';
import 'package:spendwise/sync/credential_provider.dart';
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

/// Hand-written fake backend serving one stubbed pull page per collection.
///
/// Only `pull` has real behavior; the other three methods throw because no
/// pull-page test needs them. An optional [failure] makes `pull` return a
/// typed failure instead of a page.
final class _FakePullBackend implements SyncBackend {
  _FakePullBackend({Map<SyncCollection, PullResponse>? pages, this.failure})
    : pages = pages ?? const {};

  final Map<SyncCollection, PullResponse> pages;
  final SyncOutcome<PullResponse>? failure;
  final List<PullRequest> pulls = [];

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
  ) => throw UnimplementedError('Push is out of scope for pull-page tests.');

  @override
  Future<SyncOutcome<ReconcileResponse>> reconcile(
    SyncCredential credential,
    ReconcileRequest request,
  ) => throw UnimplementedError(
    'Reconcile RPC is out of scope for pull-page tests.',
  );

  @override
  Future<SyncOutcome<AcknowledgeResponse>> acknowledge(
    SyncCredential credential,
    AcknowledgeRequest request,
  ) => throw UnimplementedError(
    'Acknowledge RPC is out of scope for pull-page tests.',
  );
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
}) async {
  const cipher = SyncCipher();
  const codec = PayloadCodec();
  const collection = SyncCollection.entries;
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
    required InMemorySyncStagingStore staging,
    required Uint8List e2eKey,
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
      metadataStore: SyncMetadataStore(db),
      verifier: PostFlushReadbackVerifier(DriftCollectionVersionReader(db)),
      credentialProvider: CredentialProvider(
        database: db,
        secretStore: secrets,
      ),
      ledger: ledger,
      persistenceProcessor: processor,
    );
  }

  /// Pins the duplicate/dominated-page contract: watermark and pending
  /// acknowledgement advance to [cursor], no vectors are recorded, and
  /// nothing reaches the ledger bus or the persistence store.
  Future<void> expectDuplicatePageCommit(
    SyncCoordinator coordinator,
    _FakePullBackend backend,
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
      final backend = _FakePullBackend(
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
        final backend = _FakePullBackend(
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
      final backend = _FakePullBackend(
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
        final backend = _FakePullBackend(
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

  group('processPullPage: new and conflicting pages (TS2, TS3)', () {
    test('a genuinely new row commits nothing and publishes nothing', () async {
      const rowID = '55555555-5555-5555-5555-555555555555';
      final key = _freshKey();
      final envelope = await _pullEnvelope(
        key: key,
        rowID: rowID,
        version: VersionVector(<String, int>{'deva': 1}),
        change: UpsertEntry(_pullTestEntry(rowID)),
      );
      final backend = _FakePullBackend(
        pages: {
          SyncCollection.entries: _pullPage(<SyncEnvelope>[
            envelope,
          ], 'cursor-5'),
        },
      );
      final staging = InMemorySyncStagingStore();
      final coordinator = await pullCoordinator(
        backend: backend,
        // No stored version: the row was never seen locally.
        versionSource: InMemorySyncVersionSource(),
        staging: staging,
        e2eKey: key,
      );

      final publications = await collectPublications(
        () => coordinator.processPullPage(SyncCollection.entries),
      );

      expect(backend.pulls, hasLength(1));
      final snapshot = await coordinator.metadataStore.snapshot();
      expect(snapshot.watermarks[SyncCollection.entries], isNull);
      expect(
        await coordinator.metadataStore.pendingAcknowledgement(
          SyncCollection.entries,
        ),
        isNull,
      );
      expect(publications, isEmpty);
      expect(store.calls, isEmpty);
      expect(store.enqueuedBatches, isEmpty);
      expect(staging.pendingConflicts, isEmpty);
    });

    test('a stored vector that does not dominate the pulled one commits '
        'nothing (TS3)', () async {
      const rowID = '66666666-6666-6666-6666-666666666666';
      final key = _freshKey();
      final envelope = await _pullEnvelope(
        key: key,
        rowID: rowID,
        version: VersionVector(<String, int>{'devb': 1}),
        change: UpsertEntry(_pullTestEntry(rowID)),
      );
      final backend = _FakePullBackend(
        pages: {
          SyncCollection.entries: _pullPage(<SyncEnvelope>[
            envelope,
          ], 'cursor-6'),
        },
      );
      final staging = InMemorySyncStagingStore();
      final versions = InMemorySyncVersionSource(<SyncRowID, RowVersion>{
        // Concurrent with the pulled vector: neither dominates the other.
        SyncRowID.of(SyncCollection.entries, rowID): RowVersion(
          versionVector: VersionVector(<String, int>{'deva': 1}),
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

      final snapshot = await coordinator.metadataStore.snapshot();
      expect(snapshot.watermarks[SyncCollection.entries], isNull);
      expect(
        await coordinator.metadataStore.pendingAcknowledgement(
          SyncCollection.entries,
        ),
        isNull,
      );
      expect(publications, isEmpty);
      expect(store.calls, isEmpty);
      expect(store.enqueuedBatches, isEmpty);
    });

    test(
      'a staged conflict commits no watermark but leaves the staged group',
      () async {
        const rowID = '77777777-7777-7777-7777-777777777777';
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
        final backend = _FakePullBackend(
          pages: {
            SyncCollection.entries: _pullPage(<SyncEnvelope>[
              first,
              second,
            ], 'cursor-7'),
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

        final snapshot = await coordinator.metadataStore.snapshot();
        expect(snapshot.watermarks[SyncCollection.entries], isNull);
        expect(
          await coordinator.metadataStore.pendingAcknowledgement(
            SyncCollection.entries,
          ),
          isNull,
        );
        expect(publications, isEmpty);
        expect(store.calls, isEmpty);
        expect(store.enqueuedBatches, isEmpty);
        // The engine's own conflict staging still stands: forward progress
        // for the later conflict-resolution slice.
        expect(staging.pendingConflicts, hasLength(1));
        expect(
          staging.pendingConflicts.single.collection,
          SyncCollection.entries,
        );
      },
    );

    test('a failed pull throws without committing anything', () async {
      final key = _freshKey();
      final backend = _FakePullBackend(
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
  });
}
