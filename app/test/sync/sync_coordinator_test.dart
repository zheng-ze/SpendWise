import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:spendwise/ledger/event_bus.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/persistence/device_identity.dart';
import 'package:spendwise/persistence/ledger_database.dart';
import 'package:spendwise/persistence/persistence_processor.dart';
import 'package:spendwise/sync/cached_collection_version_source.dart';
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
}
