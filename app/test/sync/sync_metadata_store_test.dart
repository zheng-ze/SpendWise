import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
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

    test('setBackendSelection(null) clears a prior selection', () async {
      await store.setBackendSelection('profile-1');
      expect(await store.getBackendSelection(), 'profile-1');

      await store.setBackendSelection(null);

      // A fresh store over the same database observes the cleared value,
      // so the update wrote the null rather than omitting it.
      expect(await SyncMetadataStore(db).getBackendSelection(), isNull);
    });

    test('setPhase stores the explicit code and returns the enum', () async {
      await store.setPhase(EnrollmentPhase.reconciliationComplete);
      expect(await store.getPhase(), EnrollmentPhase.reconciliationComplete);

      await store.setPhase(EnrollmentPhase.gateEnabled);
      expect(await store.getPhase(), EnrollmentPhase.gateEnabled);
    });

    test('setWriteGateEnabled persists the flag', () async {
      expect(await store.isWriteGateEnabled(), isFalse);

      await store.setPhase(EnrollmentPhase.reconciliationComplete);
      await store.setWriteGateEnabled(true);
      expect(await store.isWriteGateEnabled(), isTrue);
    });

    test('setting each scalar keeps them independent in one row', () async {
      await store.setBackendSelection('profile-x');
      await store.setPhase(EnrollmentPhase.reconciliationComplete);
      await store.setWriteGateEnabled(true);

      expect(await store.getBackendSelection(), 'profile-x');
      expect(await store.getPhase(), EnrollmentPhase.reconciliationComplete);
      expect(await store.isWriteGateEnabled(), isTrue);
    });

    test(
      'enabling the write gate before reconciliationComplete throws',
      () async {
        expect(await store.getPhase(), isNull);
        await expectLater(
          store.setWriteGateEnabled(true),
          throwsA(isA<WriteGateNotReadyError>()),
        );
        expect(await store.isWriteGateEnabled(), isFalse);

        await store.setPhase(EnrollmentPhase.snapshotKeyWorkInProgress);
        await expectLater(
          store.setWriteGateEnabled(true),
          throwsA(isA<WriteGateNotReadyError>()),
        );
        expect(await store.isWriteGateEnabled(), isFalse);
      },
    );

    test(
      'enabling the write gate at reconciliationComplete succeeds',
      () async {
        await store.setPhase(EnrollmentPhase.reconciliationComplete);

        await store.setWriteGateEnabled(true);

        expect(await store.isWriteGateEnabled(), isTrue);
        expect(
          await SyncMetadataStore(db).isWriteGateEnabled(),
          isTrue,
          reason: 'the enabled gate persists across store instances',
        );
      },
    );

    test('enabling an already-enabled gate is an idempotent no-op', () async {
      await store.setPhase(EnrollmentPhase.reconciliationComplete);
      await store.setWriteGateEnabled(true);

      // Already enabled, so the call succeeds without the phase check
      // even after the phase advances.
      await store.setPhase(EnrollmentPhase.gateEnabled);
      await store.setWriteGateEnabled(true);

      expect(await store.isWriteGateEnabled(), isTrue);
      expect(await store.getPhase(), EnrollmentPhase.gateEnabled);
    });

    test('disabling the write gate succeeds from any phase', () async {
      await store.setPhase(EnrollmentPhase.credentialAcquired);
      await store.setWriteGateEnabled(false);
      expect(await store.isWriteGateEnabled(), isFalse);

      await store.setPhase(EnrollmentPhase.reconciliationComplete);
      await store.setWriteGateEnabled(true);
      await store.setWriteGateEnabled(false);
      expect(await store.isWriteGateEnabled(), isFalse);
    });

    test('concurrent scalar mutations lose no write', () async {
      await store.setPhase(EnrollmentPhase.reconciliationComplete);
      // Seeds a non-null value so a lost update would overwrite it.
      // A null seed would hide the race.
      await store.setBackendSelection('profile-seed');

      await Future.wait([
        store.setBackendSelection('profile-concurrent'),
        store.setWriteGateEnabled(true),
      ]);

      expect(await store.getBackendSelection(), 'profile-concurrent');
      expect(await store.isWriteGateEnabled(), isTrue);
      expect(
        await store.getPhase(),
        EnrollmentPhase.reconciliationComplete,
      );
    });
  });

  group('watermarks', () {
    test(
      'setWatermark roundtrips and getAllWatermarks reads all five',
      () async {
        await store.setWatermark(
          SyncCollection.moneySources,
          'cp-checkpoint-1',
        );
        await store.setWatermark(SyncCollection.entries, 'cp-checkpoint-2');
        await store.setWatermark(
          SyncCollection.categories,
          'cp-checkpoint-3',
        );
        await store.setWatermark(SyncCollection.plans, 'cp-checkpoint-4');
        await store.setWatermark(SyncCollection.budgets, 'cp-checkpoint-5');

        expect(
          await store.getWatermark(SyncCollection.moneySources),
          'cp-checkpoint-1',
        );
        expect(
          await store.getWatermark(SyncCollection.entries),
          'cp-checkpoint-2',
        );
        expect(
          await store.getWatermark(SyncCollection.budgets),
          'cp-checkpoint-5',
        );

        final all = await store.getAllWatermarks();
        expect(all.keys.toSet(), equals(SyncCollection.values.toSet()));
        expect(all.length, 5);
        // The stored cursor stays opaque and never holds a version vector.
        expect(
          PullRequest(
            collection: SyncCollection.entries,
            cursor: all[SyncCollection.entries],
          ).cursor,
          'cp-checkpoint-2',
        );
      },
    );

    test('getWatermark returns null for an unread collection', () async {
      expect(await store.getWatermark(SyncCollection.entries), isNull);
    });

    test('setWatermark replaces the prior cursor for the collection', () async {
      await store.setWatermark(SyncCollection.entries, 'cp-checkpoint-1');
      await store.setWatermark(SyncCollection.entries, 'cp-checkpoint-7');

      expect(
        await store.getWatermark(SyncCollection.entries),
        'cp-checkpoint-7',
      );
    });
  });

  group('acknowledged vectors', () {
    test('set/get by SyncRowID roundtrips', () async {
      await store.setAcknowledgedVector(
        entryRowE1,
        VersionVector({'deviceA': 2}),
      );

      expect(
        await store.getAcknowledgedVector(entryRowE1),
        VersionVector({'deviceA': 2}),
      );
    });

    test(
      'vectors for the same row id are independent per collection',
      () async {
        await store.setAcknowledgedVector(
          SyncRowID.of(SyncCollection.entries, 'e1'),
          VersionVector({'deviceA': 2}),
        );
        await store.setAcknowledgedVector(
          categoryRowE1,
          VersionVector({'deviceC': 9}),
        );

        expect(
          await store.getAcknowledgedVector(entryRowE1),
          VersionVector({'deviceA': 2}),
        );
        expect(
          await store.getAcknowledgedVector(categoryRowE1),
          VersionVector({'deviceC': 9}),
        );
      },
    );

    test('clearAcknowledgedVector removes only its row', () async {
      await store.setAcknowledgedVector(
        entryRowE1,
        VersionVector({'deviceA': 2}),
      );
      await store.setAcknowledgedVector(
        entryRowE2,
        VersionVector({'deviceB': 3}),
      );

      await store.clearAcknowledgedVector(entryRowE1);

      expect(await store.getAcknowledgedVector(entryRowE1), isNull);
      expect(
        await store.getAcknowledgedVector(entryRowE2),
        VersionVector({'deviceB': 3}),
      );
    });

    test('getAllAcknowledgedVectors maps every row', () async {
      await store.setAcknowledgedVector(
        entryRowE1,
        VersionVector({'deviceA': 2}),
      );
      await store.setAcknowledgedVector(
        entryRowE2,
        VersionVector({'deviceB': 3}),
      );

      final all = await store.getAllAcknowledgedVectors();
      expect(all, {
        entryRowE1: VersionVector({'deviceA': 2}),
        entryRowE2: VersionVector({'deviceB': 3}),
      });
    });
  });

  group('pending pull acknowledgements', () {
    test('setPendingAck/hasPendingAck roundtrip', () async {
      expect(
        await store.hasPendingAck(SyncCollection.entries, 'cp-1'),
        isFalse,
      );

      await store.setPendingAck(SyncCollection.entries, 'cp-1');
      expect(await store.hasPendingAck(SyncCollection.entries, 'cp-1'), isTrue);
    });

    test('setPendingAck is idempotent when the row already exists', () async {
      await store.setPendingAck(SyncCollection.entries, 'cp-1');
      // A retry, for example after a crash between commit and acknowledgement,
      // must not throw a UNIQUE constraint violation.
      await store.setPendingAck(SyncCollection.entries, 'cp-1');

      expect(await store.hasPendingAck(SyncCollection.entries, 'cp-1'), isTrue);
      expect(await store.allPendingCheckpoints(), hasLength(1));
    });

    test('clearPendingAck removes the owed page', () async {
      await store.setPendingAck(SyncCollection.entries, 'cp-1');

      await store.clearPendingAck(SyncCollection.entries, 'cp-1');

      expect(
        await store.hasPendingAck(SyncCollection.entries, 'cp-1'),
        isFalse,
      );
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
    test(
      'commits ack vectors, watermark, and pending ack atomically',
      () async {
        await store.commitPullPage(
          collection: SyncCollection.entries,
          checkpoint: 'cp-9',
          watermark: 'cp-checkpoint-7',
          acknowledgedVectors: {
            entryRowE1: VersionVector({'deviceB': 4}),
            entryRowE2: VersionVector({'deviceB': 4}),
          },
        );

        expect(
          await store.getAcknowledgedVector(entryRowE1),
          VersionVector({'deviceB': 4}),
        );
        expect(
          await store.getAcknowledgedVector(entryRowE2),
          VersionVector({'deviceB': 4}),
        );
        expect(
          await store.getWatermark(SyncCollection.entries),
          'cp-checkpoint-7',
        );
        expect(
          await store.hasPendingAck(SyncCollection.entries, 'cp-9'),
          isTrue,
        );
        expect(
          await store.allPendingCheckpoints(),
          contains(const PendingCheckpoint(SyncCollection.entries, 'cp-9')),
        );
      },
    );

    test(
      'a repeated commitPullPage for one checkpoint is idempotent',
      () async {
        Future<void> commit() => store.commitPullPage(
          collection: SyncCollection.entries,
          checkpoint: 'cp-9',
          watermark: 'cp-checkpoint-7',
          acknowledgedVectors: {
            entryRowE1: VersionVector({'deviceB': 4}),
            entryRowE2: VersionVector({'deviceB': 4}),
          },
        );

        await commit();
        // A crash/retry replays the same page commit. The existing pending-ack
        // row must not fail the whole commit with a UNIQUE constraint error.
        await commit();

        expect(
          await store.getAcknowledgedVector(entryRowE1),
          VersionVector({'deviceB': 4}),
        );
        expect(
          await store.getAcknowledgedVector(entryRowE2),
          VersionVector({'deviceB': 4}),
        );
        expect(
          await store.getWatermark(SyncCollection.entries),
          'cp-checkpoint-7',
        );
        expect(
          await store.hasPendingAck(SyncCollection.entries, 'cp-9'),
          isTrue,
        );
        expect(await store.allPendingCheckpoints(), hasLength(1));
      },
    );

    test(
      'commitPullPage rolls back every write when the commit fails',
      () async {
        // Seed unrelated state that must survive the failed commit untouched.
        final seededRow = SyncRowID.of(SyncCollection.categories, 'seed');
        await store.setAcknowledgedVector(seededRow, VersionVector({'d': 1}));
        await store.setWatermark(
          SyncCollection.categories,
          'cp-checkpoint-seed',
        );

        // Fail the commit after the ack-vector and watermark writes, at the
        // pending-ack write, by removing that table.
        await db.customStatement('DROP TABLE sync_pending_ack');

        await expectLater(
          store.commitPullPage(
            collection: SyncCollection.entries,
            checkpoint: 'cp-9',
            watermark: 'cp-checkpoint-7',
            acknowledgedVectors: {
              entryRowE1: VersionVector({'deviceB': 4}),
            },
          ),
          throwsA(isA<Exception>()),
        );

        // The failed commit leaves no partial state behind.
        expect(await store.getAcknowledgedVector(entryRowE1), isNull);
        expect(await store.getWatermark(SyncCollection.entries), isNull);

        // Pre-existing state stays exactly as before the call.
        expect(
          await store.getAcknowledgedVector(seededRow),
          VersionVector({'d': 1}),
        );
        expect(
          await store.getWatermark(SyncCollection.categories),
          'cp-checkpoint-seed',
        );
      },
    );

    test('committed page state survives close and reopen', () async {
      // Opens one file with two database objects to prove durable metadata.
      // Silences the multiple-database warning for this test.
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      addTearDown(
        () => driftRuntimeOptions.dontWarnAboutMultipleDatabases = false,
      );
      final directory = await Directory.systemTemp.createTemp('metadata');
      try {
        final path = '${directory.path}${Platform.pathSeparator}ledger.db';

        final first = LedgerDatabase(NativeDatabase(File(path)));
        try {
          final firstStore = SyncMetadataStore(first);
          await firstStore.setBackendSelection('profile-1');
          await firstStore.setPhase(EnrollmentPhase.reconciliationComplete);
          await firstStore.commitPullPage(
            collection: SyncCollection.entries,
            checkpoint: 'cp-9',
            watermark: 'cp-checkpoint-7',
            acknowledgedVectors: {
              entryRowE1: VersionVector({'deviceB': 4}),
            },
          );
        } finally {
          await first.close();
        }

        // A fresh store over the same file reconstructs the durable metadata,
        // modelling a force-quit after the page commit.
        final second = LedgerDatabase(NativeDatabase(File(path)));
        try {
          final secondStore = SyncMetadataStore(second);
          expect(await secondStore.getBackendSelection(), 'profile-1');
          expect(
            await secondStore.getPhase(),
            EnrollmentPhase.reconciliationComplete,
          );
          expect(
            await secondStore.getAcknowledgedVector(entryRowE1),
            VersionVector({'deviceB': 4}),
          );
          expect(
            await secondStore.getWatermark(SyncCollection.entries),
            'cp-checkpoint-7',
          );
          expect(
            await secondStore.hasPendingAck(SyncCollection.entries, 'cp-9'),
            isTrue,
          );
        } finally {
          await second.close();
        }
      } finally {
        await directory.delete(recursive: true);
      }
    });

    test('ack vectors and the page watermark stay in lockstep', () async {
      // Reads reflect the whole page, never a partially committed one.
      await store.commitPullPage(
        collection: SyncCollection.entries,
        checkpoint: 'cp-10',
        watermark: 'cp-checkpoint-7',
        acknowledgedVectors: {
          entryRowE1: VersionVector({'deviceA': 6}),
        },
      );

      final acked = await store.getAllAcknowledgedVectors();
      final watermark = await store.getWatermark(SyncCollection.entries);
      expect(acked[entryRowE1], VersionVector({'deviceA': 6}));
      expect(watermark, 'cp-checkpoint-7');
      expect(
        await store.hasPendingAck(SyncCollection.entries, 'cp-10'),
        isTrue,
      );
    });
  });
}
