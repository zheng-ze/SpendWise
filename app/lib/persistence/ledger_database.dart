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
    onUpgrade: (db, from, to) async {
      // Sync stores enter at v4: create every table the sync layer needs.
      if (from < 4) {
        await _createSyncTables(db);
      }
    },
  );

  /// Creates the five additive sync tables introduced at schema v4. The DDL
  /// mirrors the table definitions in `tables.dart` so a live database gains
  /// exactly the columns the generated rows expect. Table-level CHECK
  /// constraints trail the column definitions because SQLite rejects them
  /// between columns.
  Future<void> _createSyncTables(Migrator db) async {
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
      'version_data BLOB NOT NULL'
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
  }
}
