import 'package:drift/drift.dart';
import 'package:spendwise/persistence/database/tables.dart';

part 'ledger_database.g.dart';

const _freshSchemaVersion = 9;

const _listTablesSql =
    "SELECT name FROM sqlite_master WHERE type='table' "
    "AND name NOT LIKE 'sqlite_%'";

// MARK: - Database

@DriftDatabase(
  tables: [
    Accounts,
    SubPockets,
    Categories,
    Entries,
    Plans,
    Budgets,
    StoreMeta,
  ],
)
class LedgerDatabase extends _$LedgerDatabase {
  LedgerDatabase(super.executor);

  @override
  int get schemaVersion => _freshSchemaVersion;

  // MARK: - Migration

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from >= _freshSchemaVersion) return;
      // The upgrade wipes the old database rather than migrating it.
      final rows = await m.database.customSelect(_listTablesSql).get();
      for (final row in rows) {
        final name = row.read<String>('name');
        await m.database.customStatement('DROP TABLE IF EXISTS "$name"');
      }
      await m.createAll();
    },
  );
}
