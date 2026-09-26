import 'package:drift/drift.dart';
import 'package:spendwise/persistence/tables.dart';
import 'package:spendwise/sync/sync_tables.dart';
import 'package:sync/sync.dart';

part 'ledger_database.g.dart';

@DriftDatabase(
  tables: [
    Accounts,
    SubPockets,
    Categories,
    Entries,
    Plans,
    Budgets,
    StoreMeta,
    SyncMeta,
    SyncAcknowledgedVectors,
    SyncPendingAcknowledgements,
    SyncStagedConflicts,
    SyncStagedSiblings,
    SyncOrphanTombstones,
  ],
)
class LedgerDatabase extends _$LedgerDatabase {
  LedgerDatabase(super.executor);

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 4) {
        await m.createAll();
      }
      if (from < 5) {
        await m.createAll();
      }
      if (from >= 4 && from < 6) {
        await m.addColumn(syncMeta, syncMeta.deviceBindingState);
        await m.addColumn(syncMeta, syncMeta.reauthResumePhase);
        // Binding states: 0 = notApplicable, 1 = authorizationRequired,
        // 2 = bound. Custom rows keep their backend selection so a later
        // ticket can show an unsupported-protocol notice instead of
        // Supabase recovery.
        await m.database.customStatement(
          'UPDATE sync_meta SET enrollment_phase = 0, '
          'device_binding_state = 0, write_enabled = 0 '
          "WHERE id = 0 AND backend = 'custom'",
        );
        await m.database.customStatement(
          'UPDATE sync_meta SET device_binding_state = 1, write_enabled = 0 '
          "WHERE id = 0 AND backend = 'supabase' AND enrollment_phase = 1",
        );
        await m.database.customStatement(
          'UPDATE sync_meta SET device_binding_state = 1, '
          'enrollment_phase = 5, write_enabled = 0 '
          "WHERE id = 0 AND backend = 'supabase' AND enrollment_phase IN "
          '(2, 3, 4)',
        );
      }
    },
  );
}
