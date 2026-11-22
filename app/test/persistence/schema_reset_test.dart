import 'package:domain/domain.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/persistence/database/ledger_database.dart';
import 'package:spendwise/persistence/store/drift_ledger_store.dart';

import '../support/ledger_fixtures.dart';

const _freshVersion = 9;
const _legacyVersion = 8;

const _ledgerTables = {
  'accounts',
  'sub_pockets',
  'categories',
  'entries',
  'plans',
  'budgets',
};

const _freshTables = {..._ledgerTables, 'store_meta'};

const _legacyStatements = [
  'CREATE TABLE sync_meta (id INTEGER NOT NULL PRIMARY KEY, backend TEXT)',
  'INSERT INTO sync_meta (id, backend) VALUES (0, \'hosted\')',
  'CREATE TABLE accounts (id TEXT NOT NULL PRIMARY KEY, name TEXT NOT NULL, '
      'version_data BLOB NOT NULL, lifecycle INTEGER NOT NULL)',
  'INSERT INTO accounts (id, name, version_data, lifecycle) '
      'VALUES (\'a1\', \'old\', x\'00\', 0)',
  'CREATE TABLE store_meta (id INTEGER NOT NULL PRIMARY KEY, '
      'device_id TEXT NOT NULL, has_seeded INTEGER NOT NULL DEFAULT 0)',
  'INSERT INTO store_meta (id, device_id, has_seeded) VALUES (0, \'d\', 1)',
  'PRAGMA user_version = $_legacyVersion',
];

void main() {
  late LedgerDatabase db;

  tearDown(() => db.close());

  Future<Set<String>> tableNames() async {
    final rows = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type='table' "
          "AND name NOT LIKE 'sqlite_%'",
        )
        .get();
    return {for (final row in rows) row.read<String>('name')};
  }

  Future<Set<String>> columnNames(String table) async {
    final rows = await db.customSelect('PRAGMA table_info($table)').get();
    return {for (final row in rows) row.read<String>('name')};
  }

  Future<int> userVersion() async {
    final row = await db.customSelect('PRAGMA user_version').getSingle();
    return row.read<int>('user_version');
  }

  LedgerDatabase openLegacyDatabase() => LedgerDatabase(
    NativeDatabase.memory(
      setup: (raw) {
        for (final statement in _legacyStatements) {
          raw.execute(statement);
        }
      },
    ),
  );

  List<LedgerChange> seedChanges() => [
    UpsertAccount(testAccount(id: 'a1', name: 'wallet')),
    UpsertEntry(
      testEntry(id: 'e1', sourceID: 'a1', date: DateTime.utc(2026, 3, 14)),
    ),
  ];

  test('a fresh open creates exactly the ledger tables at version 9', () async {
    db = LedgerDatabase(NativeDatabase.memory());

    expect(await tableNames(), _freshTables);
    expect(await userVersion(), _freshVersion);
  });

  test('a v8 database opens to the fresh schema with no old data', () async {
    db = openLegacyDatabase();

    final tables = await tableNames();
    expect(tables, _freshTables);
    expect(tables.where((name) => name.startsWith('sync_')), isEmpty);
    expect(await columnNames('accounts'), isNot(contains('version_data')));
    expect(await columnNames('store_meta'), {'id', 'has_seeded'});
    expect(await userVersion(), _freshVersion);
    for (final table in _freshTables) {
      final count = db.customSelect('SELECT COUNT(*) AS c FROM $table');
      expect((await count.getSingle()).read<int>('c'), 0, reason: table);
    }
  });

  test('a reset v8 database seeds again on first launch', () async {
    db = openLegacyDatabase();
    final store = DriftLedgerStore(db);
    await store.start();

    await store.seedIfFirstLaunch(seedChanges());

    final state = await store.load();
    expect(state.entries.keys.toSet(), {'e1'});
    expect(state.moneySources.keys.toSet(), {'a1'});
  });
}
