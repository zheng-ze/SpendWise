import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ledger/analysis/analysis_query_result.dart';
import 'package:spendwise/ledger/analysis/insights/completeness.dart';
import 'package:spendwise/ledger/analysis/summaries/month_spread.dart';
import 'package:spendwise/ledger/analysis_queries.dart';
import 'package:spendwise/ledger/ledger.dart';

import 'analysis_test_support.dart';

const _checkingID = '11111111-1111-1111-1111-111111111111';
const _savingsID = '22222222-2222-2222-2222-222222222222';
const _flaggedID = '99999999-9999-9999-9999-999999999999';
const _foodID = '33333333-3333-3333-3333-333333333333';
const _payID = '44444444-4444-4444-4444-444444444444';
const _hiddenID = '66666666-6666-6666-6666-666666666666';

final _today = DateTime.utc(2027, 5, 15);
final _endMonth = DateTime.utc(2027, 5, 1);

void _populate(Ledger ledger) {
  ledger.addAccount(
    Account(id: _checkingID, name: 'Checking', type: AccountType.checking),
  );
  ledger.addAccount(
    Account(id: _savingsID, name: 'Savings', type: AccountType.savings),
  );
  ledger.addAccount(
    Account(
      id: _flaggedID,
      name: 'Flagged',
      type: AccountType.savings,
      incomingTransfersAsExpenses: true,
    ),
  );
  for (final category in [
    TransactionCategory(
      id: _foodID,
      name: 'Food',
      kind: CategoryKind.expense,
      colorHex: '#000000',
      includeInAnalysis: true,
      parentID: null,
      symbol: 'tag',
    ),
    TransactionCategory(
      id: _payID,
      name: 'Pay',
      kind: CategoryKind.income,
      colorHex: '#000000',
      includeInAnalysis: true,
      parentID: null,
      symbol: 'tag',
    ),
    TransactionCategory(
      id: _hiddenID,
      name: 'Hidden',
      kind: CategoryKind.expense,
      colorHex: '#000000',
      includeInAnalysis: false,
      parentID: null,
      symbol: 'tag',
    ),
  ]) {
    ledger.addCategory(category);
  }
  void entry(
    String id,
    String amount,
    DateTime date, {
    String? categoryID,
    String sourceID = _checkingID,
    String? destinationID,
    bool includeInAnalysis = true,
  }) {
    ledger.addEntry(
      Entry(
        id: id,
        amount: Decimal.parse(amount),
        name: 'entry',
        sourceID: sourceID,
        destinationID: destinationID,
        categoryID: categoryID,
        date: date,
        includeInAnalysis: includeInAnalysis,
      ),
    );
  }

  const p = 'e0000000-0000-0000-0000-';
  entry(
    '${p}000000000001',
    '-4.00',
    DateTime.utc(2026, 12, 15),
    categoryID: _foodID,
    includeInAnalysis: false,
  );
  entry(
    '${p}000000000002',
    '-10.00',
    DateTime.utc(2027, 1, 5),
    categoryID: _foodID,
  );
  entry(
    '${p}000000000003',
    '40.00',
    DateTime.utc(2027, 1, 31),
    categoryID: _payID,
  );
  entry(
    '${p}000000000004',
    '-5.00',
    DateTime.utc(2027, 2, 1),
    categoryID: _foodID,
  );
  entry(
    '${p}000000000005',
    '-7.00',
    DateTime.utc(2027, 4, 1),
    categoryID: _foodID,
  );
  entry(
    '${p}000000000006',
    '-999.00',
    DateTime.utc(2027, 4, 3),
    categoryID: _foodID,
    includeInAnalysis: false,
  );
  entry(
    '${p}000000000007',
    '-6.00',
    DateTime.utc(2027, 4, 5),
    categoryID: _hiddenID,
  );
  entry(
    '${p}000000000008',
    '22.00',
    DateTime.utc(2027, 4, 7),
    destinationID: _savingsID,
  );
  entry(
    '${p}000000000009',
    '40.00',
    DateTime.utc(2027, 4, 8),
    destinationID: _flaggedID,
  );
  entry(
    '${p}000000000010',
    '15.00',
    DateTime.utc(2027, 4, 9),
    sourceID: _flaggedID,
    destinationID: _checkingID,
  );
  entry(
    '${p}000000000011',
    '-3.00',
    DateTime.utc(2027, 5, 2),
    categoryID: _foodID,
  );
  entry(
    '${p}000000000012',
    '-9.00',
    DateTime.utc(2027, 5, 20),
    categoryID: _foodID,
  );
  entry(
    '${p}000000000013',
    '50.00',
    DateTime.utc(2027, 5, 10),
    categoryID: _payID,
  );
  ledger.setOpeningBalance(
    Decimal.parse('100'),
    _checkingID,
    date: DateTime.utc(2027, 3, 1),
  );
}

