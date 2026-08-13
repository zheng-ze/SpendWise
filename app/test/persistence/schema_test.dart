import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/persistence/ledger_database.dart';

void main() {
  late LedgerDatabase db;

  setUp(() => db = LedgerDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<Map<String, String>> columnTypes(String table) async {
    final rows = await db.customSelect('PRAGMA table_info($table)').get();
    return {
      for (final row in rows)
        row.read<String>('name'): row.read<String>('type'),
    };
  }

  test('money columns are text so amounts round-trip exactly', () async {
    expect((await columnTypes('entries'))['amount'], 'TEXT');
    expect((await columnTypes('plans'))['template_amount'], 'TEXT');
  });

  test('every synced table carries a version vector and a lifecycle', () async {
    for (final table in [
      'accounts',
      'sub_pockets',
      'categories',
      'entries',
      'plans',
    ]) {
      final columns = await columnTypes(table);
      expect(columns['version_data'], 'BLOB', reason: table);
      expect(columns['lifecycle'], 'INTEGER', reason: table);
    }
  });

  test('store_meta is device-local, so it has neither', () async {
    final columns = await columnTypes('store_meta');
    expect(columns.containsKey('version_data'), isFalse);
    expect(columns.containsKey('lifecycle'), isFalse);
  });

  test('reserved entry columns exist and are nullable', () async {
    final rows = await db.customSelect('PRAGMA table_info(entries)').get();
    final nullable = {
      for (final row in rows)
        row.read<String>('name'): row.read<int>('notnull') == 0,
    };
    expect(nullable['note'], isTrue);
    expect(nullable['system_kind'], isTrue);
  });

  test('the plan template is flat columns, not a nested structure', () async {
    final columns = await columnTypes('plans');
    expect(
      columns.keys,
      containsAll([
        'template_amount',
        'template_name',
        'template_category_id',
        'template_source_id',
        'template_destination_id',
        'template_include_in_analysis',
      ]),
    );
  });

  test('store_meta rejects a second row', () async {
    await db.customStatement(
      "INSERT INTO store_meta (id, device_id, has_seeded) VALUES (0, 'a', 0)",
    );
    await expectLater(
      db.customStatement(
        "INSERT INTO store_meta (id, device_id, has_seeded) VALUES (1, 'b', 0)",
      ),
      throwsA(isA<SqliteException>()),
    );
  });

  test('dates are stored as integer epoch milliseconds', () async {
    expect((await columnTypes('entries'))['date'], 'INTEGER');
    final planColumns = await columnTypes('plans');
    expect(planColumns['anchor'], 'INTEGER');
    expect(planColumns['end_date'], 'INTEGER');
    expect(planColumns['last_resolved_date'], 'INTEGER');
  });
}
