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
  ],
)
class LedgerDatabase extends _$LedgerDatabase {
  LedgerDatabase(super.executor);

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async => m.createAll(),
    // Additive only: later versions create their tables with
    // CREATE TABLE IF NOT EXISTS, so existing user rows are preserved.
    onUpgrade: (m, from, to) async {
      if (from < 4) {
        await m.createAll();
      }
    },
  );
}
