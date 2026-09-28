import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/persistence/ledger_database.dart';
import 'package:spendwise/sync/sync_metadata_store.dart';
import 'package:sync/sync.dart';

const _rowA = '11111111-1111-1111-1111-111111111111';
const _rowB = '22222222-2222-2222-2222-222222222222';

class FailingCommitInterceptor extends QueryInterceptor {
  int failures = 0;

  @override
  Future<void> commitTransaction(TransactionExecutor inner) async {
    if (failures > 0) {
      failures--;
      throw const _CommitFailure();
    }
    return super.commitTransaction(inner);
  }
}

class _CommitFailure implements Exception {
  const _CommitFailure();
}

void main() {
  late LedgerDatabase db;
  late SyncMetadataStore store;

  setUp(() {
    db = LedgerDatabase(NativeDatabase.memory());
    store = SyncMetadataStore(db);
  });

  tearDown(() => db.close());

  Future<SyncMetadataSnapshot> snapshot() => store.snapshot();

  Future<void> seedRow({
    required SyncDeviceBindingState binding,
    required SyncEnrollmentPhase phase,
    required bool writes,
    SyncEnrollmentPhase? resume,
  }) async {
    await snapshot();
    await (db.update(db.syncMeta)..where((t) => t.id.equals(0))).write(
      SyncMetaCompanion(
        deviceBindingState: Value(binding.code),
        enrollmentPhase: Value(phase.code),
        writeEnabled: Value(writes),
        reauthResumePhase: resume == null
            ? const Value<int?>(null)
            : Value(resume.code),
      ),
    );
  }

  group('defaults', () {
    test('backend selection stays null until enrollment', () async {
      final state = await snapshot();
      expect(state.backend, isNull);
      expect(state.endpoint, isNull);
    });

    test('phase starts not-enrolled with the write gate closed', () async {
      final state = await snapshot();
      expect(state.phase, SyncEnrollmentPhase.notEnrolled);
      expect(state.writeEnabled, isFalse);
    });

    test('all five pull watermarks start null', () async {
      final state = await snapshot();
      expect(state.watermarks, hasLength(SyncCollection.values.length));
      for (final collection in SyncCollection.values) {
        expect(state.watermarks[collection], isNull, reason: '$collection');
      }
    });

    test('vectors and pending acknowledgements start empty', () async {
      expect(await store.acknowledgedVectors(), isEmpty);
      expect(await store.pendingAcknowledgements(), isEmpty);
      expect(
        await store.acknowledgedVector(
          SyncRowID.of(SyncCollection.entries, _rowA),
        ),
        isNull,
      );
      expect(
        await store.pendingAcknowledgement(SyncCollection.entries),
        isNull,
      );
    });
  });

  group('backend selection', () {
    test('round-trips each backend kind with its endpoint', () async {
      await store.setBackendSelection(
        backend: SyncBackendKind.supabase,
        endpoint: null,
      );
      var state = await snapshot();
      expect(state.backend, SyncBackendKind.supabase);
      expect(state.endpoint, isNull);

      await store.setBackendSelection(
        backend: SyncBackendKind.custom,
        endpoint: 'https://sync.example.com',
      );
      state = await snapshot();
      expect(state.backend, SyncBackendKind.custom);
      expect(state.endpoint, 'https://sync.example.com');
    });

    test('clears back to null', () async {
      await store.setBackendSelection(
        backend: SyncBackendKind.custom,
        endpoint: 'https://sync.example.com',
      );
      await store.clearBackendSelection();
      final state = await snapshot();
      expect(state.backend, isNull);
      expect(state.endpoint, isNull);
    });
  });

  group('enrollment phase and write gate', () {
    test('records every phase durably', () async {
      for (final phase in SyncEnrollmentPhase.values) {
        await seedRow(
          binding: SyncDeviceBindingState.notApplicable,
          phase: phase,
          writes: false,
        );
        expect((await snapshot()).phase, phase, reason: '$phase');
      }
    });

    test('deviceBindingRequired follows device_binding_state', () async {
      expect((await snapshot()).deviceBindingRequired, isFalse);
      await (db.update(db.syncMeta)..where((t) => t.id.equals(0))).write(
        const SyncMetaCompanion(deviceBindingState: Value(1)),
      );
      expect((await snapshot()).deviceBindingRequired, isTrue);
    });
  });

  group('pull watermarks', () {
    test('records and overwrites each collection independently', () async {
      for (final collection in SyncCollection.values) {
        await store.setPullWatermark(collection, 'cursor-$collection-1');
      }
      var state = await snapshot();
      for (final collection in SyncCollection.values) {
        expect(
          state.watermarks[collection],
          'cursor-$collection-1',
          reason: '$collection',
        );
      }

      await store.setPullWatermark(SyncCollection.entries, 'cursor-entries-2');
      state = await snapshot();
      expect(state.watermarks[SyncCollection.entries], 'cursor-entries-2');
      expect(
        state.watermarks[SyncCollection.plans],
        'cursor-SyncCollection.plans-1',
      );
    });

    test('a null cursor clears the watermark', () async {
      await store.setPullWatermark(SyncCollection.budgets, 'cursor-1');
      await store.setPullWatermark(SyncCollection.budgets, null);
      expect((await snapshot()).watermarks[SyncCollection.budgets], isNull);
    });
  });

  group('acknowledged vectors', () {
    test('round-trips vectors keyed by SyncRowID', () async {
      final row = SyncRowID.of(SyncCollection.entries, _rowA);
      final vector = VersionVector({'device-a': 3});
      await store.setAcknowledgedVector(row, vector);
      expect(await store.acknowledgedVector(row), vector);
    });

    test('overwrites a vector for the same row', () async {
      final row = SyncRowID.of(SyncCollection.entries, _rowA);
      await store.setAcknowledgedVector(row, VersionVector({'device-a': 1}));
      await store.setAcknowledgedVector(row, VersionVector({'device-a': 2}));
      expect(
        await store.acknowledgedVector(row),
        VersionVector({'device-a': 2}),
      );
      expect((await store.acknowledgedVectors()), hasLength(1));
    });

    test(
      'keeps identical UUIDs in different collections independent',
      () async {
        final inEntries = SyncRowID.of(SyncCollection.entries, _rowA);
        final inPlans = SyncRowID.of(SyncCollection.plans, _rowA);
        await store.setAcknowledgedVector(
          inEntries,
          VersionVector({'device-a': 1}),
        );
        await store.setAcknowledgedVector(
          inPlans,
          VersionVector({'device-a': 7}),
        );
        expect(
          await store.acknowledgedVector(inEntries),
          VersionVector({'device-a': 1}),
        );
        expect(
          await store.acknowledgedVector(inPlans),
          VersionVector({'device-a': 7}),
        );
      },
    );

    test('lists every recorded vector', () async {
      await store.setAcknowledgedVector(
        SyncRowID.of(SyncCollection.entries, _rowA),
        VersionVector({'device-a': 1}),
      );
      await store.setAcknowledgedVector(
        SyncRowID.of(SyncCollection.categories, _rowB),
        VersionVector({'device-b': 2}),
      );
      expect(await store.acknowledgedVectors(), {
        SyncRowID.of(SyncCollection.entries, _rowA): VersionVector({
          'device-a': 1,
        }),
        SyncRowID.of(SyncCollection.categories, _rowB): VersionVector({
          'device-b': 2,
        }),
      });
    });
  });

  group('pending pull acknowledgements', () {
    test('round-trips one checkpoint per collection', () async {
      await store.setPendingAcknowledgement(
        SyncCollection.entries,
        'checkpoint-9',
      );
      expect(
        await store.pendingAcknowledgement(SyncCollection.entries),
        'checkpoint-9',
      );
      expect(await store.pendingAcknowledgement(SyncCollection.plans), isNull);
    });

    test('overwrites the checkpoint for the same collection', () async {
      await store.setPendingAcknowledgement(
        SyncCollection.entries,
        'checkpoint-9',
      );
      await store.setPendingAcknowledgement(
        SyncCollection.entries,
        'checkpoint-10',
      );
      expect(
        await store.pendingAcknowledgement(SyncCollection.entries),
        'checkpoint-10',
      );
    });

    test('clears only the named collection', () async {
      await store.setPendingAcknowledgement(
        SyncCollection.entries,
        'checkpoint-9',
      );
      await store.setPendingAcknowledgement(
        SyncCollection.plans,
        'checkpoint-3',
      );
      await store.clearPendingAcknowledgement(SyncCollection.entries);
      expect(await store.pendingAcknowledgements(), {
        SyncCollection.plans: 'checkpoint-3',
      });
    });

    test('clearing an absent collection is a no-op', () async {
      await store.clearPendingAcknowledgement(SyncCollection.entries);
      expect(await store.pendingAcknowledgements(), isEmpty);
    });
  });

  group('recordPulledPage', () {
    test('commits vectors, watermark, and acknowledgement together', () async {
      final first = SyncRowID.of(SyncCollection.entries, _rowA);
      final second = SyncRowID.of(SyncCollection.entries, _rowB);
      await store.recordPulledPage(
        collection: SyncCollection.entries,
        vectors: {
          first: VersionVector({'device-a': 1}),
          second: VersionVector({'device-b': 2}),
        },
        watermark: 'cursor-5',
        checkpoint: 'checkpoint-5',
      );

      expect(
        await store.acknowledgedVector(first),
        VersionVector({'device-a': 1}),
      );
      expect(
        await store.acknowledgedVector(second),
        VersionVector({'device-b': 2}),
      );
      expect((await snapshot()).watermarks[SyncCollection.entries], 'cursor-5');
      expect(
        await store.pendingAcknowledgement(SyncCollection.entries),
        'checkpoint-5',
      );
    });

    test(
      'an empty page still advances watermark and acknowledgement',
      () async {
        await store.recordPulledPage(
          collection: SyncCollection.plans,
          vectors: const {},
          watermark: 'cursor-1',
          checkpoint: 'checkpoint-1',
        );
        expect((await snapshot()).watermarks[SyncCollection.plans], 'cursor-1');
        expect(
          await store.pendingAcknowledgement(SyncCollection.plans),
          'checkpoint-1',
        );
        expect(await store.acknowledgedVectors(), isEmpty);
      },
    );

    test('rejects a vector from another collection', () async {
      await expectLater(
        store.recordPulledPage(
          collection: SyncCollection.entries,
          vectors: {
            SyncRowID.of(SyncCollection.plans, _rowA): VersionVector({
              'device-a': 1,
            }),
          },
          watermark: 'cursor-1',
          checkpoint: 'checkpoint-1',
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect((await snapshot()).watermarks[SyncCollection.entries], isNull);
      expect(
        await store.pendingAcknowledgement(SyncCollection.entries),
        isNull,
      );
    });
  });

  group('transaction atomicity and rollback', () {
    test('a failed multi-value commit rolls back every value', () async {
      final flaky = FailingCommitInterceptor();
      final fragileDb = LedgerDatabase(
        NativeDatabase.memory().interceptWith(flaky),
      );
      addTearDown(fragileDb.close);
      final fragile = SyncMetadataStore(fragileDb);

      await fragile.enterSnapshotInProgress();
      await fragile.setPullWatermark(SyncCollection.entries, 'cursor-1');

      flaky.failures = 1;
      final row = SyncRowID.of(SyncCollection.entries, _rowA);
      await expectLater(
        fragile.recordPulledPage(
          collection: SyncCollection.entries,
          vectors: {
            row: VersionVector({'device-a': 1}),
          },
          watermark: 'cursor-2',
          checkpoint: 'checkpoint-2',
        ),
        throwsA(isA<_CommitFailure>()),
      );

      expect(
        (await fragile.snapshot()).phase,
        SyncEnrollmentPhase.snapshotInProgress,
      );
      expect(
        (await fragile.snapshot()).watermarks[SyncCollection.entries],
        'cursor-1',
      );
      expect(await fragile.acknowledgedVector(row), isNull);
      expect(
        await fragile.pendingAcknowledgement(SyncCollection.entries),
        isNull,
      );

      await fragile.recordPulledPage(
        collection: SyncCollection.entries,
        vectors: {
          row: VersionVector({'device-a': 1}),
        },
        watermark: 'cursor-2',
        checkpoint: 'checkpoint-2',
      );
      expect(
        await fragile.acknowledgedVector(row),
        VersionVector({'device-a': 1}),
      );
      expect(
        (await fragile.snapshot()).watermarks[SyncCollection.entries],
        'cursor-2',
      );
      expect(
        await fragile.pendingAcknowledgement(SyncCollection.entries),
        'checkpoint-2',
      );
    });

    test('a failed single-value write keeps the previous value', () async {
      final flaky = FailingCommitInterceptor();
      final fragileDb = LedgerDatabase(
        NativeDatabase.memory().interceptWith(flaky),
      );
      addTearDown(fragileDb.close);
      final fragile = SyncMetadataStore(fragileDb);

      await fragile.enterSnapshotInProgress();
      flaky.failures = 1;
      await expectLater(
        fragile.enterReconciliationComplete(),
        throwsA(isA<_CommitFailure>()),
      );
      final state = await fragile.snapshot();
      expect(state.phase, SyncEnrollmentPhase.snapshotInProgress);
      expect(state.deviceBindingState, SyncDeviceBindingState.bound);
      expect(state.writeEnabled, isFalse);
      expect(state.reauthResumePhase, isNull);
    });
  });

  group('secret separation', () {
    Future<Set<String>> columns(String table) async {
      final rows = await db.customSelect('PRAGMA table_info($table)').get();
      return {for (final row in rows) row.read<String>('name')};
    }

    test('the sync schema has no column for secret material', () async {
      await store.snapshot();
      await store.setAcknowledgedVector(
        SyncRowID.of(SyncCollection.entries, _rowA),
        VersionVector({'device-a': 1}),
      );
      await store.setPendingAcknowledgement(
        SyncCollection.entries,
        'checkpoint-1',
      );

      expect(await columns('sync_meta'), {
        'id',
        'backend',
        'endpoint',
        'enrollment_phase',
        'write_enabled',
        'device_binding_state',
        'reauth_resume_phase',
        'money_sources_cursor',
        'entries_cursor',
        'categories_cursor',
        'plans_cursor',
        'budgets_cursor',
      });
      expect(await columns('sync_acknowledged_vectors'), {
        'collection',
        'row_id',
        'version_data',
      });
      expect(await columns('sync_pending_acknowledgements'), {
        'collection',
        'checkpoint',
      });
    });
  });

  group('restart durability', () {
    test('metadata survives close and reopen', () async {
      final directory = await Directory.systemTemp.createTemp(
        'spendwise-metadata-test',
      );
      addTearDown(() => directory.delete(recursive: true));
      LedgerDatabase open() => LedgerDatabase(
        NativeDatabase(File('${directory.path}/spendwise.db')),
      );

      final first = open();
      final writer = SyncMetadataStore(first);
      await writer.setBackendSelection(
        backend: SyncBackendKind.custom,
        endpoint: 'https://sync.example.com',
      );
      await writer.enterReconciliationComplete();
      await writer.enterGateEnabled();
      await writer.setPullWatermark(SyncCollection.entries, 'cursor-5');
      await writer.setPullWatermark(SyncCollection.budgets, 'cursor-2');
      await writer.setAcknowledgedVector(
        SyncRowID.of(SyncCollection.entries, _rowA),
        VersionVector({'device-a': 3}),
      );
      await writer.setPendingAcknowledgement(
        SyncCollection.entries,
        'checkpoint-5',
      );
      await first.close();

      final second = open();
      addTearDown(second.close);
      final reader = SyncMetadataStore(second);
      final state = await reader.snapshot();
      expect(state.backend, SyncBackendKind.custom);
      expect(state.endpoint, 'https://sync.example.com');
      expect(state.phase, SyncEnrollmentPhase.gateEnabled);
      expect(state.writeEnabled, isTrue);
      expect(state.deviceBindingState, SyncDeviceBindingState.bound);
      expect(state.reauthResumePhase, isNull);
      expect(state.watermarks[SyncCollection.entries], 'cursor-5');
      expect(state.watermarks[SyncCollection.budgets], 'cursor-2');
      expect(state.watermarks[SyncCollection.plans], isNull);
      expect(
        await reader.acknowledgedVector(
          SyncRowID.of(SyncCollection.entries, _rowA),
        ),
        VersionVector({'device-a': 3}),
      );
      expect(
        await reader.pendingAcknowledgement(SyncCollection.entries),
        'checkpoint-5',
      );
    });
  });

  group('hosted operation legality', () {
    SyncMetadataSnapshot fake({
      required SyncDeviceBindingState binding,
      required SyncEnrollmentPhase phase,
      required bool writes,
      SyncEnrollmentPhase? resume,
    }) => SyncMetadataSnapshot(
      backend: null,
      endpoint: null,
      phase: phase,
      writeEnabled: writes,
      deviceBindingState: binding,
      reauthResumePhase: resume,
      watermarks: {
        for (final collection in SyncCollection.values) collection: null,
      },
    );

    test('accepts every legal combination', () {
      final legal = [
        fake(
          binding: SyncDeviceBindingState.notApplicable,
          phase: SyncEnrollmentPhase.notEnrolled,
          writes: false,
        ),
        fake(
          binding: SyncDeviceBindingState.authorizationRequired,
          phase: SyncEnrollmentPhase.credentialAcquired,
          writes: false,
        ),
        fake(
          binding: SyncDeviceBindingState.authorizationRequired,
          phase: SyncEnrollmentPhase.bindingAuthorizationRequired,
          writes: false,
        ),
        fake(
          binding: SyncDeviceBindingState.bound,
          phase: SyncEnrollmentPhase.sessionReauthRequired,
          writes: false,
          resume: SyncEnrollmentPhase.snapshotInProgress,
        ),
        fake(
          binding: SyncDeviceBindingState.bound,
          phase: SyncEnrollmentPhase.sessionReauthRequired,
          writes: false,
          resume: SyncEnrollmentPhase.reconciliationComplete,
        ),
        fake(
          binding: SyncDeviceBindingState.bound,
          phase: SyncEnrollmentPhase.sessionReauthRequired,
          writes: false,
          resume: SyncEnrollmentPhase.gateEnabled,
        ),
        fake(
          binding: SyncDeviceBindingState.bound,
          phase: SyncEnrollmentPhase.snapshotInProgress,
          writes: false,
        ),
        fake(
          binding: SyncDeviceBindingState.bound,
          phase: SyncEnrollmentPhase.reconciliationComplete,
          writes: false,
        ),
        fake(
          binding: SyncDeviceBindingState.bound,
          phase: SyncEnrollmentPhase.gateEnabled,
          writes: true,
        ),
      ];
      for (final state in legal) {
        final outcome = store.validateHostedOperationState(state);
        expect(outcome, isA<HostedOperationLegal>(), reason: '$state');
        expect(outcome.isLegal, isTrue, reason: '$state');
      }
    });

    test('rejects every illegal combination', () {
      final illegal = [
        fake(
          binding: SyncDeviceBindingState.bound,
          phase: SyncEnrollmentPhase.sessionReauthRequired,
          writes: false,
        ),
        fake(
          binding: SyncDeviceBindingState.notApplicable,
          phase: SyncEnrollmentPhase.gateEnabled,
          writes: true,
        ),
        fake(
          binding: SyncDeviceBindingState.notApplicable,
          phase: SyncEnrollmentPhase.credentialAcquired,
          writes: false,
        ),
        fake(
          binding: SyncDeviceBindingState.authorizationRequired,
          phase: SyncEnrollmentPhase.notEnrolled,
          writes: false,
        ),
        fake(
          binding: SyncDeviceBindingState.authorizationRequired,
          phase: SyncEnrollmentPhase.snapshotInProgress,
          writes: false,
        ),
        fake(
          binding: SyncDeviceBindingState.bound,
          phase: SyncEnrollmentPhase.credentialAcquired,
          writes: false,
        ),
        fake(
          binding: SyncDeviceBindingState.bound,
          phase: SyncEnrollmentPhase.bindingAuthorizationRequired,
          writes: false,
        ),
        fake(
          binding: SyncDeviceBindingState.bound,
          phase: SyncEnrollmentPhase.notEnrolled,
          writes: false,
        ),
        fake(
          binding: SyncDeviceBindingState.bound,
          phase: SyncEnrollmentPhase.gateEnabled,
          writes: false,
        ),
        fake(
          binding: SyncDeviceBindingState.bound,
          phase: SyncEnrollmentPhase.snapshotInProgress,
          writes: true,
        ),
        fake(
          binding: SyncDeviceBindingState.notApplicable,
          phase: SyncEnrollmentPhase.notEnrolled,
          writes: true,
        ),
        fake(
          binding: SyncDeviceBindingState.authorizationRequired,
          phase: SyncEnrollmentPhase.credentialAcquired,
          writes: true,
        ),
        fake(
          binding: SyncDeviceBindingState.authorizationRequired,
          phase: SyncEnrollmentPhase.bindingAuthorizationRequired,
          writes: true,
        ),
        fake(
          binding: SyncDeviceBindingState.bound,
          phase: SyncEnrollmentPhase.sessionReauthRequired,
          writes: true,
          resume: SyncEnrollmentPhase.gateEnabled,
        ),
        fake(
          binding: SyncDeviceBindingState.bound,
          phase: SyncEnrollmentPhase.sessionReauthRequired,
          writes: false,
          resume: SyncEnrollmentPhase.credentialAcquired,
        ),
        fake(
          binding: SyncDeviceBindingState.bound,
          phase: SyncEnrollmentPhase.sessionReauthRequired,
          writes: false,
          resume: SyncEnrollmentPhase.sessionReauthRequired,
        ),
        fake(
          binding: SyncDeviceBindingState.bound,
          phase: SyncEnrollmentPhase.gateEnabled,
          writes: true,
          resume: SyncEnrollmentPhase.snapshotInProgress,
        ),
        fake(
          binding: SyncDeviceBindingState.notApplicable,
          phase: SyncEnrollmentPhase.notEnrolled,
          writes: false,
          resume: SyncEnrollmentPhase.snapshotInProgress,
        ),
      ];
      for (final state in illegal) {
        final outcome = store.validateHostedOperationState(state);
        expect(outcome, isA<HostedOperationIllegal>(), reason: '$state');
        expect(outcome.isLegal, isFalse, reason: '$state');
      }
    });

    test(
      'snapshot returns illegal rows as raw values without throwing',
      () async {
        await seedRow(
          binding: SyncDeviceBindingState.bound,
          phase: SyncEnrollmentPhase.sessionReauthRequired,
          writes: false,
        );
        final state = await snapshot();
        expect(state.phase, SyncEnrollmentPhase.sessionReauthRequired);
        expect(state.reauthResumePhase, isNull);
        expect(store.validateHostedOperationState(state).isLegal, isFalse);
      },
    );
  });

  group('binding repair transitions', () {
    test(
      'enterBindingAuthorizationRequired disables writes and clears resume',
      () async {
        await store.enterSnapshotInProgress();
        await store.enterBindingAuthorizationRequired();
        final state = await snapshot();
        expect(
          state.deviceBindingState,
          SyncDeviceBindingState.authorizationRequired,
        );
        expect(state.phase, SyncEnrollmentPhase.bindingAuthorizationRequired);
        expect(state.writeEnabled, isFalse);
        expect(state.reauthResumePhase, isNull);
        expect(store.validateHostedOperationState(state).isLegal, isTrue);
      },
    );

    test('binding repair overrides a prior session reauth', () async {
      await seedRow(
        binding: SyncDeviceBindingState.bound,
        phase: SyncEnrollmentPhase.gateEnabled,
        writes: true,
      );
      expect(
        await store.enterSessionReauthRequired(),
        SessionReauthEntry.applied,
      );
      await store.enterBindingAuthorizationRequired();
      final state = await snapshot();
      expect(
        state.deviceBindingState,
        SyncDeviceBindingState.authorizationRequired,
      );
      expect(state.phase, SyncEnrollmentPhase.bindingAuthorizationRequired);
      expect(state.writeEnabled, isFalse);
      expect(state.reauthResumePhase, isNull);
    });

    test('enterSnapshotInProgress binds with writes disabled', () async {
      await store.enterBindingAuthorizationRequired();
      await store.enterSnapshotInProgress();
      final state = await snapshot();
      expect(state.deviceBindingState, SyncDeviceBindingState.bound);
      expect(state.phase, SyncEnrollmentPhase.snapshotInProgress);
      expect(state.writeEnabled, isFalse);
      expect(state.reauthResumePhase, isNull);
      expect(store.validateHostedOperationState(state).isLegal, isTrue);
    });

    test(
      'enterReconciliationComplete keeps the binding with writes disabled',
      () async {
        await store.enterSnapshotInProgress();
        await store.enterReconciliationComplete();
        final state = await snapshot();
        expect(state.deviceBindingState, SyncDeviceBindingState.bound);
        expect(state.phase, SyncEnrollmentPhase.reconciliationComplete);
        expect(state.writeEnabled, isFalse);
        expect(store.validateHostedOperationState(state).isLegal, isTrue);
      },
    );

    test(
      'enterGateEnabled enables writes from reconciliationComplete',
      () async {
        await store.enterReconciliationComplete();
        await store.enterGateEnabled();
        final state = await snapshot();
        expect(state.deviceBindingState, SyncDeviceBindingState.bound);
        expect(state.phase, SyncEnrollmentPhase.gateEnabled);
        expect(state.writeEnabled, isTrue);
        expect(state.reauthResumePhase, isNull);
        expect(store.validateHostedOperationState(state).isLegal, isTrue);
      },
    );

    test(
      'enterGateEnabled is refused from any other phase and persists nothing',
      () async {
        await store.enterSnapshotInProgress();
        await expectLater(
          store.enterGateEnabled(),
          throwsA(isA<SyncWriteGateException>()),
        );
        final state = await snapshot();
        expect(state.phase, SyncEnrollmentPhase.snapshotInProgress);
        expect(state.writeEnabled, isFalse);
      },
    );

    test(
      'enterGateEnabled rejects an illegal unbound reconciliationComplete row',
      () async {
        await seedRow(
          binding: SyncDeviceBindingState.authorizationRequired,
          phase: SyncEnrollmentPhase.reconciliationComplete,
          writes: false,
        );
        final before = await snapshot();
        await expectLater(
          store.enterGateEnabled(),
          throwsA(isA<SyncWriteGateException>()),
        );
        final after = await snapshot();
        expect(after.deviceBindingState, before.deviceBindingState);
        expect(after.phase, before.phase);
        expect(after.writeEnabled, before.writeEnabled);
        expect(after.reauthResumePhase, before.reauthResumePhase);
      },
    );
  });

  group('session reauth compare-and-set', () {
    test(
      'applies from each allowed phase and records it as the resume target',
      () async {
        for (final resume in [
          SyncEnrollmentPhase.snapshotInProgress,
          SyncEnrollmentPhase.reconciliationComplete,
          SyncEnrollmentPhase.gateEnabled,
        ]) {
          await seedRow(
            binding: SyncDeviceBindingState.bound,
            phase: resume,
            writes: resume == SyncEnrollmentPhase.gateEnabled,
          );
          expect(
            await store.enterSessionReauthRequired(),
            SessionReauthEntry.applied,
            reason: '$resume',
          );
          final state = await snapshot();
          expect(
            state.deviceBindingState,
            SyncDeviceBindingState.bound,
            reason: '$resume',
          );
          expect(
            state.phase,
            SyncEnrollmentPhase.sessionReauthRequired,
            reason: '$resume',
          );
          expect(state.writeEnabled, isFalse, reason: '$resume');
          expect(state.reauthResumePhase, resume, reason: '$resume');
          expect(
            store.validateHostedOperationState(state).isLegal,
            isTrue,
            reason: '$resume',
          );
        }
      },
    );

    test(
      'no-ops when already in session reauth and keeps the resume target',
      () async {
        await store.enterSnapshotInProgress();
        await store.enterReconciliationComplete();
        await store.enterGateEnabled();
        expect(
          await store.enterSessionReauthRequired(),
          SessionReauthEntry.applied,
        );
        final before = await snapshot();
        expect(
          await store.enterSessionReauthRequired(),
          SessionReauthEntry.alreadyInProgress,
        );
        final after = await snapshot();
        expect(after.phase, before.phase);
        expect(after.writeEnabled, before.writeEnabled);
        expect(after.deviceBindingState, before.deviceBindingState);
        expect(after.reauthResumePhase, before.reauthResumePhase);
        expect(after.reauthResumePhase, isNot(isNull));
      },
    );

    test('no-ops when binding repair is pending', () async {
      await store.enterBindingAuthorizationRequired();
      final before = await snapshot();
      expect(
        await store.enterSessionReauthRequired(),
        SessionReauthEntry.rejectedIllegalState,
      );
      final after = await snapshot();
      expect(after.phase, before.phase);
      expect(after.writeEnabled, before.writeEnabled);
      expect(after.deviceBindingState, before.deviceBindingState);
      expect(after.reauthResumePhase, before.reauthResumePhase);
    });

    test('no-ops when never bound', () async {
      final before = await snapshot();
      expect(
        await store.enterSessionReauthRequired(),
        SessionReauthEntry.rejectedIllegalState,
      );
      final after = await snapshot();
      expect(after.phase, before.phase);
      expect(after.writeEnabled, before.writeEnabled);
      expect(after.deviceBindingState, before.deviceBindingState);
      expect(after.reauthResumePhase, before.reauthResumePhase);
    });

    test(
      'rejects an illegal bound gateEnabled row with writes disabled',
      () async {
        await seedRow(
          binding: SyncDeviceBindingState.bound,
          phase: SyncEnrollmentPhase.gateEnabled,
          writes: false,
        );
        final before = await snapshot();
        expect(
          await store.enterSessionReauthRequired(),
          SessionReauthEntry.rejectedIllegalState,
        );
        final after = await snapshot();
        expect(after.phase, before.phase);
        expect(after.writeEnabled, before.writeEnabled);
        expect(after.deviceBindingState, before.deviceBindingState);
        expect(after.reauthResumePhase, before.reauthResumePhase);
      },
    );

    test(
      'rejects an illegal bound snapshotInProgress row with writes enabled',
      () async {
        await seedRow(
          binding: SyncDeviceBindingState.bound,
          phase: SyncEnrollmentPhase.snapshotInProgress,
          writes: true,
        );
        final before = await snapshot();
        expect(
          await store.enterSessionReauthRequired(),
          SessionReauthEntry.rejectedIllegalState,
        );
        final after = await snapshot();
        expect(after.phase, before.phase);
        expect(after.writeEnabled, before.writeEnabled);
        expect(after.deviceBindingState, before.deviceBindingState);
        expect(after.reauthResumePhase, before.reauthResumePhase);
      },
    );

    test('rejects a legal phase carrying a stale resume phase', () async {
      await seedRow(
        binding: SyncDeviceBindingState.bound,
        phase: SyncEnrollmentPhase.reconciliationComplete,
        writes: false,
        resume: SyncEnrollmentPhase.snapshotInProgress,
      );
      final before = await snapshot();
      expect(
        await store.enterSessionReauthRequired(),
        SessionReauthEntry.rejectedIllegalState,
      );
      final after = await snapshot();
      expect(after.phase, before.phase);
      expect(after.writeEnabled, before.writeEnabled);
      expect(after.deviceBindingState, before.deviceBindingState);
      expect(after.reauthResumePhase, before.reauthResumePhase);
    });

    test('rejects an illegal unbound sessionReauthRequired row instead of '
        'reporting it as already in progress', () async {
      await seedRow(
        binding: SyncDeviceBindingState.authorizationRequired,
        phase: SyncEnrollmentPhase.sessionReauthRequired,
        writes: false,
        resume: SyncEnrollmentPhase.gateEnabled,
      );
      final before = await snapshot();
      expect(
        await store.enterSessionReauthRequired(),
        SessionReauthEntry.rejectedIllegalState,
      );
      final after = await snapshot();
      expect(after.phase, before.phase);
      expect(after.writeEnabled, before.writeEnabled);
      expect(after.deviceBindingState, before.deviceBindingState);
      expect(after.reauthResumePhase, before.reauthResumePhase);
    });
  });

  group('session reauth restoration', () {
    test(
      'restores each resume phase and gates writes on gateEnabled',
      () async {
        for (final resume in [
          SyncEnrollmentPhase.snapshotInProgress,
          SyncEnrollmentPhase.reconciliationComplete,
          SyncEnrollmentPhase.gateEnabled,
        ]) {
          await seedRow(
            binding: SyncDeviceBindingState.bound,
            phase: resume,
            writes: resume == SyncEnrollmentPhase.gateEnabled,
          );
          expect(
            await store.enterSessionReauthRequired(),
            SessionReauthEntry.applied,
            reason: '$resume',
          );
          final restored = await store.restoreFromSessionReauth();
          expect(restored, resume, reason: '$resume');
          final state = await snapshot();
          expect(state.phase, resume, reason: '$resume');
          expect(
            state.deviceBindingState,
            SyncDeviceBindingState.bound,
            reason: '$resume',
          );
          expect(state.reauthResumePhase, isNull, reason: '$resume');
          expect(
            state.writeEnabled,
            resume == SyncEnrollmentPhase.gateEnabled,
            reason: '$resume',
          );
          expect(
            store.validateHostedOperationState(state).isLegal,
            isTrue,
            reason: '$resume',
          );
        }
      },
    );

    test(
      'refuses restoration outside session reauth and persists nothing',
      () async {
        final before = await snapshot();
        await expectLater(
          store.restoreFromSessionReauth(),
          throwsA(isA<SyncRepairTransitionException>()),
        );
        final after = await snapshot();
        expect(after.phase, before.phase);
        expect(after.writeEnabled, before.writeEnabled);
        expect(after.deviceBindingState, before.deviceBindingState);
        expect(after.reauthResumePhase, before.reauthResumePhase);
      },
    );

    test(
      'refuses restoration of an illegal writes-enabled sessionReauthRequired '
      'row and persists nothing',
      () async {
        await seedRow(
          binding: SyncDeviceBindingState.bound,
          phase: SyncEnrollmentPhase.sessionReauthRequired,
          writes: true,
          resume: SyncEnrollmentPhase.gateEnabled,
        );
        final before = await snapshot();
        await expectLater(
          store.restoreFromSessionReauth(),
          throwsA(isA<SyncRepairTransitionException>()),
        );
        final after = await snapshot();
        expect(after.phase, before.phase);
        expect(after.writeEnabled, before.writeEnabled);
        expect(after.deviceBindingState, before.deviceBindingState);
        expect(after.reauthResumePhase, before.reauthResumePhase);
      },
    );
  });
}
