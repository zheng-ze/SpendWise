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

const _v5SyncMeta = '''
CREATE TABLE sync_meta (
  id INTEGER NOT NULL PRIMARY KEY,
  backend TEXT NULL,
  endpoint TEXT NULL,
  enrollment_phase INTEGER NOT NULL DEFAULT 0,
  write_enabled INTEGER NOT NULL DEFAULT 0
    CHECK (write_enabled IN (0, 1)),
  money_sources_cursor TEXT NULL,
  entries_cursor TEXT NULL,
  categories_cursor TEXT NULL,
  plans_cursor TEXT NULL,
  budgets_cursor TEXT NULL,
  CHECK (id = 0)
);
''';

LedgerDatabase _openUpgradedSyncMeta({
  required int fromVersion,
  String? backend,
  String? endpoint,
  int phase = 0,
  bool writeEnabled = false,
}) {
  final executor = NativeDatabase.memory(
    setup: (raw) {
      raw.execute(_v5SyncMeta);
      final backendSql = backend == null ? 'NULL' : "'$backend'";
      final endpointSql = endpoint == null ? 'NULL' : "'$endpoint'";
      raw.execute(
        'INSERT INTO sync_meta (id, backend, endpoint, enrollment_phase, '
        'write_enabled) VALUES (0, $backendSql, $endpointSql, $phase, '
        '${writeEnabled ? 1 : 0})',
      );
      raw.execute('PRAGMA user_version = $fromVersion');
    },
  );
  return LedgerDatabase(executor);
}

typedef _RemapCase = ({
  String? backend,
  String? endpoint,
  int phase,
  bool writeEnabled,
  int expectedPhase,
  int expectedBinding,
});

Future<void> _expectV6Columns(LedgerDatabase db) async {
  final columns = await db.customSelect('PRAGMA table_info(sync_meta)').get();
  final byName = {for (final row in columns) row.read<String>('name'): row};
  expect(byName['device_binding_state']!.read<String>('type'), 'INTEGER');
  expect(byName['device_binding_state']!.read<int>('notnull'), 1);
  expect(byName['device_binding_state']!.read<String?>('dflt_value'), '0');
  expect(byName['reauth_resume_phase']!.read<String>('type'), 'INTEGER');
  expect(byName['reauth_resume_phase']!.read<int>('notnull'), 0);
  expect(byName['reauth_resume_phase']!.read<String?>('dflt_value'), isNull);
}

