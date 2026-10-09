import 'dart:async';

import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ledger/analysis/analysis_query_result.dart';
import 'package:spendwise/ledger/analysis/completeness.dart';
import 'package:spendwise/ledger/analysis/month_spread.dart';
import 'package:spendwise/ledger/analysis_cache.dart';
import 'package:spendwise/ledger/analysis_queries.dart';
import 'package:spendwise/ledger/ledger.dart';

const _checkingID = '11111111-1111-1111-1111-111111111111';
const _savingsID = '22222222-2222-2222-2222-222222222222';
const _flaggedID = '99999999-9999-9999-9999-999999999999';
const _foodID = '33333333-3333-3333-3333-333333333333';
const _payID = '44444444-4444-4444-4444-444444444444';
const _hiddenID = '66666666-6666-6666-6666-666666666666';

final _today = DateTime.utc(2027, 5, 15);
final _endMonth = DateTime.utc(2027, 5, 1);

class _ManualRunner {
  final List<Completer<List<AnalysisItem>>> pending = [];

  int calls = 0;

  Future<List<AnalysisItem>> call(LedgerState state) {
    calls++;
    final completer = Completer<List<AnalysisItem>>();
    pending.add(completer);
    return completer.future;
  }
}

({
  Ledger ledger,
  AnalysisCache cache,
  AnalysisQueries queries,
  _ManualRunner runner,
})
_setup({DateTime? today}) {
  final ledger = Ledger();
  final runner = _ManualRunner();
  final cache = AnalysisCache(runner: runner.call)
    ..start(ledger.bus, sourceRevision: () => ledger.revision);
  final queries = AnalysisQueries(
    ledger: ledger,
    cache: cache,
    today: today ?? _today,
  );
  addTearDown(() async {
    queries.dispose();
    await cache.dispose();
  });
  return (ledger: ledger, cache: cache, queries: queries, runner: runner);
}

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

