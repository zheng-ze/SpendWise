import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sync/sync.dart';
import 'package:spendwise/persistence/ledger_database.dart';
import 'package:spendwise/sync/drift_sync_staging_store.dart';
import 'package:spendwise/sync/sync_metadata_store.dart';

// Opens a raw connection without running migrations for schema probes.
final class _NoMigration implements QueryExecutorUser {
  const _NoMigration();

  @override
  int get schemaVersion => 4;

  @override
  Future<void> beforeOpen(
    QueryExecutor executor,
    OpeningDetails details,
  ) async {}
}

void main() {
  LedgerDatabase? db;

  tearDown(() async {
    await db?.close();
    db = null;
  });

  // Reads the real CREATE TABLE statement from a scratch database
  // for the pre-upgrade fixture.
  Future<String> userTableDdl(String table) async {
    final scratch = LedgerDatabase(NativeDatabase.memory());
    try {
      await scratch.customSelect('SELECT 1').get();
      final row = await scratch
          .customSelect(
            "SELECT sql FROM sqlite_master WHERE type = 'table' AND name = '$table'",
          )
          .getSingle();
      return row.read<String>('sql');
    } finally {
      await scratch.close();
    }
  }

  // Opens a v3 database with one account row, so the open runs the upgrade.
  // Proves existing user data survives the migration.
  Future<LedgerDatabase> openUpgraded() async {
    final accountsDdl = await userTableDdl('accounts');
    final executor = NativeDatabase.memory(
      setup: (raw) {
        raw.execute(accountsDdl);
        raw.execute(
          'INSERT INTO accounts (id, name, type, sub_pocket_ids, '
          'incoming_transfers_as_expenses, include_in_net_worth, '
          'statement_day, version_data, lifecycle) '
          "VALUES ('acct-1', 'Cash', 0, '[]', 0, 1, NULL, X'00', 0)",
        );
        raw.execute('PRAGMA user_version = 3');
      },
    );
    final upgraded = LedgerDatabase(executor);
    // Trigger the open and the upgrade.
    await upgraded.customSelect('SELECT 1').get();
    db = upgraded;
    return upgraded;
  }

  Future<Map<String, int>> notNullColumns(
    LedgerDatabase database,
    String table,
  ) async {
    final rows = await database.customSelect('PRAGMA table_info($table)').get();
    return {
      for (final row in rows)
        row.read<String>('name'): row.read<int>('notnull'),
    };
  }

  test('v3 to v4 upgrade creates the sync tables', () async {
    final database = await openUpgraded();

    for (final table in [
      'sync_metadata',
      'sync_watermark',
      'sync_acknowledged_vector',
      'sync_pending_ack',
      'sync_staging_group',
    ]) {
      final rows = await database
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'table' AND name = '$table'",
          )
          .get();
      expect(rows, hasLength(1), reason: 'missing table $table');
    }

    final version = await database
        .customSelect('PRAGMA user_version')
        .getSingle();
    expect(version.read<int>('user_version'), 4);

    final metadataSql = await database
        .customSelect(
          "SELECT sql FROM sqlite_master WHERE type = 'table' AND name = 'sync_metadata'",
        )
        .getSingle();
    expect(metadataSql.read<String>('sql'), contains('CHECK (id = 0)'));
  });

  test('v3 to v4 upgrade preserves existing user data', () async {
    final database = await openUpgraded();

    // The pre-v4 account row is still present, unchanged, after the upgrade.
    final accounts = await database.select(database.accounts).get();
    expect(accounts, hasLength(1));
    final account = accounts.single;
    expect(account.id, 'acct-1');
    expect(account.name, 'Cash');
    expect(account.type, 0);
    expect(account.subPocketIds, '[]');
    expect(account.incomingTransfersAsExpenses, isFalse);
    expect(account.includeInNetWorth, isTrue);
    expect(account.statementDay, isNull);
    expect(account.versionData, [0]);
    expect(account.lifecycle, 0);
  });

  test('upgraded payload columns reject null like a fresh database', () async {
    final database = await openUpgraded();

    final watermark = await notNullColumns(database, 'sync_watermark');
    expect(watermark['cursor'], 1);

    final acknowledged = await notNullColumns(
      database,
      'sync_acknowledged_vector',
    );
    expect(acknowledged['version_data'], 1);

    final staging = await notNullColumns(database, 'sync_staging_group');
    expect(staging['sibling_data'], 1);

    final metadata = await notNullColumns(database, 'sync_metadata');
    expect(metadata['write_gate'], 1);

    final gateDefault = await database
        .customSelect('PRAGMA table_info(sync_metadata)')
        .get();
    final writeGate = gateDefault.firstWhere(
      (row) => row.read<String>('name') == 'write_gate',
    );
    expect(writeGate.read<String?>('dflt_value'), '0');
  });

  test('a mid-migration failure rolls back and the retry completes', () async {
    final directory = await Directory.systemTemp.createTemp(
      'migration-atomicity',
    );
    try {
      final path = '${directory.path}${Platform.pathSeparator}ledger.db';
      final accountsDdl = await userTableDdl('accounts');

      // Plants a conflicting table so the migration fails partway.
      // Rollback keeps the plant and removes what the run created.
      final failingDb = LedgerDatabase(
        NativeDatabase(
          File(path),
          setup: (raw) {
            raw.execute(accountsDdl);
            raw.execute(
              'INSERT INTO accounts (id, name, type, sub_pocket_ids, '
              'incoming_transfers_as_expenses, include_in_net_worth, '
              'statement_day, version_data, lifecycle) '
              "VALUES ('acct-1', 'Cash', 0, '[]', 0, 1, NULL, X'00', 0)",
            );
            raw.execute(
              'CREATE TABLE sync_pending_ack ('
              'collection TEXT NOT NULL, '
              'checkpoint TEXT NOT NULL, '
              'PRIMARY KEY (collection, checkpoint)'
              ')',
            );
            raw.execute('PRAGMA user_version = 3');
          },
        ),
      );
      await expectLater(
        failingDb.customSelect('SELECT 1').get(),
        throwsA(isA<Exception>()),
      );
      await failingDb.close();

      // Probes through a raw connection without migrations, so the probe
      // never changes the version or runs the upgrade.
      Future<({Set<String> tables, int version})> probeSchema() async {
        final probe = NativeDatabase(File(path), enableMigrations: false);
        try {
          await probe.ensureOpen(const _NoMigration());
          final rows = await probe.runSelect(
            "SELECT name FROM sqlite_master WHERE type = 'table' "
            "AND name LIKE 'sync_%'",
            <Object?>[],
          );
          final versions = await probe.runSelect(
            'PRAGMA user_version',
            <Object?>[],
          );
          return (
            tables: {for (final row in rows) (row['name'] as String)},
            version: versions.single['user_version'] as int,
          );
        } finally {
          await probe.close();
        }
      }

      // The failed run leaves no partial schema. Only the plant remains
      // with the version still at 3.
      final failed = await probeSchema();
      expect(failed.tables, {'sync_pending_ack'});
      expect(failed.version, 3);

      // Remove the conflicting plant, as a crash recovery would leave no
      // conflict behind, then retry from the clean v3 state.
      final cleaner = NativeDatabase(File(path), enableMigrations: false);
      try {
        await cleaner.ensureOpen(const _NoMigration());
        await cleaner.runCustom('DROP TABLE sync_pending_ack');
      } finally {
        await cleaner.close();
      }

      // A subsequent normal open completes the full upgrade, preserving
      // the pre-v4 user data.
      final database = LedgerDatabase(NativeDatabase(File(path)));
      db = database;
      await database.customSelect('SELECT 1').get();
      for (final table in [
        'sync_metadata',
        'sync_watermark',
        'sync_acknowledged_vector',
        'sync_pending_ack',
        'sync_staging_group',
      ]) {
        final rows = await database
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type = 'table' "
              "AND name = '$table'",
            )
            .get();
        expect(rows, hasLength(1), reason: 'missing table $table');
      }
      final upgradedVersion = await database
          .customSelect('PRAGMA user_version')
          .getSingle();
      expect(upgradedVersion.read<int>('user_version'), 4);
      final accounts = await database.select(database.accounts).get();
      expect(accounts.map((account) => account.id).toList(), ['acct-1']);

      // The retried schema serves the stores, with watermarks as opaque
      // pull cursors.
      final metadata = SyncMetadataStore(database);
      await metadata.setWatermark(SyncCollection.entries, 'cp-checkpoint-7');
      expect(
        await metadata.getWatermark(SyncCollection.entries),
        'cp-checkpoint-7',
      );
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('upgraded database serves both sync stores', () async {
    final database = await openUpgraded();
    final metadata = SyncMetadataStore(database);
    final staging = await DriftSyncStagingStore.open(database);

    // Checks pre-enrollment defaults on the migrated store.
    expect(await metadata.getBackendSelection(), isNull);
    expect(await metadata.getPhase(), isNull);
    expect(await metadata.isWriteGateEnabled(), isFalse);

    final rowID = SyncRowID.of(SyncCollection.entries, 'e1');
    await metadata.commitPullPage(
      collection: SyncCollection.entries,
      checkpoint: 'cp-1',
      watermark: 'cp-checkpoint-7',
      acknowledgedVectors: {
        rowID: VersionVector({'deviceA': 2}),
      },
    );
    expect(
      await metadata.getAcknowledgedVector(rowID),
      VersionVector({'deviceA': 2}),
    );
    expect(
      await metadata.hasPendingAck(SyncCollection.entries, 'cp-1'),
      isTrue,
    );

    expect(staging.pendingConflicts, isEmpty);
  });
}
