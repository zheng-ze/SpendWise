import 'package:drift/drift.dart';
import 'package:spendwise/persistence/tables.dart';

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
    SyncMetadata,
    SyncWatermark,
    SyncAcknowledgedVector,
    SyncPendingAck,
    SyncStagingGroup,
  ],
)
class LedgerDatabase extends _$LedgerDatabase {
  LedgerDatabase(super.executor);

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      // Creates sync tables for upgrades from before v4. Budgets entered
      // at v2 without its own migration step, so pre-v4 databases may
      // lack the table even when stamped v2 or v3. createTable is
      // IF NOT EXISTS, so it repairs that gap without touching tables
      // that already exist.
      if (from < 4) {
        await m.createTable(budgets);
        await _createSyncTables(m);
      }
    },
  );

  // Creates sync tables in one transaction so a crash rolls back a
  // partial upgrade. Keeps CHECK constraints after columns.
  Future<void> _createSyncTables(Migrator db) async {
    await db.database.transaction(() async {
      await db.database.customStatement(
        'CREATE TABLE sync_metadata ('
        'id INTEGER NOT NULL PRIMARY KEY, '
        'backend_selection TEXT, '
        'enrollment_phase INTEGER, '
        'write_gate INTEGER NOT NULL DEFAULT 0 CHECK (write_gate IN (0, 1)), '
        'CHECK (id = 0)'
        ')',
      );
      await db.database.customStatement(
        'CREATE TABLE sync_watermark ('
        'collection TEXT NOT NULL PRIMARY KEY, '
        'cursor TEXT NOT NULL'
        ')',
      );
      await db.database.customStatement(
        'CREATE TABLE sync_acknowledged_vector ('
        'collection TEXT NOT NULL, '
        'row_id TEXT NOT NULL, '
        'version_data BLOB NOT NULL, '
        'PRIMARY KEY (collection, row_id)'
        ')',
      );
      await db.database.customStatement(
        'CREATE TABLE sync_pending_ack ('
        'collection TEXT NOT NULL, '
        'checkpoint TEXT NOT NULL, '
        'PRIMARY KEY (collection, checkpoint)'
        ')',
      );
      await db.database.customStatement(
        'CREATE TABLE sync_staging_group ('
        'sequence INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, '
        'collection TEXT NOT NULL, '
        'row_id TEXT NOT NULL, '
        'sibling_data BLOB NOT NULL, '
        'UNIQUE (collection, row_id)'
        ')',
      );
    });
  }
}