Future<void> _settle(
  _ManualRunner runner,
  Ledger ledger, {
  List<AnalysisItem>? items,
}) async {
  runner.pending.last.complete(items ?? Accounting.analysisItems(ledger.state));
  await pumpEventQueue();
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
    final setup = _setup();
    _populate(setup.ledger);
    await _settle(setup.runner, setup.ledger);
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

  test('emptyMonthsAreZeroForBothKinds', () async {
    final juneSetup = _setup(today: DateTime.utc(2027, 6, 15));
    await _settle(juneSetup.runner, juneSetup.ledger);
    final june = juneSetup.queries.readMonthSpread(
      endMonth: DateTime.utc(2027, 6, 1),
      kind: CategoryKind.expense,
    );
    expect(june.state, AnalysisQueryState.ready);
    final current = june.value!.slots.last;
    expect(current.month, DateTime.utc(2027, 6, 1));
    expect(current.total, Decimal.zero);
    expect(current.itemCount, 0);
  });

  test('currentSlotMatchesReadPeriodForBothKinds', () async {
    final setup = _setup();
    _populate(setup.ledger);
    await _settle(setup.runner, setup.ledger);
    final queries = setup.queries;
    final may = DateRange(_endMonth, DateTime.utc(2027, 6, 1));

    final period = queries.readPeriod(window: may);
    expect(period.state, AnalysisQueryState.ready);
    final expense = _readySpread(queries, CategoryKind.expense);
    final income = _readySpread(queries, CategoryKind.income);
    expect(_slot(expense, 2027, 5).total, Decimal.parse('12.00'));
    expect(_slot(expense, 2027, 5).total, period.value?.spent);
    expect(_slot(income, 2027, 5).total, period.value?.income);
  });

  test('outOfRecordEndsStayEmptyAndFutureEndsFail', () async {
    final setup = _setup();
    _populate(setup.ledger);
    await _settle(setup.runner, setup.ledger);

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

  test('navigationAnchorsPagesAtTheCurrentMonth', () async {
    final setup = _setup();
    _populate(setup.ledger);
    await _settle(setup.runner, setup.ledger);
    expect(
      _readySpread(setup.queries, CategoryKind.expense).earliestSpreadEndMonth,
      _endMonth,
    );

    final older = monthSpread(
      items: const [],
      endMonth: _endMonth,
      kind: CategoryKind.expense,
      firstRecordMonth: DateTime.utc(2025, 6, 1),
      today: _today,
    );
    expect(older.earliestSpreadEndMonth, DateTime.utc(2026, 5, 1));
    expect(
      monthSpread(
        items: const [],
        endMonth: _endMonth,
        kind: CategoryKind.expense,
        firstRecordMonth: null,
        today: _today,
      ).earliestSpreadEndMonth,
      _endMonth,
    );
  });

  test('spreadEqualityIsListAwareAndSlotsAreImmutable', () async {
    MonthSpread build() => monthSpread(
      items: Accounting.analysisItems(_populatedState()),
      endMonth: _endMonth,
      kind: CategoryKind.expense,
      firstRecordMonth: DateTime.utc(2026, 12, 1),
      today: _today,
    );
    final first = build();
    final second = build();
    expect(identical(first.slots, second.slots), isFalse);
    expect(second, first);
    expect(second.hashCode, first.hashCode);

    final changed = monthSpread(
      items: Accounting.analysisItems(_populatedState())
          .where((item) => item.date != DateTime.utc(2027, 2, 1)),
      endMonth: _endMonth,
      kind: CategoryKind.expense,
      firstRecordMonth: DateTime.utc(2026, 12, 1),
      today: _today,
    );
    expect(changed == first, isFalse);
    expect(() => first.slots.add(first.slots.first), throwsUnsupportedError);
  });

  test('spreadFollowsMixedMemoAndRevisionGate', () async {
    final setup = _setup();
    final ledger = setup.ledger;
    final queries = setup.queries;
    final runner = setup.runner;

    final loading = queries.readMonthSpread(
      endMonth: _endMonth,
      kind: CategoryKind.expense,
    );
    expect(loading.state, AnalysisQueryState.loading);
    expect(loading.value, isNull);

    _populate(ledger);
    await _settle(runner, ledger);
    final settled = queries.readMonthSpread(
      endMonth: _endMonth,
      kind: CategoryKind.expense,
    );
    expect(settled.state, AnalysisQueryState.ready);
    expect(settled.sourceRevision, ledger.revision);
    expect(
      identical(
        queries.readMonthSpread(
          endMonth: DateTime(2027, 5, 20, 14, 45),
          kind: CategoryKind.expense,
        ),
        settled,
      ),
      isTrue,
    );
    expect(
      identical(
        queries.readMonthSpread(endMonth: _endMonth, kind: CategoryKind.income),
        settled,
      ),
      isFalse,
    );

    ledger.addEntry(
      Entry(
        id: 'f0000000-0000-0000-0000-000000000001',
        amount: Decimal.parse('-2.00'),
        name: 'entry',
        sourceID: _checkingID,
        categoryID: _foodID,
        date: DateTime.utc(2027, 5, 12),
      ),
    );
    final retained = queries.readMonthSpread(
      endMonth: _endMonth,
      kind: CategoryKind.expense,
    );
    expect(retained.state, AnalysisQueryState.loading);
    expect(retained.value, settled.value);
    expect(retained.sourceRevision, settled.sourceRevision);

    await _settle(runner, ledger);
    final updated = queries.readMonthSpread(
      endMonth: _endMonth,
      kind: CategoryKind.expense,
    );
    expect(updated.state, AnalysisQueryState.ready);
    expect(updated.sourceRevision, ledger.revision);
    expect(_slot(updated.value!, 2027, 5).total, Decimal.parse('14.00'));
  });

  test('movingEarliestDuringPendingRefreshKeepsSpreadCoherent', () async {
    final setup = _setup();
    final ledger = setup.ledger;
    final queries = setup.queries;
    final runner = setup.runner;
    _populate(ledger);
    await _settle(runner, ledger);

    final revision = ledger.revision;
    final settled = queries.readMonthSpread(
      endMonth: _endMonth,
      kind: CategoryKind.expense,
    );
    expect(settled.sourceRevision, revision);
    expect(settled.value?.earliestSpreadEndMonth, _endMonth);
    expect(_slot(settled.value!, 2027, 1).total, Decimal.parse('10.00'));
    expect(_slot(settled.value!, 2027, 1).itemCount, 1);

    ledger.deleteEntry('e0000000-0000-0000-0000-000000000001');

    final retained = queries.readMonthSpread(
      endMonth: _endMonth,
      kind: CategoryKind.expense,
    );
    expect(retained.state, AnalysisQueryState.loading);
    expect(retained.value, settled.value);
    expect(retained.sourceRevision, revision);

    final freshMonth = queries.readMonthCompleteness(
      month: DateTime.utc(2026, 12, 15),
    );
    expect(freshMonth.state, AnalysisQueryState.ready);
    expect(freshMonth.sourceRevision, ledger.revision);
    expect(freshMonth.value?.state, PeriodCompleteness.preRecord);
    expect(retained.sourceRevision, isNot(freshMonth.sourceRevision));

    await _settle(runner, ledger);
    final accepted = queries.readMonthSpread(
      endMonth: _endMonth,
      kind: CategoryKind.expense,
    );
    expect(accepted.sourceRevision, ledger.revision);
    expect(accepted.value?.earliestSpreadEndMonth, _endMonth);
    expect(_slot(accepted.value!, 2026, 12).total, Decimal.zero);
    expect(_slot(accepted.value!, 2026, 12).itemCount, 0);
    expect(
      queries
          .readMonthCompleteness(month: DateTime.utc(2026, 12, 15))
          .sourceRevision,
      ledger.revision,
    );
  });

  test('dayChangeRecomputesSpreadWithoutRunnerWork', () async {
    final setup = _setup();
    _populate(setup.ledger);
    await _settle(setup.runner, setup.ledger);
    final queries = setup.queries;
    final calls = setup.runner.calls;
    var notifications = 0;
    queries.addListener(() => notifications++);

    queries.setToday(DateTime.utc(2027, 6, 1));
    expect(setup.runner.calls, calls);
    expect(notifications, 1);

    final spread = queries.readMonthSpread(
      endMonth: _endMonth,
      kind: CategoryKind.expense,
    );
    expect(spread.state, AnalysisQueryState.ready);
    expect(spread.value?.currentMonth, DateTime.utc(2027, 6, 1));
    expect(_slot(spread.value!, 2027, 5).total, Decimal.parse('12.00'));
    expect(_slot(spread.value!, 2027, 5).itemCount, 2);

    final june = queries.readMonthSpread(
      endMonth: DateTime.utc(2027, 6, 1),
      kind: CategoryKind.income,
    );
    expect(june.state, AnalysisQueryState.ready);
    expect(_slot(june.value!, 2027, 6).total, Decimal.zero);
    expect(_slot(june.value!, 2027, 6).itemCount, 0);
  });

  test('spreadFailureIsIsolated', () async {
    final setup = _setup();
    _populate(setup.ledger);
    await _settle(setup.runner, setup.ledger);
    final queries = setup.queries;

    final failed = queries.readMonthSpread(
      endMonth: DateTime.utc(2027, 6, 1),
      kind: CategoryKind.expense,
    );
    expect(failed.state, AnalysisQueryState.failed);

    final period = queries.readPeriod(
      window: DateRange(_endMonth, DateTime.utc(2027, 6, 1)),
    );
    expect(period.state, AnalysisQueryState.ready);
    expect(period.value?.spent, Decimal.parse('12.00'));

    await queries.retry();
    final spread = queries.readMonthSpread(
      endMonth: _endMonth,
      kind: CategoryKind.expense,
    );
    expect(spread.state, AnalysisQueryState.ready);
  });
}

LedgerState _populatedState() {
  final ledger = Ledger();
  _populate(ledger);
  return ledger.state;
}
