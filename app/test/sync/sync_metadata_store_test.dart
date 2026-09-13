import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sync/sync.dart';
import 'package:spendwise/persistence/ledger_database.dart';
import 'package:spendwise/sync/sync_metadata_store.dart';

void main() {
  late LedgerDatabase db;
  late SyncMetadataStore store;

  setUp(() async {
    db = LedgerDatabase(NativeDatabase.memory());
    store = SyncMetadataStore(db);
  });

  tearDown(() async {
    await db.close();
  });

  // SyncRowID.of is not a const factory, so these are plain top-level fields.
  final entryRowE1 = SyncRowID.of(SyncCollection.entries, 'e1');
  final entryRowE2 = SyncRowID.of(SyncCollection.entries, 'e2');
  final categoryRowE1 = SyncRowID.of(SyncCollection.categories, 'e1');

  group('scalars', () {
    test('defaults to pre-enrollment values before any write', () async {
      expect(await store.getBackendSelection(), isNull);
      expect(await store.getPhase(), isNull);
      expect(await store.isWriteGateEnabled(), isFalse);
    });

    test('setBackendSelection roundtrips through the one row', () async {
      await store.setBackendSelection('profile-1');
      expect(await store.getBackendSelection(), 'profile-1');

      // A second profile replaces the first instead of stacking rows.
      await store.setBackendSelection('profile-2');
      expect(await store.getBackendSelection(), 'profile-2');
    });

    test('setPhase stores the explicit code and returns the enum', () async {
      await store.setPhase(EnrollmentPhase.reconciliationComplete);
      expect(await store.getPhase(), EnrollmentPhase.reconciliationComplete);

      await store.setPhase(EnrollmentPhase.gateEnabled);
      expect(await store.getPhase(), EnrollmentPhase.gateEnabled);
    });

    test('setWriteGateEnabled persists the flag', () async {
      expect(await store.isWriteGateEnabled(), isFalse);

      await store.setWriteGateEnabled(true);
      expect(await store.isWriteGateEnabled(), isTrue);
    });

    test('setting each scalar keeps them independent in one row', () async {
      await store.setBackendSelection('profile-x');
      await store.setPhase(EnrollmentPhase.gateEnabled);
      await store.setWriteGateEnabled(true);

      expect(await store.getBackendSelection(), 'profile-x');
      expect(await store.getPhase(), EnrollmentPhase.gateEnabled);
      expect(await store.isWriteGateEnabled(), isTrue);
    });
  });

  group('watermarks', () {
    test('setWatermark roundtrips and getAllWatermarks reads all five',
        () async {
      await store.setWatermark(
        SyncCollection.moneySources,
        VersionVector({'deviceA': 3}),
      );
      await store.setWatermark(
        SyncCollection.entries,
        VersionVector({'deviceB': 2}),
      );
      await store.setWatermark(
        SyncCollection.categories,
        VersionVector({'deviceC': 1}),
      );
      await store.setWatermark(
        SyncCollection.plans,
        VersionVector({'deviceA': 5}),
      );
      await store.setWatermark(
        SyncCollection.budgets,
        VersionVector({'deviceD': 4}),
      );

      expect(await store.getWatermark(SyncCollection.moneySources),
          VersionVector({'deviceA': 3}));
      expect(await store.getWatermark(SyncCollection.entries),
          VersionVector({'deviceB': 2}));
      expect(await store.getWatermark(SyncCollection.budgets),
          VersionVector({'deviceD': 4}));

      final all = await store.getAllWatermarks();
      expect(all.keys.toSet(), equals(SyncCollection.values.toSet()));
      expect(all.length, 5);
    });

    test('getWatermark returns null for an unread collection', () async {
      expect(await store.getWatermark(SyncCollection.entries), isNull);
    });

    test('setWatermark replaces the prior vector for the collection',
        () async {
      await store.setWatermark(SyncCollection.entries, VersionVector({'d': 1}));
      await store.setWatermark(SyncCollection.entries, VersionVector({'d': 7}));

      expect(await store.getWatermark(SyncCollection.entries),
          VersionVector({'d': 7}));
    });
  });

  group('acknowledged vectors', () {
    test('set/get by SyncRowID roundtrips', () async {
      await store.setAcknowledgedVector(entryRowE1, VersionVector({'deviceA': 2}));

      expect(await store.getAcknowledgedVector(entryRowE1),
          VersionVector({'deviceA': 2}));
    });

    test('vectors for the same row id are independent per collection',
        () async {
      await store.setAcknowledgedVector(
        SyncRowID.of(SyncCollection.entries, 'e1'),
        VersionVector({'deviceA': 2}),
      );
      await store.setAcknowledgedVector(
        categoryRowE1,
        VersionVector({'deviceC': 9}),
      );

      expect(await store.getAcknowledgedVector(entryRowE1),
          VersionVector({'deviceA': 2}));
      expect(await store.getAcknowledgedVector(categoryRowE1),
          VersionVector({'deviceC': 9}));
    });

    test('clearAcknowledgedVector removes only its row', () async {
      await store.setAcknowledgedVector(entryRowE1, VersionVector({'deviceA': 2}));
      await store.setAcknowledgedVector(entryRowE2, VersionVector({'deviceB': 3}));

      await store.clearAcknowledgedVector(entryRowE1);

      expect(await store.getAcknowledgedVector(entryRowE1), isNull);
      expect(await store.getAcknowledgedVector(entryRowE2),
          VersionVector({'deviceB': 3}));
    });

    test('getAllAcknowledgedVectors maps every row', () async {
      await store.setAcknowledgedVector(entryRowE1, VersionVector({'deviceA': 2}));
      await store.setAcknowledgedVector(entryRowE2, VersionVector({'deviceB': 3}));

      final all = await store.getAllAcknowledgedVectors();
      expect(all, {
        entryRowE1: VersionVector({'deviceA': 2}),
        entryRowE2: VersionVector({'deviceB': 3}),
      });
    });
  });

  group('pending pull acknowledgements', () {
    test('setPendingAck/hasPendingAck roundtrip', () async {
      expect(await store.hasPendingAck(SyncCollection.entries, 'cp-1'), isFalse);

      await store.setPendingAck(SyncCollection.entries, 'cp-1');
      expect(await store.hasPendingAck(SyncCollection.entries, 'cp-1'), isTrue);
    });

    test('clearPendingAck removes the owed page', () async {
      await store.setPendingAck(SyncCollection.entries, 'cp-1');

      await store.clearPendingAck(SyncCollection.entries, 'cp-1');

      expect(await store.hasPendingAck(SyncCollection.entries, 'cp-1'), isFalse);
    });

    test('allPendingCheckpoints lists every owed checkpoint', () async {
      await store.setPendingAck(SyncCollection.entries, 'cp-1');
      await store.setPendingAck(SyncCollection.categories, 'cp-2');
      await store.setPendingAck(SyncCollection.entries, 'cp-3');

      final pending = await store.allPendingCheckpoints();
      expect(
        pending,
        containsAllInOrder([
          const PendingCheckpoint(SyncCollection.entries, 'cp-1'),
          PendingCheckpoint(SyncCollection.categories, 'cp-2'),
          PendingCheckpoint(SyncCollection.entries, 'cp-3'),
        ]),
      );
    });
  });

  group('commitPullPage', () {
    test('commits ack vectors, watermark, and pending ack atomically',
        () async {
      await store.commitPullPage(
        collection: SyncCollection.entries,
        checkpoint: 'cp-9',
        watermark: VersionVector({'deviceB': 4}),
        acknowledgedVectors: {
          entryRowE1: VersionVector({'deviceB': 4}),
          entryRowE2: VersionVector({'deviceB': 4}),
        },
      );

      expect(await store.getAcknowledgedVector(entryRowE1),
          VersionVector({'deviceB': 4}));
      expect(await store.getAcknowledgedVector(entryRowE2),
          VersionVector({'deviceB': 4}));
      expect(await store.getWatermark(SyncCollection.entries),
          VersionVector({'deviceB': 4}));
      expect(await store.hasPendingAck(SyncCollection.entries, 'cp-9'), isTrue);
      expect(
        await store.allPendingCheckpoints(),
        contains(const PendingCheckpoint(SyncCollection.entries, 'cp-9')),
      );
    });

    test('ack vectors and the page watermark stay in lockstep', () async {
      // commitPullPage bundles the ack vectors, the page watermark, and the
      // pending ack in one Drift transaction, so every read reflects the whole
      // page rather than a partially committed one.
      await store.commitPullPage(
        collection: SyncCollection.entries,
        checkpoint: 'cp-10',
        watermark: VersionVector({'deviceA': 6}),
        acknowledgedVectors: {
          entryRowE1: VersionVector({'deviceA': 6}),
        },
      );

      final acked = await store.getAllAcknowledgedVectors();
      final watermark = await store.getWatermark(SyncCollection.entries);
      expect(acked[entryRowE1], VersionVector({'deviceA': 6}));
      expect(watermark, VersionVector({'deviceA': 6}));
      expect(await store.hasPendingAck(SyncCollection.entries, 'cp-10'), isTrue);
    });
  });
}