MonthSpread _readySpread(AnalysisQueries queries, CategoryKind kind) {
  final read = queries.readMonthSpread(endMonth: _endMonth, kind: kind);
  expect(read.state, AnalysisQueryState.ready);
  return read.value!;
}

MonthSlot _slot(MonthSpread spread, int year, int month) {
  return spread.slots.singleWhere(
    (slot) => slot.month == DateTime.utc(year, month, 1),
  );
}

void main() {
  test('spreadsCoverTwelveMonthsWithCommittedTotals', () async {
    final setup = setupAnalysis();
    _populate(setup.ledger);
    await settle(setup.runner, setup.ledger);
    final expense = _readySpread(setup.queries, CategoryKind.expense);
    final income = _readySpread(setup.queries, CategoryKind.income);

    for (final spread in [expense, income]) {
      expect(spread.currentMonth, _endMonth);
      expect(spread.earliestSpreadEndMonth, _endMonth);
      expect(spread.slots, hasLength(12));
      for (var i = 0; i < 12; i++) {
        final want = DateTime.utc(2026, 6 + i, 1);
        expect(spread.slots[i].month, want);
        expect(spread.slots[i].window, monthWindow(want));
      }
    }
    expect(expense.endMonth, _endMonth);
    expect(expense.kind, CategoryKind.expense);
    expect(income.kind, CategoryKind.income);
    final table = <List<Object>>[
      [2026, 6, '0', 0, '0', 0],
      [2026, 7, '0', 0, '0', 0],
      [2026, 8, '0', 0, '0', 0],
      [2026, 9, '0', 0, '0', 0],
      [2026, 10, '0', 0, '0', 0],
      [2026, 11, '0', 0, '0', 0],
      [2026, 12, '0', 0, '0', 0],
      [2027, 1, '10.00', 1, '40.00', 1],
      [2027, 2, '5.00', 1, '0', 0],
      [2027, 3, '0', 0, '0', 0],
      [2027, 4, '47.00', 2, '15.00', 1],
      [2027, 5, '12.00', 2, '50.00', 1],
    ];
    for (final row in table) {
      final expenseSlot = _slot(expense, row[0] as int, row[1] as int);
      expect(expenseSlot.total, Decimal.parse(row[2] as String));
      expect(expenseSlot.itemCount, row[3]);
      final incomeSlot = _slot(income, row[0] as int, row[1] as int);
      expect(incomeSlot.total, Decimal.parse(row[4] as String));
      expect(incomeSlot.itemCount, row[5]);
    }
  });

  test('outOfRecordEndsStayEmptyAndFutureEndsFail', () async {
    final setup = setupAnalysis();
    _populate(setup.ledger);
    await settle(setup.runner, setup.ledger);

    final historical = setup.queries.readMonthSpread(
      endMonth: DateTime.utc(2026, 6, 1),
      kind: CategoryKind.expense,
    );
    expect(historical.state, AnalysisQueryState.ready);
    for (final slot in historical.value!.slots) {
      expect(slot.total, Decimal.zero);
      expect(slot.itemCount, 0);
    }
    expect(historical.value!.earliestSpreadEndMonth, _endMonth);

    final futureOnly = monthSpread(
      items: const [],
      endMonth: _endMonth,
      kind: CategoryKind.expense,
      firstRecordMonth: DateTime.utc(2027, 7, 1),
      today: _today,
    );
    for (final slot in futureOnly.slots) {
      expect(slot.total, Decimal.zero);
      expect(slot.itemCount, 0);
    }
    expect(futureOnly.earliestSpreadEndMonth, _endMonth);

    final failed = setup.queries.readMonthSpread(
      endMonth: DateTime.utc(2027, 6, 1),
      kind: CategoryKind.expense,
    );
    expect(failed.state, AnalysisQueryState.failed);
    expect(failed.value, isNull);
    expect(failed.sourceRevision, isNull);
  });
}
