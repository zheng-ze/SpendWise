import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/persistence/database/ledger_database.dart';

const _expectedLedgerColumns = {
  'accounts': {
    'id',
    'name',
    'type',
    'sub_pocket_ids',
    'incoming_transfers_as_expenses',
    'include_in_net_worth',
    'statement_day',
    'lifecycle',
  },
  'sub_pockets': {'id', 'name', 'incoming_transfers_as_expenses', 'lifecycle'},
  'categories': {
    'id',
    'name',
    'kind',
    'color_hex',
    'include_in_analysis',
    'parent_id',
    'symbol',
    'lifecycle',
  },
  'entries': {
    'id',
    'date',
    'amount',
    'name',
    'category_id',
    'source_id',
    'destination_id',
    'include_in_analysis',
    'note',
    'system_kind',
    'lifecycle',
  },
  'plans': {
    'id',
    'frequency',
    'anchor',
    'end_date',
    'last_resolved_date',
    'template_amount',
    'template_name',
    'template_category_id',
    'template_source_id',
    'template_destination_id',
    'template_include_in_analysis',
    'template_note',
    'lifecycle',
  },
  'budgets': {'id', 'category_id', 'limit_amount', 'lifecycle'},
};

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
    expect((await columnTypes('budgets'))['limit_amount'], 'TEXT');
  });

  test('budgets hold one limit and no limit history columns', () async {
    final columns = await columnTypes('budgets');

    expect(columns.keys, {'id', 'category_id', 'limit_amount', 'lifecycle'});
  });

  test('every ledger table has exactly its expected columns and an integer lifecycle', () async {
    for (final entry in _expectedLedgerColumns.entries) {
      final columns = await columnTypes(entry.key);
      expect(columns['lifecycle'], 'INTEGER', reason: entry.key);
      expect(columns.keys.toSet(), entry.value, reason: entry.key);
    }
  });

  test('store_meta holds only its id and the seeded flag', () async {
    final columns = await columnTypes('store_meta');
    expect(columns.keys, {'id', 'has_seeded'});
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
        'template_note',
      ]),
    );
  });

  test('the plan template note column is nullable text', () async {
    final rows = await db.customSelect('PRAGMA table_info(plans)').get();
    final byName = {for (final row in rows) row.read<String>('name'): row};
    expect(byName['template_note']!.read<String>('type'), 'TEXT');
    expect(byName['template_note']!.read<int>('notnull'), 0);
  });

  test('store_meta rejects a second row', () async {
    await db.customStatement(
      "INSERT INTO store_meta (id, has_seeded) VALUES (0, 0)",
    );
    await expectLater(
      db.customStatement(
        "INSERT INTO store_meta (id, has_seeded) VALUES (1, 0)",
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
