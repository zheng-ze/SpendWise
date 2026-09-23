import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/persistence/ledger_database.dart';
import 'package:spendwise/sync/drift_sync_staging_store.dart';
import 'package:spendwise/sync/sync_metadata_store.dart';
import 'package:sync/sync.dart';

const _v3Accounts = '''
CREATE TABLE accounts (
  id TEXT NOT NULL PRIMARY KEY,
  name TEXT NOT NULL,
  type INTEGER NOT NULL,
  sub_pocket_ids TEXT NOT NULL,
  incoming_transfers_as_expenses INTEGER NOT NULL
    CHECK (incoming_transfers_as_expenses IN (0, 1)),
  include_in_net_worth INTEGER NOT NULL
    CHECK (include_in_net_worth IN (0, 1)),
  statement_day INTEGER NULL,
  version_data BLOB NOT NULL,
  lifecycle INTEGER NOT NULL
);
''';

const _v3Entries = '''
CREATE TABLE entries (
  id TEXT NOT NULL PRIMARY KEY,
  date INTEGER NOT NULL,
  amount TEXT NOT NULL,
  name TEXT NOT NULL,
  category_id TEXT NULL,
  source_id TEXT NOT NULL,
  destination_id TEXT NULL,
  include_in_analysis INTEGER NOT NULL
    CHECK (include_in_analysis IN (0, 1)),
  note TEXT NULL,
  system_kind INTEGER NULL,
  version_data BLOB NOT NULL,
  lifecycle INTEGER NOT NULL
);
''';

const _v3StoreMeta = '''
CREATE TABLE store_meta (
  id INTEGER NOT NULL PRIMARY KEY,
  device_id TEXT NOT NULL,
  has_seeded INTEGER NOT NULL
    CHECK (has_seeded IN (0, 1)) DEFAULT 0,
  CHECK (id = 0)
);
''';

