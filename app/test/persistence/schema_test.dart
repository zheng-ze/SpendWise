import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/persistence/database/ledger_database.dart';

void main() {
  late LedgerDatabase db;

  setUp(() => db = LedgerDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<Map<String, Map<String, Object?>>> columns(String table) async {
    final rows = await db.customSelect('PRAGMA table_info($table)').get();
    return {
      for (final row in rows)
        row.read<String>('name'): {
          'type': row.read<String>('type'),
          'notnull': row.read<int>('notnull'),
        },
    };
  }

  test('money and dates use exact persistent representations', () async {
    final entries = await columns('entries');
    final plans = await columns('plans');

    expect(entries['amount']!['type'], 'TEXT');
    expect(entries['date']!['type'], 'INTEGER');
    expect(plans['template_amount']!['type'], 'TEXT');
    expect(plans['anchor']!['type'], 'INTEGER');
    expect(plans['end_date']!['type'], 'INTEGER');
    expect(plans['last_resolved_date']!['type'], 'INTEGER');
  });

  test(
    'synced rows carry vectors and lifecycle while store metadata does not',
    () async {
      for (final table in [
        'accounts',
        'sub_pockets',
        'categories',
        'entries',
        'plans',
      ]) {
        final schema = await columns(table);
        expect(schema['version_data']!['type'], 'BLOB', reason: table);
        expect(schema['lifecycle']!['type'], 'INTEGER', reason: table);
      }

      final metadata = await columns('store_meta');
      expect(metadata.containsKey('version_data'), isFalse);
      expect(metadata.containsKey('lifecycle'), isFalse);
    },
  );

  test('entry and plan notes remain nullable text columns', () async {
    final entries = await columns('entries');
    final plans = await columns('plans');

    expect(entries['note'], {'type': 'TEXT', 'notnull': 0});
    expect(entries['system_kind']!['notnull'], 0);
    expect(plans['template_note'], {'type': 'TEXT', 'notnull': 0});
  });

  test('store metadata rejects a second row', () async {
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
}
