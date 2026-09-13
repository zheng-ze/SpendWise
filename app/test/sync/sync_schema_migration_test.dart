import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sync/sync.dart';
import 'package:spendwise/persistence/ledger_database.dart';
import 'package:spendwise/sync/drift_sync_staging_store.dart';
import 'package:spendwise/sync/sync_metadata_store.dart';

void main() {
  LedgerDatabase? db;

  tearDown(() async {
    await db?.close();
    db = null;
  });

  /// Opens a database that already lived through schema v3, so constructing
  /// the v4 [LedgerDatabase] on it runs the v3-to-v4 upgrade path instead of
  /// a fresh create.
  Future<LedgerDatabase> openUpgraded() async {
    final executor = NativeDatabase.memory(
      setup: (raw) {
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

  test('upgraded payload columns reject null like a fresh database', () async {
    final database = await openUpgraded();

    final watermark = await notNullColumns(database, 'sync_watermark');
    expect(watermark['version_data'], 1);

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

  test('upgraded database serves both sync stores', () async {
    final database = await openUpgraded();
    final metadata = SyncMetadataStore(database);
    final staging = DriftSyncStagingStore(database);

    // Pre-enrollment defaults on the migrated store.
    expect(await metadata.getBackendSelection(), isNull);
    expect(await metadata.getPhase(), isNull);
    expect(await metadata.isWriteGateEnabled(), isFalse);

    final rowID = SyncRowID.of(SyncCollection.entries, 'e1');
    await metadata.commitPullPage(
      collection: SyncCollection.entries,
      checkpoint: 'cp-1',
      watermark: VersionVector({'deviceA': 2}),
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

    expect(await staging.pendingConflicts, isEmpty);
  });
}
