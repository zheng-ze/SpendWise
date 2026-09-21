import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ledger/event_bus.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/persistence/device_identity.dart';
import 'package:spendwise/persistence/ledger_database.dart'
    hide Account, SubPocket, Entry, Budget;
import 'package:spendwise/persistence/persistence_processor.dart';
import 'package:spendwise/sync/collection_version_reader.dart';
import 'package:spendwise/sync/credential_provider.dart';
import 'package:spendwise/sync/enrollment_snapshot_publisher.dart';
import 'package:spendwise/sync/post_flush_readback_verifier.dart';
import 'package:spendwise/sync/secret_store.dart';
import 'package:spendwise/sync/sync_coordinator.dart';
import 'package:spendwise/sync/sync_e2e_key_provider.dart';
import 'package:spendwise/sync/sync_metadata_store.dart';
import 'package:spendwise/sync/sync_secret_keys.dart';
import 'package:sync/sync.dart';

import '../support/recording_ledger_store.dart';
import 'in_memory_secret_store.dart';

/// One distinct seeded row ID per collection, so a test can make any subset
/// of collections non-noop while keeping the rows distinguishable.
String _rowID(SyncCollection collection) {
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

/// Hand-written fake backend in the style of the coordinator tests: `push`
/// records every request and delegates to a scripted [onPush] handler, while
/// `acknowledge` records and serves [acknowledgeOutcomes] defaulting to
/// success. `pull` and `reconcile` throw because the push path never calls
/// them.
final class _ScriptedPushBackend implements SyncBackend {
  final List<PushRequest> pushes = [];
  final List<AcknowledgeRequest> acknowledges = [];
  final Map<SyncCollection, SyncOutcome<AcknowledgeResponse>>
  acknowledgeOutcomes = {};

  /// Scripted per-test push behavior.
  Future<SyncOutcome<PushResponse>> Function(PushRequest request)? onPush;

  @override
  Future<SyncOutcome<PullResponse>> pull(
    SyncCredential credential,
    PullRequest request,
  ) => throw UnimplementedError('Push tests never pull.');

  @override
  Future<SyncOutcome<PushResponse>> push(
    SyncCredential credential,
    PushRequest request,
  ) async {
    pushes.add(request);
    final handler = onPush;
    if (handler == null) throw StateError('No stubbed push outcome.');
    return handler(request);
  }

  @override
  Future<SyncOutcome<ReconcileResponse>> reconcile(
    SyncCredential credential,
    ReconcileRequest request,
  ) => throw UnimplementedError('Push tests never reconcile.');

  @override
  Future<SyncOutcome<AcknowledgeResponse>> acknowledge(
    SyncCredential credential,
    AcknowledgeRequest request,
  ) async {
    acknowledges.add(request);
    return acknowledgeOutcomes[request.collection] ??
        SyncSuccess<AcknowledgeResponse>(AcknowledgeResponse(const {}));
  }
}

/// [CollectionVersionReader] decorator logging every collection the
/// coordinator reads, so a test can prove the publisher visited collections
/// in order — including [PushNoop] collections that make no backend call.
final class _RecordingReader implements CollectionVersionReader {
  _RecordingReader(this.inner);

  final InMemoryCollectionVersionReader inner;
  final List<SyncCollection> calls = [];

  void upsert(SyncRowID rowID, RowVersion version) =>
      inner.upsert(rowID, version);

  @override
  Future<Map<SyncRowID, RowVersion>> readRowVersions(
    SyncCollection collection,
  ) async {
    calls.add(collection);
    return inner.readRowVersions(collection);
  }
}

/// [SecretStore] decorator logging reads and deletes into [events], so a
/// test can prove the proof read happened before any push.
final class _OrderedSecretStore implements SecretStore {
  _OrderedSecretStore(this.inner, this.events);

  final InMemorySecretStore inner;
  final List<String> events;

  @override
  Future<String?> read(String key) async {
    events.add('read:$key');
    return inner.read(key);
  }

  @override
  Future<void> write(String key, String value) => inner.write(key, value);

  @override
  Future<void> delete(String key) async {
    events.add('delete:$key');
    return inner.delete(key);
  }
}

/// Builds a push wire response marking every submitted envelope [status]
/// under its own sibling ID.
PushResponse _pushRowsResponse(
  List<SyncEnvelope> submitted, {
  String status = 'applied',
}) => PushResponse(<String, Object?>{
  'rows': [
    for (final envelope in submitted)
      <String, Object?>{
        'row_id': envelope.rowID,
        'collection': envelope.collection.wireName,
        'sibling_id': envelope.siblingID,
        'status': status,
        if (status != 'rejected')
          'version_vector': envelope.versionVector.toWireCounters(),
      },
  ],
});

/// A push handler answering every submission as applied under the submitted
/// sibling IDs.
Future<SyncOutcome<PushResponse>> _appliedPush(PushRequest request) async =>
    SyncSuccess<PushResponse>(_pushRowsResponse(request.envelopes));

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
  late InMemorySecretStore coordinatorSecrets;
  late InMemorySecretStore proofSecrets;
  late RecordingLedgerStore store;
  late EventBus bus;
  late Ledger ledger;
  late PersistenceProcessor processor;

  setUp(() {
    db = LedgerDatabase(NativeDatabase.memory());
    coordinatorSecrets = InMemorySecretStore();
    proofSecrets = InMemorySecretStore();
    store = RecordingLedgerStore();
    bus = EventBus();
    ledger = Ledger(bus: bus);
    processor = PersistenceProcessor(store: store, bus: bus);
  });

  tearDown(() async {
    await bus.dispose();
    ledger.dispose();
    await db.close();
  });

  /// Assembles a publisher over a real coordinator with a scriptable backend,
  /// a recording candidate reader, and an enabled write gate (unless
  /// [enableWrites] is false), mirroring the coordinator tests' push setup.
  /// The coordinator's credentials live in [coordinatorSecrets]; the write
  /// proof under test lives in [proofSecrets], so coordinator I/O never
  /// pollutes the proof accounting.
  Future<({SyncCoordinator coordinator, _ScriptedPushBackend backend})>
  publishSetup({
    _ScriptedPushBackend? backend,
    bool enableWrites = true,
  }) async {
    final effective = backend ?? _ScriptedPushBackend();
    final reader = _RecordingReader(InMemoryCollectionVersionReader());
    final versions = InMemorySyncVersionSource();
    final staging = InMemorySyncStagingStore();
    final id = await deviceID(db);
    await coordinatorSecrets.write(
      syncCredentialSecretKey,
      _credentialPayload(id, 'test-bearer'),
    );
    await coordinatorSecrets.write(
      syncE2EKeySecretKey,
      base64Url.encode(List<int>.generate(32, (index) => index)),
    );
    final coordinator = SyncCoordinator.forTesting(
      engine: SyncEngine(
        userID: id,
        keyAccessor: SyncE2EKeyProvider(secretStore: coordinatorSecrets)
            .accessor,
        stagingStore: staging,
      ),
      backend: effective,
      versionSource: versions,
      versionReader: reader,
      metadataStore: SyncMetadataStore(db),
      verifier: PostFlushReadbackVerifier(DriftCollectionVersionReader(db)),
      credentialProvider: CredentialProvider(
        database: db,
        secretStore: coordinatorSecrets,
      ),
      ledger: ledger,
      persistenceProcessor: processor,
      stagingStore: staging,
    );
    if (enableWrites) {
      await coordinator.metadataStore.setEnrollmentPhase(
        SyncEnrollmentPhase.reconciliationComplete,
      );
      await coordinator.metadataStore.setWriteEnabled(true);
    }
    return (coordinator: coordinator, backend: effective);
  }

  EnrollmentSnapshotPublisher publisherOf(SyncCoordinator coordinator) =>
      EnrollmentSnapshotPublisher(
        coordinator: coordinator,
        secretStore: proofSecrets,
      );

  /// Seeds one tombstone row for [collection]: absent from the ledger, it
  /// pushes as a tombstone delete, so no per-collection ledger seeding is
  /// needed to make the collection non-noop.
  void seedTombstone(
    _RecordingReader reader,
    InMemorySyncVersionSource versions,
    SyncCollection collection,
  ) {
    final row = SyncRowID.of(collection, _rowID(collection));
    final version = RowVersion(
      versionVector: VersionVector(<String, int>{'dev': 1}),
      lifecycle: SiblingLifecycle.tombstone,
    );
    reader.upsert(row, version);
    versions.upsert(row, version);
  }

  int proofReads() =>
      proofSecrets.reads.where((key) => key == syncWriteProofSecretKey).length;

  // TS1: sequential first-selection across the fixed enum order.

  test(
    'all noop returns success in enum order with the proof untouched',
    () async {
      final setup = await publishSetup();
      setup.backend.onPush = _appliedPush;
      await proofSecrets.write(syncWriteProofSecretKey, 'proof-1');
      final publisher = publisherOf(setup.coordinator);

      final result = await publisher.publish();

      expect(result, isA<EnrollmentSnapshotPublished>());
      final reader = setup.coordinator.versionReader as _RecordingReader;
      expect(reader.calls, SyncCollection.values);
      expect(setup.backend.pushes, isEmpty);
      expect(proofReads(), 1);
      expect(proofSecrets.deletes, isEmpty);
      expect(await proofSecrets.read(syncWriteProofSecretKey), 'proof-1');
    },
  );

  test(
    'first non-noop at moneySources takes the proof; later pushes get null',
    () async {
      final setup = await publishSetup();
      setup.backend.onPush = _appliedPush;
      final reader = setup.coordinator.versionReader as _RecordingReader;
      seedTombstone(
        reader,
        setup.coordinator.versionSource as InMemorySyncVersionSource,
        SyncCollection.moneySources,
      );
      seedTombstone(
        reader,
        setup.coordinator.versionSource as InMemorySyncVersionSource,
        SyncCollection.budgets,
      );
      await proofSecrets.write(syncWriteProofSecretKey, 'proof-1');
      final publisher = publisherOf(setup.coordinator);

      final result = await publisher.publish();

      expect(result, isA<EnrollmentSnapshotPublished>());
      expect(reader.calls, SyncCollection.values);
      expect(setup.backend.pushes, hasLength(2));
      expect(setup.backend.pushes[0].writeProof, 'proof-1');
      expect(setup.backend.pushes[1].writeProof, isNull);
      expect(proofSecrets.deletes, [syncWriteProofSecretKey]);
    },
  );

  test(
    'first non-noop at categories takes the proof; later pushes get null',
    () async {
      final setup = await publishSetup();
      setup.backend.onPush = _appliedPush;
      final reader = setup.coordinator.versionReader as _RecordingReader;
      final versions =
          setup.coordinator.versionSource as InMemorySyncVersionSource;
      seedTombstone(reader, versions, SyncCollection.categories);
      seedTombstone(reader, versions, SyncCollection.plans);
      await proofSecrets.write(syncWriteProofSecretKey, 'proof-1');
      final publisher = publisherOf(setup.coordinator);

      final result = await publisher.publish();

      expect(result, isA<EnrollmentSnapshotPublished>());
      expect(reader.calls, SyncCollection.values);
      expect(setup.backend.pushes, hasLength(2));
      expect(setup.backend.pushes[0].writeProof, 'proof-1');
      expect(setup.backend.pushes[1].writeProof, isNull);
      expect(proofSecrets.deletes, [syncWriteProofSecretKey]);
    },
  );

  test(
    'a missing proof reaches the first push as null with no delete',
    () async {
      final setup = await publishSetup();
      setup.backend.onPush = _appliedPush;
      final reader = setup.coordinator.versionReader as _RecordingReader;
      seedTombstone(
        reader,
        setup.coordinator.versionSource as InMemorySyncVersionSource,
        SyncCollection.entries,
      );
      final publisher = publisherOf(setup.coordinator);

      final result = await publisher.publish();

      expect(result, isA<EnrollmentSnapshotPublished>());
      expect(setup.backend.pushes, hasLength(1));
      expect(setup.backend.pushes.single.writeProof, isNull);
      expect(proofSecrets.deletes, isEmpty);
    },
  );

  // TS2: single read, delete-on-confirmation, delete-failure propagation.

  test(
    'the proof is read once before any push and deleted after confirmation',
    () async {
      final events = <String>[];
      final ordered = _OrderedSecretStore(proofSecrets, events);
      final setup = await publishSetup();
      setup.backend.onPush = (request) async {
        events.add('push:${request.envelopes.single.collection.name}');
        return _appliedPush(request);
      };
      final reader = setup.coordinator.versionReader as _RecordingReader;
      final versions =
          setup.coordinator.versionSource as InMemorySyncVersionSource;
      seedTombstone(reader, versions, SyncCollection.entries);
      seedTombstone(reader, versions, SyncCollection.plans);
      await proofSecrets.write(syncWriteProofSecretKey, 'proof-1');
      final publisher = EnrollmentSnapshotPublisher(
        coordinator: setup.coordinator,
        secretStore: ordered,
      );

      final result = await publisher.publish();

      expect(result, isA<EnrollmentSnapshotPublished>());
      expect(events, [
        'read:$syncWriteProofSecretKey',
        'push:entries',
        'delete:$syncWriteProofSecretKey',
        'push:plans',
      ]);
    },
  );

  test('unresolved rows delete the proof once and stop the run', () async {
    final setup = await publishSetup();
    setup.backend.onPush = (request) async => SyncSuccess<PushResponse>(
      _pushRowsResponse(request.envelopes, status: 'rejected'),
    );
    final reader = setup.coordinator.versionReader as _RecordingReader;
    final versions =
        setup.coordinator.versionSource as InMemorySyncVersionSource;
    seedTombstone(reader, versions, SyncCollection.entries);
    seedTombstone(reader, versions, SyncCollection.plans);
    await proofSecrets.write(syncWriteProofSecretKey, 'proof-1');
    final publisher = publisherOf(setup.coordinator);

    final result = await publisher.publish();

    expect(result, isA<EnrollmentSnapshotPending>());
    final pending = result as EnrollmentSnapshotPending;
    expect(pending.collection, SyncCollection.entries);
    expect(pending.result, isA<PushUnresolvedRows>());
    expect(reader.calls, [SyncCollection.moneySources, SyncCollection.entries]);
    expect(setup.backend.pushes, hasLength(1));
    expect(proofSecrets.deletes, [syncWriteProofSecretKey]);
    expect(await proofSecrets.read(syncWriteProofSecretKey), isNull);
  });

  test('a delete failure propagates instead of reporting success', () async {
    final setup = await publishSetup();
    setup.backend.onPush = _appliedPush;
    final reader = setup.coordinator.versionReader as _RecordingReader;
    seedTombstone(
      reader,
      setup.coordinator.versionSource as InMemorySyncVersionSource,
      SyncCollection.entries,
    );
    await proofSecrets.write(syncWriteProofSecretKey, 'proof-1');
    proofSecrets.deleteFailure = const SecretStoreException();
    final publisher = publisherOf(setup.coordinator);

    await expectLater(
      publisher.publish(),
      throwsA(isA<SecretStoreException>()),
    );
    expect(proofSecrets.deletes, [syncWriteProofSecretKey]);
    expect(await proofSecrets.read(syncWriteProofSecretKey), 'proof-1');
  });

  // TS3: pending outcomes stop the run; retries resupply or withhold.

  test('deferred keeps the proof and the retry resupplies it to the same collection', () async {
    final backend = _ScriptedPushBackend();
    final setup = await publishSetup(backend: backend);
    backend.onPush = _appliedPush;
    final reader = setup.coordinator.versionReader as _RecordingReader;
    final versions =
        setup.coordinator.versionSource as InMemorySyncVersionSource;
    seedTombstone(reader, versions, SyncCollection.entries);
    seedTombstone(reader, versions, SyncCollection.plans);
    await setup.coordinator.metadataStore.setPendingAcknowledgement(
      SyncCollection.entries,
      'cursor-deferred',
    );
    backend.acknowledgeOutcomes[SyncCollection.entries] =
        const NetworkUnavailable<AcknowledgeResponse>(message: 'down');
    await proofSecrets.write(syncWriteProofSecretKey, 'proof-1');
    final publisher = publisherOf(setup.coordinator);

    final first = await publisher.publish();

    expect(first, isA<EnrollmentSnapshotPending>());
    final pending = first as EnrollmentSnapshotPending;
    expect(pending.collection, SyncCollection.entries);
    expect(pending.result, isA<PushDeferred>());
    expect(reader.calls, [SyncCollection.moneySources]);
    expect(backend.acknowledges.map((request) => request.collection), [
      SyncCollection.entries,
    ]);
    expect(backend.pushes, isEmpty);
    expect(proofSecrets.deletes, isEmpty);

    backend.acknowledgeOutcomes.remove(SyncCollection.entries);
    reader.calls.clear();

    final second = await publisher.publish();

    expect(second, isA<EnrollmentSnapshotPublished>());
    expect(backend.pushes, hasLength(2));
    expect(backend.pushes[0].writeProof, 'proof-1');
    expect(backend.pushes[1].writeProof, isNull);
    expect(proofReads(), 2);
    expect(proofSecrets.deletes, [syncWriteProofSecretKey]);
  });

  test('unresolved deletes the proof and the retry passes null to the same collection', () async {
    final setup = await publishSetup();
    var unresolved = true;
    setup.backend.onPush = (request) async => unresolved
        ? SyncSuccess<PushResponse>(
            _pushRowsResponse(request.envelopes, status: 'rejected'),
          )
        : _appliedPush(request);
    final reader = setup.coordinator.versionReader as _RecordingReader;
    final versions =
        setup.coordinator.versionSource as InMemorySyncVersionSource;
    seedTombstone(reader, versions, SyncCollection.entries);
    seedTombstone(reader, versions, SyncCollection.plans);
    await proofSecrets.write(syncWriteProofSecretKey, 'proof-1');
    final publisher = publisherOf(setup.coordinator);

    final first = await publisher.publish();

    expect(first, isA<EnrollmentSnapshotPending>());
    expect(
      (first as EnrollmentSnapshotPending).collection,
      SyncCollection.entries,
    );
    expect(proofSecrets.deletes, [syncWriteProofSecretKey]);

    unresolved = false;
    reader.calls.clear();

    final second = await publisher.publish();

    expect(second, isA<EnrollmentSnapshotPublished>());
    expect(reader.calls, SyncCollection.values);
    expect(setup.backend.pushes, hasLength(3));
    expect(setup.backend.pushes[0].writeProof, 'proof-1');
    expect(setup.backend.pushes[1].writeProof, isNull);
    expect(setup.backend.pushes[2].writeProof, isNull);
    expect(proofReads(), 2);
    expect(proofSecrets.deletes, [syncWriteProofSecretKey]);
  });

  test(
    'a retry stays on the pending collection until it resolves terminally',
    () async {
      final backend = _ScriptedPushBackend();
      final setup = await publishSetup(backend: backend);
      backend.onPush = _appliedPush;
      final reader = setup.coordinator.versionReader as _RecordingReader;
      final versions =
          setup.coordinator.versionSource as InMemorySyncVersionSource;
      seedTombstone(reader, versions, SyncCollection.entries);
      seedTombstone(reader, versions, SyncCollection.plans);
      await setup.coordinator.metadataStore.setPendingAcknowledgement(
        SyncCollection.entries,
        'cursor-deferred',
      );
      backend.acknowledgeOutcomes[SyncCollection.entries] =
          const NetworkUnavailable<AcknowledgeResponse>(message: 'down');
      await proofSecrets.write(syncWriteProofSecretKey, 'proof-1');
      final publisher = publisherOf(setup.coordinator);

      final first = await publisher.publish();
      expect(first, isA<EnrollmentSnapshotPending>());
      reader.calls.clear();

      final second = await publisher.publish();

      expect(second, isA<EnrollmentSnapshotPending>());
      expect(
        (second as EnrollmentSnapshotPending).collection,
        SyncCollection.entries,
      );
      expect(reader.calls, [SyncCollection.moneySources]);
      expect(backend.acknowledges.map((request) => request.collection), [
        SyncCollection.entries,
        SyncCollection.entries,
      ]);
      expect(backend.pushes, isEmpty);

      backend.acknowledgeOutcomes.remove(SyncCollection.entries);
      reader.calls.clear();

      final third = await publisher.publish();

      expect(third, isA<EnrollmentSnapshotPublished>());
      expect(reader.calls, SyncCollection.values);
    },
  );

  // TS4: failure propagation without proof deletion or success.

  test(
    'a closed write gate throws StateError with no proof deletion',
    () async {
      final setup = await publishSetup(enableWrites: false);
      setup.backend.onPush = _appliedPush;
      final reader = setup.coordinator.versionReader as _RecordingReader;
      seedTombstone(
        reader,
        setup.coordinator.versionSource as InMemorySyncVersionSource,
        SyncCollection.entries,
      );
      await proofSecrets.write(syncWriteProofSecretKey, 'proof-1');
      final publisher = publisherOf(setup.coordinator);

      await expectLater(publisher.publish(), throwsA(isA<StateError>()));
      expect(setup.backend.pushes, isEmpty);
      expect(proofSecrets.deletes, isEmpty);
      expect(await proofSecrets.read(syncWriteProofSecretKey), 'proof-1');
    },
  );

  test(
    'a backend failure on the proof-bearing push keeps the proof stored',
    () async {
      final setup = await publishSetup();
      setup.backend.onPush = (request) async =>
          const NetworkUnavailable<PushResponse>(message: 'down');
      final reader = setup.coordinator.versionReader as _RecordingReader;
      seedTombstone(
        reader,
        setup.coordinator.versionSource as InMemorySyncVersionSource,
        SyncCollection.entries,
      );
      await proofSecrets.write(syncWriteProofSecretKey, 'proof-1');
      final publisher = publisherOf(setup.coordinator);

      await expectLater(publisher.publish(), throwsA(isA<StateError>()));
      expect(setup.backend.pushes, hasLength(1));
      expect(setup.backend.pushes.single.writeProof, 'proof-1');
      expect(proofSecrets.deletes, isEmpty);
      expect(await proofSecrets.read(syncWriteProofSecretKey), 'proof-1');
    },
  );

  test('a proof read failure propagates before any push call', () async {
    final setup = await publishSetup();
    setup.backend.onPush = _appliedPush;
    final reader = setup.coordinator.versionReader as _RecordingReader;
    seedTombstone(
      reader,
      setup.coordinator.versionSource as InMemorySyncVersionSource,
      SyncCollection.entries,
    );
    proofSecrets.readFailure = const SecretStoreException();
    final publisher = publisherOf(setup.coordinator);

    await expectLater(
      publisher.publish(),
      throwsA(isA<SecretStoreException>()),
    );
    expect(setup.backend.pushes, isEmpty);
    expect(reader.calls, isEmpty);
  });

  test('two concurrent publish() calls on the same instance never both submit the proof', () async {
    // A rejected row stays an eligible candidate for the coordinator's own
    // fresh recomputation on retry (unlike an acknowledged one), so a
    // second concurrent call can genuinely reach a real backend.push()
    // call for the same row with a second (by then stale) writeProof
    // unless EnrollmentSnapshotPublisher itself serializes concurrent
    // publish() calls.
    final setup = await publishSetup();
    final reader = setup.coordinator.versionReader as _RecordingReader;
    seedTombstone(
      reader,
      setup.coordinator.versionSource as InMemorySyncVersionSource,
      SyncCollection.moneySources,
    );
    var pushCount = 0;
    final blockFirstPush = Completer<void>();
    final firstPushStarted = Completer<void>();
    setup.backend.onPush = (request) async {
      pushCount += 1;
      if (pushCount == 1) {
        firstPushStarted.complete();
        await blockFirstPush.future;
        return SyncSuccess<PushResponse>(
          _pushRowsResponse(request.envelopes, status: 'rejected'),
        );
      }
      return _appliedPush(request);
    };
    await proofSecrets.write(syncWriteProofSecretKey, 'proof-1');
    final publisher = publisherOf(setup.coordinator);

    final first = publisher.publish();
    await firstPushStarted.future;
    final second = publisher.publish();
    blockFirstPush.complete();
    await Future.wait([first, second]);

    final proofBearingPushes = setup.backend.pushes.where(
      (request) => request.writeProof != null,
    );
    expect(proofBearingPushes, hasLength(1));
  });
}
