import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ledger/analysis/entry_record.dart';
import 'package:spendwise/ledger/analysis/search.dart';
import 'package:spendwise/ledger/analysis/summaries/register.dart';

import 'analysis_test_support.dart';

void main() {
  test('searchMatchesTrimmedCaseInsensitiveEntryAndCategoryNames', () {
    final ledger = LedgerState();
    final source = Account(
      id: testId(1),
      name: 'Checking',
      type: AccountType.checking,
    );
    final category = TransactionCategory(
      id: testId(2),
      name: 'Dining',
      kind: CategoryKind.expense,
      colorHex: '#000000',
      includeInAnalysis: true,
      parentID: null,
      symbol: 'tag',
    );
    ledger.addAccount(source);
    ledger.addCategory(category);
    ledger.addEntry(
      Entry(
        amount: Decimal.parse('-12'),
        name: 'Lunch',
        sourceID: source.id,
        categoryID: category.id,
        date: DateTime.utc(2026, 10, 2),
      ),
    );

    final byName = searchEntries(ledger: ledger, query: '  LUNCH  ');
    final byCategory = searchEntries(ledger: ledger, query: 'dining');

    expect(byName.single.matches.single.entry.name, 'Lunch');
    expect(byName.single.matches.single.category, category);
    expect(byCategory.single.expense, Decimal.parse('12'));
    expect(byName.single, byName.single);
    expect(byName.single.hashCode, byName.single.hashCode);
    final record = byName.single.matches.single;
    final equalRecord = entryRecord(ledger, record.entry);
    expect(record, equalRecord);
    expect(record.hashCode, equalRecord.hashCode);
  });

  test('registerDaysReturnsNewestDaysWithNewestEntriesFirst', () {
    final ledger = LedgerState();
    final source = Account(
      id: testId(3),
      name: 'Checking',
      type: AccountType.checking,
    );
    ledger.addAccount(source);
    for (final row in [
      ('Older', DateTime.utc(2026, 10, 1)),
      ('First', DateTime.utc(2026, 10, 2)),
      ('Second', DateTime.utc(2026, 10, 2)),
    ]) {
      ledger.addEntry(
        Entry(
          amount: Decimal.parse('-5'),
          name: row.$1,
          sourceID: source.id,
          date: row.$2,
        ),
      );
    }

    final days = registerDays(
      ledger: ledger,
      window: DateRange(DateTime.utc(2026, 10, 1), DateTime.utc(2026, 10, 3)),
    );

    expect(days.map((day) => day.date), [
      DateTime.utc(2026, 10, 2),
      DateTime.utc(2026, 10, 1),
    ]);
    expect(days.first.entries.map((record) => record.entry.name), [
      'Second',
      'First',
    ]);
    expect(days.first.expense, Decimal.parse('10'));
    expect(days.first, days.first);
    expect(days.first.hashCode, days.first.hashCode);
  });
}
