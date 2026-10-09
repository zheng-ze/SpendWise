import 'dart:async';

import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ledger/analysis/analysis_query_result.dart';
import 'package:spendwise/ledger/analysis/year_spread.dart';
import 'package:spendwise/ledger/analysis_cache.dart';
import 'package:spendwise/ledger/analysis_queries.dart';
import 'package:spendwise/ledger/ledger.dart';

const _checkingID = '11111111-1111-1111-1111-111111111111';
const _savingsID = '22222222-2222-2222-2222-222222222222';
const _flaggedID = '99999999-9999-9999-9999-999999999999';
const _foodID = '33333333-3333-3333-3333-333333333333';
const _payID = '44444444-4444-4444-4444-444444444444';
const _hiddenID = '66666666-6666-6666-6666-666666666666';

const _earliestID = 'd0000000-0000-0000-0000-000000000001';

final _today = DateTime.utc(2027, 5, 15);
const _endYear = 2027;

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

  const p = 'd0000000-0000-0000-0000-';
  entry(
    '${p}000000000001',
    '-4.00',
    DateTime.utc(2024, 12, 15),
    categoryID: _foodID,
    includeInAnalysis: false,
  );
  entry(
    '${p}000000000002',
    '-10.00',
    DateTime.utc(2025, 1, 10),
    categoryID: _foodID,
  );
  entry(
    '${p}000000000003',
    '100.00',
    DateTime.utc(2025, 6, 1),
    categoryID: _payID,
  );
  entry(
    '${p}000000000004',
    '-20.00',
    DateTime.utc(2025, 12, 31),
    categoryID: _foodID,
  );
  entry(
    '${p}000000000005',
    '7.00',
    DateTime.utc(2026, 1, 1),
    categoryID: _payID,
  );
  entry(
    '${p}000000000006',
    '200.00',
    DateTime.utc(2026, 3, 10),
    categoryID: _payID,
  );
  entry(
    '${p}000000000007',
    '-3.00',
    DateTime.utc(2027, 1, 5),
    categoryID: _foodID,
  );
  entry(
    '${p}000000000008',
    '50.00',
    DateTime.utc(2027, 5, 10),
    categoryID: _payID,
  );
  entry(
    '${p}000000000009',
    '-9.00',
    DateTime.utc(2027, 5, 20),
    categoryID: _foodID,
  );
  entry(
    '${p}000000000010',
    '-999.00',
    DateTime.utc(2027, 4, 3),
    categoryID: _foodID,
    includeInAnalysis: false,
  );
  entry(
    '${p}000000000011',
    '-6.00',
    DateTime.utc(2027, 4, 5),
    categoryID: _hiddenID,
  );
  entry(
    '${p}000000000012',
    '22.00',
    DateTime.utc(2027, 4, 7),
    destinationID: _savingsID,
  );
  entry(
    '${p}000000000013',
    '40.00',
    DateTime.utc(2027, 4, 8),
    destinationID: _flaggedID,
  );
  entry(
    '${p}000000000014',
    '15.00',
    DateTime.utc(2027, 4, 9),
    sourceID: _flaggedID,
    destinationID: _checkingID,
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

YearSpread _readySpread(AnalysisQueries queries, CategoryKind kind) {
  final read = queries.readYearSpread(endYear: _endYear, kind: kind);
  expect(read.state, AnalysisQueryState.ready);
  return read.value!;
}

YearSlot _slot(YearSpread spread, int year) {
  return spread.slots.singleWhere((slot) => slot.year == year);
}

void main() {
  test('fullYearSumsIncludeJanuaryLateYearAndAfterTodayEntries', () async {
    final setup = _setup();
    _populate(setup.ledger);
    await _settle(setup.runner, setup.ledger);
    final expense = _readySpread(setup.queries, CategoryKind.expense);
    final income = _readySpread(setup.queries, CategoryKind.income);

    for (final spread in [expense, income]) {
      expect(spread.endYear, _endYear);
      expect(spread.currentYear, 2027);
      expect(spread.earliestSpreadEndYear, 2024);
      expect(spread.slots, hasLength(3));
      for (var i = 0; i < 3; i++) {
        final year = 2025 + i;
        expect(spread.slots[i].year, year);
        expect(
          spread.slots[i].window,
          DateRange(DateTime.utc(year, 1, 1), DateTime.utc(year + 1, 1, 1)),
        );
      }
    }
    expect(expense.kind, CategoryKind.expense);
    expect(income.kind, CategoryKind.income);
    final table = <List<Object>>[
      [2025, '30.00', 2, '100.00', 1],
      [2026, '0', 0, '207.00', 2],
      [2027, '52.00', 3, '65.00', 2],
    ];
    for (final row in table) {
      final expenseSlot = _slot(expense, row[0] as int);
      expect(expenseSlot.total, Decimal.parse(row[1] as String));
      expect(expenseSlot.itemCount, row[2]);
      final incomeSlot = _slot(income, row[0] as int);
      expect(incomeSlot.total, Decimal.parse(row[3] as String));
      expect(incomeSlot.itemCount, row[4]);
    }
  });

  test('emptyAndOutOfRecordYearsStayZeroAndFutureEndsFail', () async {
    final empty = _setup();
    await _settle(empty.runner, empty.ledger);
    final emptySpread = empty.queries.readYearSpread(
      endYear: _endYear,
      kind: CategoryKind.expense,
    );
    expect(emptySpread.state, AnalysisQueryState.ready);
    expect(emptySpread.value!.earliestSpreadEndYear, 2027);
    final emptyCurrent = emptySpread.value!.slots.last;
    expect(emptyCurrent.year, _endYear);
    expect(emptyCurrent.total, Decimal.zero);
    expect(emptyCurrent.itemCount, 0);

    final setup = _setup();
    _populate(setup.ledger);
    await _settle(setup.runner, setup.ledger);

    final historical = setup.queries.readYearSpread(
      endYear: 2023,
      kind: CategoryKind.expense,
    );
    expect(historical.state, AnalysisQueryState.ready);
    expect(historical.value!.currentYear, 2027);
    expect(historical.value!.earliestSpreadEndYear, 2024);
    for (final slot in historical.value!.slots) {
      expect(slot.total, Decimal.zero);
      expect(slot.itemCount, 0);
    }

    final failed = setup.queries.readYearSpread(
      endYear: 2028,
      kind: CategoryKind.expense,
    );
    expect(failed.state, AnalysisQueryState.failed);
    expect(failed.value, isNull);
    expect(failed.sourceRevision, isNull);
  });

  test('navigationAnchorsPagesAtTheCurrentYear', () async {
    YearSpread spread(DateTime? first) => yearSpread(
      items: const [],
      endYear: _endYear,
      kind: CategoryKind.expense,
      firstRecordMonth: first,
      today: _today,
    );
    final table = <List<Object?>>[
      [DateTime.utc(2024, 12, 1), 2024],
      [DateTime.utc(2022, 6, 1), 2024],
      [DateTime.utc(2021, 1, 1), 2021],
      [null, 2027],
      [DateTime.utc(2028, 1, 1), 2027],
    ];
    for (final row in table) {
      expect(spread(row[0] as DateTime?).earliestSpreadEndYear, row[1]);
    }
  });
  test('spreadEqualityIsListAwareAndSlotsAreImmutable', () async {
    YearSpread build() => yearSpread(
      items: Accounting.analysisItems(_populatedState()),
      endYear: _endYear,
      kind: CategoryKind.expense,
      firstRecordMonth: DateTime.utc(2024, 12, 1),
      today: _today,
    );
    final first = build();
    final second = build();
    expect(identical(first.slots, second.slots), isFalse);
    expect(second, first);
    expect(second.hashCode, first.hashCode);

    final changed = yearSpread(
      items: Accounting.analysisItems(_populatedState())
          .where((item) => item.date != DateTime.utc(2025, 12, 31)),
      endYear: _endYear,
      kind: CategoryKind.expense,
      firstRecordMonth: DateTime.utc(2024, 12, 1),
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

    final loading = queries.readYearSpread(
      endYear: _endYear,
      kind: CategoryKind.expense,
    );
    expect(loading.state, AnalysisQueryState.loading);
    expect(loading.value, isNull);

    _populate(ledger);
    await _settle(runner, ledger);
    final settled = queries.readYearSpread(
      endYear: _endYear,
      kind: CategoryKind.expense,
    );
    expect(settled.state, AnalysisQueryState.ready);
    expect(settled.sourceRevision, ledger.revision);
    expect(
      identical(
        queries.readYearSpread(endYear: _endYear, kind: CategoryKind.income),
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
    final retained = queries.readYearSpread(
      endYear: _endYear,
      kind: CategoryKind.expense,
    );
    expect(retained.state, AnalysisQueryState.loading);
    expect(retained.value, settled.value);
    expect(retained.sourceRevision, settled.sourceRevision);

    await _settle(runner, ledger);
    final updated = queries.readYearSpread(
      endYear: _endYear,
      kind: CategoryKind.expense,
    );
    expect(updated.state, AnalysisQueryState.ready);
    expect(updated.sourceRevision, ledger.revision);
    expect(_slot(updated.value!, 2027).total, Decimal.parse('54.00'));
  });

  test('movingEarliestDuringPendingRefreshKeepsSpreadCoherent', () async {
    final setup = _setup();
    final ledger = setup.ledger;
    final queries = setup.queries;
    final runner = setup.runner;
    _populate(ledger);
    await _settle(runner, ledger);

    final revision = ledger.revision;
    final settled = queries.readYearSpread(
      endYear: _endYear,
      kind: CategoryKind.expense,
    );
    expect(settled.sourceRevision, revision);
    expect(settled.value?.earliestSpreadEndYear, 2024);
    expect(_slot(settled.value!, 2025).total, Decimal.parse('30.00'));

    ledger.deleteEntry(_earliestID);

    final retained = queries.readYearSpread(
      endYear: _endYear,
      kind: CategoryKind.expense,
    );
    expect(retained.state, AnalysisQueryState.loading);
    expect(retained.value, settled.value);
    expect(retained.sourceRevision, revision);

    final freshFirst = queries.readFirstRecordMonth();
    expect(freshFirst.state, AnalysisQueryState.ready);
    expect(freshFirst.sourceRevision, ledger.revision);
    expect(freshFirst.value, DateTime.utc(2025, 1, 1));
    expect(retained.sourceRevision, isNot(freshFirst.sourceRevision));

    await _settle(runner, ledger);
    final accepted = queries.readYearSpread(
      endYear: _endYear,
      kind: CategoryKind.expense,
    );
    expect(accepted.sourceRevision, ledger.revision);
    expect(accepted.value?.earliestSpreadEndYear, 2027);
    expect(_slot(accepted.value!, 2025).total, Decimal.parse('30.00'));
  });

  test('dayChangeRecomputesSpreadWithoutRunnerWork', () async {
    final setup = _setup();
    _populate(setup.ledger);
    await _settle(setup.runner, setup.ledger);
    final queries = setup.queries;
    final calls = setup.runner.calls;
    var notifications = 0;
    queries.addListener(() => notifications++);

    queries.setToday(DateTime.utc(2028, 1, 10));
    expect(setup.runner.calls, calls);
    expect(notifications, 1);

    final spread = queries.readYearSpread(
      endYear: _endYear,
      kind: CategoryKind.expense,
    );
    expect(spread.state, AnalysisQueryState.ready);
    expect(spread.value?.currentYear, 2028);
    expect(spread.value?.earliestSpreadEndYear, 2025);
    expect(_slot(spread.value!, 2027).total, Decimal.parse('52.00'));

    final current = queries.readYearSpread(
      endYear: 2028,
      kind: CategoryKind.expense,
    );
    expect(current.state, AnalysisQueryState.ready);
    expect(_slot(current.value!, 2028).total, Decimal.zero);
    expect(_slot(current.value!, 2028).itemCount, 0);
  });

  test('spreadFailureIsIsolated', () async {
    final setup = _setup();
    _populate(setup.ledger);
    await _settle(setup.runner, setup.ledger);
    final queries = setup.queries;

    final failed = queries.readYearSpread(
      endYear: 2028,
      kind: CategoryKind.expense,
    );
    expect(failed.state, AnalysisQueryState.failed);

    final period = queries.readPeriod(
      window: DateRange(DateTime.utc(2027, 5, 1), DateTime.utc(2027, 6, 1)),
    );
    expect(period.state, AnalysisQueryState.ready);
    expect(period.value?.spent, Decimal.parse('9.00'));
    expect(period.value?.income, Decimal.parse('50.00'));

    await queries.retry();
    final spread = queries.readYearSpread(
      endYear: _endYear,
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