Future<Map<String, Object?>> _readSyncMetaRow(LedgerDatabase db) async {
  final row = await db
      .customSelect(
        'SELECT backend, endpoint, enrollment_phase, write_enabled, '
        'device_binding_state, reauth_resume_phase FROM sync_meta '
        'WHERE id = 0',
      )
      .getSingle();
  return {
    'backend': row.readNullable<String>('backend'),
    'endpoint': row.readNullable<String>('endpoint'),
    'phase': row.read<int>('enrollment_phase'),
    'writeEnabled': row.read<bool>('write_enabled'),
    'bindingState': row.read<int>('device_binding_state'),
    'resumePhase': row.readNullable<int>('reauth_resume_phase'),
  };
}

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
        raw.execute(_v5SyncMeta);
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

  test('SyncEnrollmentPhase decodes the v6 binding-repair codes', () {
    expect(
      SyncEnrollmentPhase.fromCode(5),
      SyncEnrollmentPhase.bindingAuthorizationRequired,
    );
    expect(
      SyncEnrollmentPhase.fromCode(6),
      SyncEnrollmentPhase.sessionReauthRequired,
    );
  });

  test('a 5-to-6 upgrade disables a custom-backend row but keeps its '
      'selection', () async {
    final db = _openUpgradedSyncMeta(
      fromVersion: 5,
      backend: 'custom',
      endpoint: 'https://sync.example.com',
      phase: 4,
      writeEnabled: true,
    );
    addTearDown(db.close);

    expect(await _readSyncMetaRow(db), {
      'backend': 'custom',
      'endpoint': 'https://sync.example.com',
      'phase': 0,
      'writeEnabled': false,
      'bindingState': 0,
      'resumePhase': isNull,
    });
  });

  test(
    'a 5-to-6 upgrade keeps credentialAcquired but closes the write gate',
    () async {
      final db = _openUpgradedSyncMeta(
        fromVersion: 5,
        backend: 'supabase',
        phase: 1,
        writeEnabled: true,
      );
      addTearDown(db.close);

      expect(await _readSyncMetaRow(db), {
        'backend': 'supabase',
        'endpoint': isNull,
        'phase': 1,
        'writeEnabled': false,
        'bindingState': 1,
        'resumePhase': isNull,
      });
    },
  );

  test('a 5-to-6 upgrade remaps post-credential hosted phases to binding '
      'repair', () async {
    for (final phase in [2, 3, 4]) {
      final db = _openUpgradedSyncMeta(
        fromVersion: 5,
        backend: 'supabase',
        phase: phase,
        writeEnabled: true,
      );
      addTearDown(db.close);

      expect(await _readSyncMetaRow(db), {
        'backend': 'supabase',
        'endpoint': isNull,
        'phase': 5,
        'writeEnabled': false,
        'bindingState': 1,
        'resumePhase': isNull,
      }, reason: 'phase $phase');
    }
  });

  test('a 5-to-6 upgrade leaves unenrolled rows untouched', () async {
    final withoutBackend = _openUpgradedSyncMeta(fromVersion: 5);
    addTearDown(withoutBackend.close);
    expect(await _readSyncMetaRow(withoutBackend), {
      'backend': isNull,
      'endpoint': isNull,
      'phase': 0,
      'writeEnabled': false,
      'bindingState': 0,
      'resumePhase': isNull,
    });

    final unenrolledHosted = _openUpgradedSyncMeta(
      fromVersion: 5,
      backend: 'supabase',
    );
    addTearDown(unenrolledHosted.close);
    expect(await _readSyncMetaRow(unenrolledHosted), {
      'backend': 'supabase',
      'endpoint': isNull,
      'phase': 0,
      'writeEnabled': false,
      'bindingState': 0,
      'resumePhase': isNull,
    });
  });

  test('a 5-to-6 upgrade carries the v6 columns with correct types and '
      'defaults', () async {
    final db = _openUpgradedSyncMeta(fromVersion: 5);
    addTearDown(db.close);

    await _expectV6Columns(db);
  });

  test(
    'a 4-to-6 upgrade adds the v6 columns and remaps every row kind',
    () async {
      final probe = _openUpgradedSyncMeta(fromVersion: 4);
      addTearDown(probe.close);
      await _expectV6Columns(probe);

      final cases = <_RemapCase>[
        (
          backend: 'custom',
          endpoint: 'https://sync.example.com',
          phase: 4,
          writeEnabled: true,
          expectedPhase: 0,
          expectedBinding: 0,
        ),
        (
          backend: 'supabase',
          endpoint: null,
          phase: 1,
          writeEnabled: true,
          expectedPhase: 1,
          expectedBinding: 1,
        ),
        for (final phase in [2, 3, 4])
          (
            backend: 'supabase',
            endpoint: null,
            phase: phase,
            writeEnabled: true,
            expectedPhase: 5,
            expectedBinding: 1,
          ),
        (
          backend: null,
          endpoint: null,
          phase: 0,
          writeEnabled: false,
          expectedPhase: 0,
          expectedBinding: 0,
        ),
        (
          backend: 'supabase',
          endpoint: null,
          phase: 0,
          writeEnabled: false,
          expectedPhase: 0,
          expectedBinding: 0,
        ),
      ];
      for (final candidate in cases) {
        final db = _openUpgradedSyncMeta(
          fromVersion: 4,
          backend: candidate.backend,
          endpoint: candidate.endpoint,
          phase: candidate.phase,
          writeEnabled: candidate.writeEnabled,
        );
        addTearDown(db.close);

        expect(await _readSyncMetaRow(db), {
          'backend': candidate.backend,
          'endpoint': candidate.endpoint,
          'phase': candidate.expectedPhase,
          'writeEnabled': false,
          'bindingState': candidate.expectedBinding,
          'resumePhase': isNull,
        }, reason: '${candidate.backend} phase ${candidate.phase}');
      }
    },
  );

  test(
    'a 3-to-6 upgrade creates sync_meta fresh with the v6 columns',
    () async {
      final executor = NativeDatabase.memory(
        setup: (raw) {
          raw.execute(_v3Accounts);
          raw.execute(_v3Entries);
          raw.execute(_v3StoreMeta);
          raw.execute('PRAGMA user_version = 3');
        },
      );
      final db = LedgerDatabase(executor);
      addTearDown(db.close);

      await _expectV6Columns(db);
      final rows = await db.customSelect('SELECT id FROM sync_meta').get();
      expect(rows, isEmpty);
      expect(
        (await SyncMetadataStore(db).snapshot()).phase,
        SyncEnrollmentPhase.notEnrolled,
      );
    },
  );

  test('a fresh database has the v6 sync_meta columns with defaults', () async {
    final db = LedgerDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await _expectV6Columns(db);

    final store = SyncMetadataStore(db);
    await store.snapshot();
    final row = await db
        .customSelect(
          'SELECT device_binding_state, reauth_resume_phase FROM sync_meta '
          'WHERE id = 0',
        )
        .getSingle();
    expect(row.read<int>('device_binding_state'), 0);
    expect(row.readNullable<int>('reauth_resume_phase'), isNull);
  });
}
