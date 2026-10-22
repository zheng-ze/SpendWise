import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ledger/analysis/summaries/weeks.dart';

const _accountID = 'a0000000-0000-0000-0000-000000000001';
const _otherID = 'a0000000-0000-0000-0000-000000000002';
const _categoryID = 'a0000000-0000-0000-0000-000000000003';
final _window = DateRange(
  DateTime.utc(2026, 10, 7),
  DateTime.utc(2026, 10, 15),
);

Decimal _amount(String value) => Decimal.parse(value);

void main() {
  test('week totals align Monday ranges and preserve the requested window', () {
    final ledger = LedgerState()
      ..addAccount(
        Account(id: _accountID, name: 'Checking', type: AccountType.checking),
      )
      ..addCategory(
        TransactionCategory(
          id: _categoryID,
          name: 'Food',
          kind: CategoryKind.expense,
          colorHex: '#000000',
          includeInAnalysis: true,
          parentID: null,
          symbol: 'tag',
        ),
      )
      ..addEntry(
        Entry(
          id: 'b0000000-0000-0000-0000-000000000001',
          amount: _amount('-12'),
          name: 'Lunch',
          sourceID: _accountID,
          categoryID: _categoryID,
          date: DateTime.utc(2026, 10, 7),
        ),
      )
      ..addEntry(
        Entry(
          id: 'b0000000-0000-0000-0000-000000000002',
          amount: _amount('-8'),
          name: 'Dinner',
          sourceID: _accountID,
          categoryID: _categoryID,
          date: DateTime.utc(2026, 10, 12),
        ),
      );
    final items = Accounting.analysisItems(ledger);

    final totals = weekTotals(ledger: ledger, items: items, window: _window);
    final repeated = weekTotals(ledger: ledger, items: items, window: _window);

    expect(totals, hasLength(2));
    expect(
      totals.first.range,
      DateRange(DateTime.utc(2026, 10, 5), DateTime.utc(2026, 10, 12)),
    );
    expect(totals.first.effectiveWindow, totals.first.range);
    expect(totals.first.spent, _amount('12'));
    expect(totals.first.expenseItemCount, 1);
    expect(totals.last.spent, _amount('8'));
    expect(totals.last.expenseItemCount, 1);
    expect(totals.first, repeated.first);
    expect(totals.first.hashCode, repeated.first.hashCode);
    expect(() => totals.clear(), throwsUnsupportedError);
  });

  test('scoped week totals classify active entries touching the scope', () {
    final ledger = LedgerState()
      ..addAccount(
        Account(id: _accountID, name: 'Checking', type: AccountType.checking),
      )
      ..addAccount(
        Account(id: _otherID, name: 'Savings', type: AccountType.savings),
      )
      ..addCategory(
        TransactionCategory(
          id: _categoryID,
          name: 'Food',
          kind: CategoryKind.expense,
          colorHex: '#000000',
          includeInAnalysis: true,
          parentID: null,
          symbol: 'tag',
        ),
      )
      ..addEntry(
        Entry(
          id: 'c0000000-0000-0000-0000-000000000001',
          amount: _amount('-9'),
          name: 'Lunch',
          sourceID: _accountID,
          categoryID: _categoryID,
          date: DateTime.utc(2026, 10, 8),
        ),
      );
    final totals = weekTotals(
      ledger: ledger,
      items: const [],
      window: _window,
      sourceIDs: {_accountID},
    );

    expect(totals.first.spent, _amount('9'));
    expect(totals.first.expenseItemCount, 1);
    expect(totals.last.spent, Decimal.zero);
    expect(
      weekTotals(
        ledger: ledger,
        items: const [],
        window: DateRange(_window.start, _window.start),
      ),
      isEmpty,
    );
  });
}