void main() {
  test('the v3 to v4 migration preserves existing user rows', () async {
    final executor = NativeDatabase.memory(
      setup: (raw) {
        raw.execute(_v3Accounts);
        raw.execute(_v3Entries);
        raw.execute(_v3StoreMeta);
        raw.execute(
          "INSERT INTO accounts (id, name, type, sub_pocket_ids, "
          "incoming_transfers_as_expenses, include_in_net_worth, statement_day, "
          "version_data, lifecycle) VALUES "
          "('aaaaaaaa-0000-1111-2222-333333333333', 'Checking', 0, '[]', 0, 1, "
          "NULL, X'7B7D', 0)",
        );
        raw.execute(
          "INSERT INTO entries (id, date, amount, name, category_id, source_id, "
          "destination_id, include_in_analysis, note, system_kind, version_data, "
          "lifecycle) VALUES "
          "('eeeeeeee-0000-1111-2222-777777777777', 1710460800000, '-12.50', "
          "'Coffee', NULL, 'aaaaaaaa-0000-1111-2222-333333333333', NULL, 1, "
          "NULL, NULL, X'7B7D', 0)",
        );
        raw.execute(
          "INSERT INTO store_meta (id, device_id, has_seeded) VALUES "
          "(0, 'bbbbbbbb-0000-1111-2222-444444444444', 1)",
        );
        raw.execute('PRAGMA user_version = 3');
      },
    );

    final db = LedgerDatabase(executor);
    addTearDown(db.close);

    final metadata = SyncMetadataStore(db);
    final staging = await DriftSyncStagingStore.open(db);
    expect(await staging.pendingConflictList(), isEmpty);
    expect((await metadata.snapshot()).backend, isNull);

    final accounts = await db
        .customSelect('SELECT id, name, version_data FROM accounts')
        .get();
    expect(accounts, hasLength(1));
    expect(
      accounts.single.read<String>('id'),
      'aaaaaaaa-0000-1111-2222-333333333333',
    );
    expect(accounts.single.read<String>('name'), 'Checking');

    final entries = await db
        .customSelect('SELECT id, amount FROM entries')
        .get();
    expect(entries, hasLength(1));
    expect(
      entries.single.read<String>('id'),
      'eeeeeeee-0000-1111-2222-777777777777',
    );
    expect(entries.single.read<String>('amount'), '-12.50');

    final meta = await db
        .customSelect('SELECT device_id FROM store_meta')
        .get();
    expect(
      meta.single.read<String>('device_id'),
      'bbbbbbbb-0000-1111-2222-444444444444',
    );

    final syncTables = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' AND "
          "name LIKE 'sync_%'",
        )
        .get();
    expect(
      {for (final row in syncTables) row.read<String>('name')},
      {
        'sync_meta',
        'sync_acknowledged_vectors',
        'sync_pending_acknowledgements',
        'sync_staged_conflicts',
        'sync_staged_siblings',
        'sync_orphan_tombstones',
      },
    );
  });

  test('a fresh database creates the orphan tombstone table', () async {
    final db = LedgerDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final tables = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' AND "
          "name = 'sync_orphan_tombstones'",
        )
        .get();
    expect(tables, hasLength(1));

    final columns = await db
        .customSelect('PRAGMA table_info(sync_orphan_tombstones)')
        .get();
    expect(
      {for (final row in columns) row.read<String>('name')},
      {'collection', 'row_id', 'version_data'},
    );
  });

  test('the v4 to v5 migration preserves existing rows and adds the orphan '
      'table', () async {
    final executor = NativeDatabase.memory(
      setup: (raw) {
        raw.execute(_v3Accounts);
        raw.execute(_v3Entries);
        raw.execute(_v3StoreMeta);
        raw.execute(
          'CREATE TABLE sync_acknowledged_vectors ('
          'collection TEXT NOT NULL, '
          'row_id TEXT NOT NULL, '
          'version_data BLOB NOT NULL, '
          'PRIMARY KEY (collection, row_id))',
        );
        raw.execute(
          "INSERT INTO accounts (id, name, type, sub_pocket_ids, "
          "incoming_transfers_as_expenses, include_in_net_worth, statement_day, "
          "version_data, lifecycle) VALUES "
          "('aaaaaaaa-0000-1111-2222-333333333333', 'Checking', 0, '[]', 0, 1, "
          "NULL, X'7B7D', 0)",
        );
        raw.execute(
          "INSERT INTO sync_acknowledged_vectors (collection, row_id, "
          "version_data) VALUES ('entries', "
          "'eeeeeeee-0000-1111-2222-777777777777', X'7B7D')",
        );
        raw.execute(
          "INSERT INTO store_meta (id, device_id, has_seeded) VALUES "
          "(0, 'bbbbbbbb-0000-1111-2222-444444444444', 1)",
        );
        raw.execute('PRAGMA user_version = 4');
      },
    );

    final db = LedgerDatabase(executor);
    addTearDown(db.close);

    await db
        .into(db.syncOrphanTombstones)
        .insert(
          OrphanTombstoneRow(
            collection: SyncCollection.entries,
            rowId: 'eeeeeeee-0000-1111-2222-777777777777',
            versionData: VersionVector({'remote-a': 1}),
          ),
        );
    expect(await db.select(db.syncOrphanTombstones).get(), hasLength(1));

    final accounts = await db
        .customSelect('SELECT id, name FROM accounts')
        .get();
    expect(accounts, hasLength(1));
    expect(
      accounts.single.read<String>('id'),
      'aaaaaaaa-0000-1111-2222-333333333333',
    );
    expect(accounts.single.read<String>('name'), 'Checking');

    final acknowledged = await db
        .customSelect(
          'SELECT collection, row_id FROM sync_acknowledged_vectors',
        )
        .get();
    expect(acknowledged, hasLength(1));
    expect(acknowledged.single.read<String>('collection'), 'entries');
    expect(
      acknowledged.single.read<String>('row_id'),
      'eeeeeeee-0000-1111-2222-777777777777',
    );

    final syncTables = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' AND "
          "name LIKE 'sync_%'",
        )
        .get();
    expect(
      {for (final row in syncTables) row.read<String>('name')},
      {
        'sync_meta',
        'sync_acknowledged_vectors',
        'sync_pending_acknowledgements',
        'sync_staged_conflicts',
        'sync_staged_siblings',
        'sync_orphan_tombstones',
      },
    );
  });
}
