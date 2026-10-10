import 'dart:async';

import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ledger/analysis/analysis_query_result.dart';
import 'package:spendwise/ledger/analysis/category_breakdown.dart';
import 'package:spendwise/ledger/analysis/completeness.dart';
import 'package:spendwise/ledger/analysis/scoped_trend.dart';
import 'package:spendwise/ledger/analysis_cache.dart';
import 'package:spendwise/ledger/analysis_queries.dart';
import 'package:spendwise/ledger/ledger.dart';

const _checkingID = '11111111-1111-1111-1111-111111111111';
const _savingsID = '22222222-2222-2222-2222-222222222222';
const _flaggedID = '99999999-9999-9999-9999-999999999999';
const _mainID = '33333333-3333-3333-3333-333333333333';
const _childID = '44444444-4444-4444-4444-444444444444';
const _childlessID = '55555555-5555-5555-5555-555555555555';
const _payID = '66666666-6666-6666-6666-666666666666';
const _hiddenID = '77777777-7777-7777-7777-777777777777';
const _excludedParentID = '88888888-8888-8888-8888-888888888888';
const _excludedChildID = '99999999-9999-9999-9999-999999999992';
const _soloMainID = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
const _soloChildID = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
const _syntheticID = 'transfer-expense:savings';

const _mayExpenseTotal = '85.00';
const _mayIncomeTotal = '50.00';
const _juneExpenseTotal = '99.00';
const _year2026ExpenseTotal = '7.00';
const _year2027ExpenseTotal = '189.00';
const _futureDecemberTotal = '7.00';

final _today = DateTime.utc(2027, 5, 15);
final _may = DateTime.utc(2027, 5, 1);
final _june = DateTime.utc(2027, 6, 1);
final _mayWindow = DateRange(_may, _june);

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
      id: _mainID,
      name: 'Main',
      kind: CategoryKind.expense,
      colorHex: '#000000',
      includeInAnalysis: true,
      parentID: null,
      symbol: 'tag',
    ),
    TransactionCategory(
      id: _childID,
      name: 'Child',
      kind: CategoryKind.expense,
      colorHex: '#000000',
      includeInAnalysis: true,
      parentID: _mainID,
      symbol: 'tag',
    ),
    TransactionCategory(
      id: _childlessID,
      name: 'Childless',
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
    TransactionCategory(
      id: _excludedParentID,
      name: 'Excluded parent',
      kind: CategoryKind.expense,
      colorHex: '#000000',
      includeInAnalysis: false,
      parentID: null,
      symbol: 'tag',
    ),
    TransactionCategory(
      id: _excludedChildID,
      name: 'Excluded child',
      kind: CategoryKind.expense,
      colorHex: '#000000',
      includeInAnalysis: true,
      parentID: _excludedParentID,
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
    '-10.00',
    DateTime.utc(2027, 5, 1),
    categoryID: _childID,
  );
  entry(
    '${p}000000000002',
    '-20.00',
    DateTime.utc(2027, 5, 31),
    categoryID: _mainID,
  );
  entry(
    '${p}000000000003',
    '-15.00',
    DateTime.utc(2027, 5, 12),
    categoryID: _childlessID,
  );
  entry(
    '${p}000000000004',
    '50.00',
    DateTime.utc(2027, 5, 10),
    categoryID: _payID,
  );
  entry(
    '${p}000000000005',
    '-999.00',
    DateTime.utc(2027, 5, 5),
    categoryID: _childID,
    includeInAnalysis: false,
  );
  entry(
    '${p}000000000006',
    '-6.00',
    DateTime.utc(2027, 5, 6),
    categoryID: _hiddenID,
  );
  entry(
    '${p}000000000007',
    '-8.00',
    DateTime.utc(2027, 5, 7),
    categoryID: _excludedChildID,
  );
  entry(
    '${p}000000000008',
    '22.00',
    DateTime.utc(2027, 5, 8),
    destinationID: _savingsID,
  );
  entry(
    '${p}000000000009',
    '40.00',
    DateTime.utc(2027, 5, 9),
    destinationID: _flaggedID,
  );
  entry(
    '${p}000000000010',
    '-99.00',
    DateTime.utc(2027, 6, 1),
    categoryID: _childID,
  );
  entry(
    '${p}000000000011',
    '-3.00',
    DateTime.utc(2026, 1, 1),
    categoryID: _childlessID,
  );
  entry(
    '${p}000000000012',
    '-4.00',
    DateTime.utc(2026, 12, 31),
    categoryID: _childlessID,
  );
  entry(
    '${p}000000000013',
    '-5.00',
    DateTime.utc(2027, 1, 1),
    categoryID: _childlessID,
  );
  entry(
    '${p}000000000014',
    '-7.00',
    DateTime.utc(2028, 12, 15),
    categoryID: _childID,
  );
}

Future<void> _settle(_ManualRunner runner, Ledger ledger) async {
  runner.pending.last.complete(Accounting.analysisItems(ledger.state));
  await pumpEventQueue();
}

Decimal _rowsTotal(PeriodBreakdown breakdown) =>
    breakdown.rows.fold(Decimal.zero, (sum, row) => sum + row.amount);

PeriodBreakdown _readyBreakdown(
  AnalysisQueries queries, {
  required DateTime period,
  required AnalysisPeriodMode mode,
  required CategoryKind kind,
  required BreakdownLevel level,
}) {
  final read = queries.readCategoryBreakdown(
    period: period,
    mode: mode,
    kind: kind,
    level: level,
  );
  expect(read.state, AnalysisQueryState.ready);
  return read.value!;
}

void main() {
  test('mayBreakdownMatchesPeriodAndMonthSlotAtBothLevels', () async {
    final setup = _setup();
    _populate(setup.ledger);
    await _settle(setup.runner, setup.ledger);
    final queries = setup.queries;

    final period = queries.readPeriod(window: _mayWindow);
    expect(period.state, AnalysisQueryState.ready);
    expect(period.value?.spent, Decimal.parse(_mayExpenseTotal));
    expect(period.value?.income, Decimal.parse(_mayIncomeTotal));

    for (final kind in CategoryKind.values) {
      final spread = queries.readMonthSpread(endMonth: _may, kind: kind);
      expect(spread.state, AnalysisQueryState.ready);
      final slot = spread.value!.slots.singleWhere(
        (candidate) => candidate.month == _may,
      );
      final want = kind == CategoryKind.expense
          ? period.value?.spent
          : period.value?.income;
      expect(slot.total, want);
      for (final level in BreakdownLevel.values) {
        final breakdown = _readyBreakdown(
          queries,
          period: _may,
          mode: AnalysisPeriodMode.month,
          kind: kind,
          level: level,
        );
        expect(breakdown.window, monthWindow(_may));
        expect(_rowsTotal(breakdown), want);
        expect(_rowsTotal(breakdown), slot.total);
      }
    }

    final expense = _readyBreakdown(
      queries,
      period: _may,
      mode: AnalysisPeriodMode.month,
      kind: CategoryKind.expense,
      level: BreakdownLevel.categories,
    );
    expect(expense.total, Decimal.parse(_mayExpenseTotal));
    expect(expense.rows.map((row) => row.bucketID), [
      _syntheticID,
      _mainID,
      _childlessID,
    ]);
    expect(expense.rows.map((row) => row.amount), [
      Decimal.parse('40.00'),
      Decimal.parse('30.00'),
      Decimal.parse('15.00'),
    ]);
    expect(
      expense.rows.fold(Decimal.zero, (sum, row) => sum + row.sharePercent),
      Decimal.parse('100.0'),
    );

    final leaves = _readyBreakdown(
      queries,
      period: _may,
      mode: AnalysisPeriodMode.month,
      kind: CategoryKind.expense,
      level: BreakdownLevel.subcategories,
    );
    expect(leaves.total, Decimal.parse(_mayExpenseTotal));
    expect(leaves.rows.map((row) => (row.bucketID, row.isDirect, row.amount)), [
      (_syntheticID, false, Decimal.parse('40.00')),
      (_mainID, true, Decimal.parse('20.00')),
      (_childlessID, false, Decimal.parse('15.00')),
      (_childID, false, Decimal.parse('10.00')),
    ]);

    final income = _readyBreakdown(
      queries,
      period: _may,
      mode: AnalysisPeriodMode.month,
      kind: CategoryKind.income,
      level: BreakdownLevel.subcategories,
    );
    expect(income.total, Decimal.parse(_mayIncomeTotal));
    expect(income.rows, [
      BreakdownRow(
        bucketID: _payID,
        mainBucketID: _payID,
        isDirect: false,
        amount: Decimal.parse(_mayIncomeTotal),
        sharePercent: Decimal.parse('100.0'),
      ),
    ]);
  });

  test('yearBreakdownCoversCalendarYearAndCountsFutureDecember', () async {
    final setup = _setup();
    _populate(setup.ledger);
    await _settle(setup.runner, setup.ledger);
    final queries = setup.queries;

    DateRange yearWindow(int year) =>
        DateRange(DateTime.utc(year, 1, 1), DateTime.utc(year + 1, 1, 1));
    final spread = queries.readYearSpread(
      endYear: 2027,
      kind: CategoryKind.expense,
    );
    expect(spread.state, AnalysisQueryState.ready);

    for (final year in [2026, 2027]) {
      final period = queries.readPeriod(window: yearWindow(year));
      expect(period.state, AnalysisQueryState.ready);
      final slot = spread.value!.slots.singleWhere(
        (candidate) => candidate.year == year,
      );
      expect(slot.total, period.value?.spent);
      for (final level in BreakdownLevel.values) {
        final breakdown = _readyBreakdown(
          queries,
          period: DateTime.utc(year, 6, 15),
          mode: AnalysisPeriodMode.year,
          kind: CategoryKind.expense,
          level: level,
        );
        expect(breakdown.window, yearWindow(year));
        expect(_rowsTotal(breakdown), period.value?.spent);
        expect(_rowsTotal(breakdown), slot.total);
      }
    }
    expect(
      _readyBreakdown(
        queries,
        period: DateTime.utc(2026, 6, 15),
        mode: AnalysisPeriodMode.year,
        kind: CategoryKind.expense,
        level: BreakdownLevel.categories,
      ).total,
      Decimal.parse(_year2026ExpenseTotal),
    );
    expect(
      _readyBreakdown(
        queries,
        period: DateTime.utc(2027, 6, 15),
        mode: AnalysisPeriodMode.year,
        kind: CategoryKind.expense,
        level: BreakdownLevel.categories,
      ).total,
      Decimal.parse(_year2027ExpenseTotal),
    );

    final futureYear = queries.readCategoryBreakdown(
      period: DateTime.utc(2028, 7, 4),
      mode: AnalysisPeriodMode.year,
      kind: CategoryKind.expense,
      level: BreakdownLevel.categories,
    );
    expect(futureYear.state, AnalysisQueryState.ready);
    expect(futureYear.value?.total, Decimal.parse(_futureDecemberTotal));
    expect(futureYear.value?.window, yearWindow(2028));
    expect(futureYear.value?.rows.map((row) => row.bucketID), [_mainID]);

    final futureSpread = queries.readYearSpread(
      endYear: 2028,
      kind: CategoryKind.expense,
    );
    expect(futureSpread.state, AnalysisQueryState.failed);
  });

  test('periodInputsNormaliseToUtcMidnight', () async {
    final setup = _setup();
    _populate(setup.ledger);
    await _settle(setup.runner, setup.ledger);
    final queries = setup.queries;

    final canonical = queries.readCategoryBreakdown(
      period: _may,
      mode: AnalysisPeriodMode.month,
      kind: CategoryKind.expense,
      level: BreakdownLevel.categories,
    );
    expect(canonical.state, AnalysisQueryState.ready);
    expect(canonical.value?.window, monthWindow(_may));
    expect(
      identical(
        queries.readCategoryBreakdown(
          period: DateTime.utc(2027, 5, 20, 14, 45),
          mode: AnalysisPeriodMode.month,
          kind: CategoryKind.expense,
          level: BreakdownLevel.categories,
        ),
        canonical,
      ),
      isTrue,
    );
    expect(
      identical(
        queries.readCategoryBreakdown(
          period: DateTime(2027, 5, 20, 14, 45),
          mode: AnalysisPeriodMode.month,
          kind: CategoryKind.expense,
          level: BreakdownLevel.categories,
        ),
        canonical,
      ),
      isTrue,
    );

    final yearCanonical = queries.readCategoryBreakdown(
      period: DateTime.utc(2027, 1, 1),
      mode: AnalysisPeriodMode.year,
      kind: CategoryKind.expense,
      level: BreakdownLevel.categories,
    );
    expect(
      identical(
        queries.readCategoryBreakdown(
          period: DateTime(2027, 12, 31, 23, 59),
          mode: AnalysisPeriodMode.year,
          kind: CategoryKind.expense,
          level: BreakdownLevel.categories,
        ),
        yearCanonical,
      ),
      isTrue,
    );
  });

  test('modeAloneSeparatesJanuaryReadsWithSharedWindowStart', () async {
    final setup = _setup();
    _populate(setup.ledger);
    await _settle(setup.runner, setup.ledger);
    final queries = setup.queries;

    final january = DateTime.utc(2027, 1, 15);
    final monthRead = queries.readCategoryBreakdown(
      period: january,
      mode: AnalysisPeriodMode.month,
      kind: CategoryKind.expense,
      level: BreakdownLevel.categories,
    );
    final yearRead = queries.readCategoryBreakdown(
      period: january,
      mode: AnalysisPeriodMode.year,
      kind: CategoryKind.expense,
      level: BreakdownLevel.categories,
    );
    expect(monthRead.state, AnalysisQueryState.ready);
    expect(yearRead.state, AnalysisQueryState.ready);
    expect(
      monthRead.value?.window,
      DateRange(DateTime.utc(2027, 1, 1), DateTime.utc(2027, 2, 1)),
    );
    expect(
      yearRead.value?.window,
      DateRange(DateTime.utc(2027, 1, 1), DateTime.utc(2028, 1, 1)),
    );
    expect(monthRead.value?.window.start, yearRead.value?.window.start);
    expect(monthRead.value?.total, Decimal.parse('5.00'));
    expect(yearRead.value?.total, Decimal.parse(_year2027ExpenseTotal));
    expect(identical(yearRead, monthRead), isFalse);
  });

  test('periodInputsUseNamedCalendarDayAcrossBoundaries', () async {
    final setup = _setup();
    _populate(setup.ledger);
    await _settle(setup.runner, setup.ledger);
    final queries = setup.queries;

    AnalysisQueryResult<PeriodBreakdown> query(
      DateTime period,
      AnalysisPeriodMode mode,
    ) => queries.readCategoryBreakdown(
      period: period,
      mode: mode,
      kind: CategoryKind.expense,
      level: BreakdownLevel.categories,
    );

    final januaryWall = DateTime(2026, 1, 1, 0, 30);
    final decemberWall = DateTime(2025, 12, 31, 23, 30);

    final januaryMonth = query(januaryWall, AnalysisPeriodMode.month);
    expect(januaryMonth.state, AnalysisQueryState.ready);
    expect(
      januaryMonth.value?.window,
      DateRange(DateTime.utc(2026, 1, 1), DateTime.utc(2026, 2, 1)),
    );
    expect(januaryMonth.value?.total, Decimal.parse('3.00'));
    expect(
      identical(
        query(DateTime.utc(2026, 1, 15), AnalysisPeriodMode.month),
        januaryMonth,
      ),
      isTrue,
    );

    final januaryYear = query(januaryWall, AnalysisPeriodMode.year);
    expect(januaryYear.state, AnalysisQueryState.ready);
    expect(
      januaryYear.value?.window,
      DateRange(DateTime.utc(2026, 1, 1), DateTime.utc(2027, 1, 1)),
    );
    expect(januaryYear.value?.total, Decimal.parse(_year2026ExpenseTotal));
    expect(
      identical(
        query(DateTime.utc(2026, 6, 15), AnalysisPeriodMode.year),
        januaryYear,
      ),
      isTrue,
    );

    final decemberMonth = query(decemberWall, AnalysisPeriodMode.month);
    expect(decemberMonth.state, AnalysisQueryState.ready);
    expect(
      decemberMonth.value?.window,
      DateRange(DateTime.utc(2025, 12, 1), DateTime.utc(2026, 1, 1)),
    );
    expect(decemberMonth.value?.total, Decimal.zero);
    expect(decemberMonth.value?.rows, isEmpty);
    expect(
      identical(
        query(DateTime.utc(2025, 12, 15), AnalysisPeriodMode.month),
        decemberMonth,
      ),
      isTrue,
    );

    final decemberYear = query(decemberWall, AnalysisPeriodMode.year);
    expect(decemberYear.state, AnalysisQueryState.ready);
    expect(
      decemberYear.value?.window,
      DateRange(DateTime.utc(2025, 1, 1), DateTime.utc(2026, 1, 1)),
    );
    expect(decemberYear.value?.total, Decimal.zero);
    expect(decemberYear.value?.rows, isEmpty);
    expect(
      identical(
        query(DateTime.utc(2025, 6, 15), AnalysisPeriodMode.year),
        decemberYear,
      ),
      isTrue,
    );
  });

  test('emptyLedgersGiveEmptyBreakdowns', () async {
    final setup = _setup();
    await _settle(setup.runner, setup.ledger);
    for (final mode in AnalysisPeriodMode.values) {
      for (final level in BreakdownLevel.values) {
        for (final kind in CategoryKind.values) {
          final breakdown = _readyBreakdown(
            setup.queries,
            period: _may,
            mode: mode,
            kind: kind,
            level: level,
          );
          expect(breakdown.total, Decimal.zero);
          expect(breakdown.rows, isEmpty);
        }
      }
    }

    final expenseOnly = _setup();
    expenseOnly.ledger.addAccount(
      Account(id: _checkingID, name: 'Checking', type: AccountType.checking),
    );
    expenseOnly.ledger.addCategory(
      TransactionCategory(
        id: _mainID,
        name: 'Main',
        kind: CategoryKind.expense,
        colorHex: '#000000',
        includeInAnalysis: true,
        parentID: null,
        symbol: 'tag',
      ),
    );
    expenseOnly.ledger.addEntry(
      Entry(
        id: 'f0000000-0000-0000-0000-000000000001',
        amount: Decimal.parse('-10.00'),
        name: 'entry',
        sourceID: _checkingID,
        categoryID: _mainID,
        date: _may,
      ),
    );
    await _settle(expenseOnly.runner, expenseOnly.ledger);
    for (final level in BreakdownLevel.values) {
      final incomeMonth = _readyBreakdown(
        expenseOnly.queries,
        period: _may,
        mode: AnalysisPeriodMode.month,
        kind: CategoryKind.income,
        level: level,
      );
      expect(incomeMonth.total, Decimal.zero);
      expect(incomeMonth.rows, isEmpty);
      final incomeYear = _readyBreakdown(
        expenseOnly.queries,
        period: _may,
        mode: AnalysisPeriodMode.year,
        kind: CategoryKind.income,
        level: level,
      );
      expect(incomeYear.total, Decimal.zero);
      expect(incomeYear.rows, isEmpty);
    }
  });

  test('gatingFixturesStayOutOfBreakdowns', () async {
    final setup = _setup();
    _populate(setup.ledger);
    await _settle(setup.runner, setup.ledger);
    final queries = setup.queries;

    for (final level in BreakdownLevel.values) {
      final breakdown = _readyBreakdown(
        queries,
        period: _may,
        mode: AnalysisPeriodMode.month,
        kind: CategoryKind.expense,
        level: level,
      );
      expect(breakdown.total, Decimal.parse(_mayExpenseTotal));
      final ids = breakdown.rows.map((row) => row.bucketID).toSet();
      expect(ids, isNot(contains(_hiddenID)));
      expect(ids, isNot(contains(_excludedParentID)));
      expect(ids, isNot(contains(_excludedChildID)));
    }
  });

  test('breakdownFollowsMixedMemoAndRevisionGate', () async {
    final setup = _setup();
    final ledger = setup.ledger;
    final queries = setup.queries;
    final runner = setup.runner;

    final loading = queries.readCategoryBreakdown(
      period: _may,
      mode: AnalysisPeriodMode.month,
      kind: CategoryKind.expense,
      level: BreakdownLevel.categories,
    );
    expect(loading.state, AnalysisQueryState.loading);
    expect(loading.value, isNull);
    expect(loading.sourceRevision, isNull);

    _populate(ledger);
    await _settle(runner, ledger);
    final settled = queries.readCategoryBreakdown(
      period: _may,
      mode: AnalysisPeriodMode.month,
      kind: CategoryKind.expense,
      level: BreakdownLevel.categories,
    );
    expect(settled.state, AnalysisQueryState.ready);
    expect(settled.sourceRevision, ledger.revision);
    expect(settled.value?.total, Decimal.parse(_mayExpenseTotal));

    ledger.addEntry(
      Entry(
        id: 'f0000000-0000-0000-0000-000000000001',
        amount: Decimal.parse('-2.00'),
        name: 'entry',
        sourceID: _checkingID,
        categoryID: _childID,
        date: DateTime.utc(2027, 5, 12),
      ),
    );
    final retained = queries.readCategoryBreakdown(
      period: _may,
      mode: AnalysisPeriodMode.month,
      kind: CategoryKind.expense,
      level: BreakdownLevel.categories,
    );
    expect(retained.state, AnalysisQueryState.loading);
    expect(retained.value, settled.value);
    expect(retained.sourceRevision, settled.sourceRevision);

    await _settle(runner, ledger);
    final updated = queries.readCategoryBreakdown(
      period: _may,
      mode: AnalysisPeriodMode.month,
      kind: CategoryKind.expense,
      level: BreakdownLevel.categories,
    );
    expect(updated.state, AnalysisQueryState.ready);
    expect(updated.sourceRevision, ledger.revision);
    expect(updated.value?.total, Decimal.parse('87.00'));
  });

  test('hierarchyAndItemsShareOneRevisionGate', () async {
    final setup = _setup();
    final ledger = setup.ledger;
    final queries = setup.queries;
    final runner = setup.runner;
    ledger.addAccount(
      Account(id: _checkingID, name: 'Checking', type: AccountType.checking),
    );
    ledger.addCategory(
      TransactionCategory(
        id: _soloMainID,
        name: 'Solo',
        kind: CategoryKind.expense,
        colorHex: '#000000',
        includeInAnalysis: true,
        parentID: null,
        symbol: 'tag',
      ),
    );
    ledger.addEntry(
      Entry(
        id: 'b0000000-0000-0000-0000-000000000001',
        amount: Decimal.parse('-10.00'),
        name: 'entry',
        sourceID: _checkingID,
        categoryID: _soloMainID,
        date: DateTime.utc(2027, 5, 5),
      ),
    );
    await _settle(runner, ledger);

    final settled = queries.readCategoryBreakdown(
      period: _may,
      mode: AnalysisPeriodMode.month,
      kind: CategoryKind.expense,
      level: BreakdownLevel.subcategories,
    );
    expect(settled.state, AnalysisQueryState.ready);
    expect(settled.value?.rows.single.isDirect, isFalse);

    ledger.addCategory(
      TransactionCategory(
        id: _soloChildID,
        name: 'Solo child',
        kind: CategoryKind.expense,
        colorHex: '#000000',
        includeInAnalysis: true,
        parentID: _soloMainID,
        symbol: 'tag',
      ),
    );
    final retained = queries.readCategoryBreakdown(
      period: _may,
      mode: AnalysisPeriodMode.month,
      kind: CategoryKind.expense,
      level: BreakdownLevel.subcategories,
    );
    expect(retained.state, AnalysisQueryState.loading);
    expect(retained.value, settled.value);
    expect(retained.sourceRevision, settled.sourceRevision);
    expect(retained.value?.rows.single.isDirect, isFalse);

    await _settle(runner, ledger);
    final updated = queries.readCategoryBreakdown(
      period: _may,
      mode: AnalysisPeriodMode.month,
      kind: CategoryKind.expense,
      level: BreakdownLevel.subcategories,
    );
    expect(updated.state, AnalysisQueryState.ready);
    expect(updated.sourceRevision, ledger.revision);
    expect(updated.value?.rows.single.isDirect, isTrue);
    expect(updated.value?.total, Decimal.parse('10.00'));
  });

  test('staleCompletionKeepsTheNewerBreakdown', () async {
    final setup = _setup();
    final ledger = setup.ledger;
    final queries = setup.queries;
    final runner = setup.runner;
    _populate(ledger);
    await _settle(runner, ledger);
    final base = runner.pending.length;

    PeriodBreakdown read() => _readyBreakdown(
      queries,
      period: _may,
      mode: AnalysisPeriodMode.month,
      kind: CategoryKind.expense,
      level: BreakdownLevel.categories,
    );
    final settledTotal = read().total;

    ledger.addEntry(
      Entry(
        id: 'b0000000-0000-0000-0000-000000000001',
        amount: Decimal.parse('-1.00'),
        name: 'entry',
        sourceID: _checkingID,
        categoryID: _childID,
        date: DateTime.utc(2027, 5, 12),
      ),
    );
    final itemsAfterFirst = Accounting.analysisItems(ledger.state);
    ledger.addEntry(
      Entry(
        id: 'b0000000-0000-0000-0000-000000000002',
        amount: Decimal.parse('-2.00'),
        name: 'entry',
        sourceID: _checkingID,
        categoryID: _childID,
        date: DateTime.utc(2027, 5, 13),
      ),
    );
    final itemsAfterBoth = Accounting.analysisItems(ledger.state);

    runner.pending[base + 1].complete(itemsAfterBoth);
    await pumpEventQueue();
    final newest = queries.readCategoryBreakdown(
      period: _may,
      mode: AnalysisPeriodMode.month,
      kind: CategoryKind.expense,
      level: BreakdownLevel.categories,
    );
    expect(newest.state, AnalysisQueryState.ready);
    expect(newest.sourceRevision, ledger.revision);
    expect(newest.value?.total, settledTotal + Decimal.parse('3.00'));

    runner.pending[base].complete(itemsAfterFirst);
    await pumpEventQueue();
    final afterStale = queries.readCategoryBreakdown(
      period: _may,
      mode: AnalysisPeriodMode.month,
      kind: CategoryKind.expense,
      level: BreakdownLevel.categories,
    );
    expect(afterStale.state, AnalysisQueryState.ready);
    expect(afterStale.sourceRevision, ledger.revision);
    expect(afterStale.value, newest.value);
    expect(afterStale.value?.total, settledTotal + Decimal.parse('3.00'));
  });

  test('failedRefreshRetainsBreakdownAndRetryRecovers', () async {
    final setup = _setup();
    final ledger = setup.ledger;
    final queries = setup.queries;
    final runner = setup.runner;
    _populate(ledger);
    await _settle(runner, ledger);

    final settled = queries.readCategoryBreakdown(
      period: _may,
      mode: AnalysisPeriodMode.month,
      kind: CategoryKind.expense,
      level: BreakdownLevel.categories,
    );
    expect(settled.state, AnalysisQueryState.ready);

    ledger.addEntry(
      Entry(
        id: 'f0000000-0000-0000-0000-000000000001',
        amount: Decimal.parse('-1.00'),
        name: 'entry',
        sourceID: _checkingID,
        categoryID: _childID,
        date: DateTime.utc(2027, 5, 12),
      ),
    );
    runner.pending.last.completeError(StateError('boom'));
    await pumpEventQueue();
    await pumpEventQueue();

    final failed = queries.readCategoryBreakdown(
      period: _may,
      mode: AnalysisPeriodMode.month,
      kind: CategoryKind.expense,
      level: BreakdownLevel.categories,
    );
    expect(failed.state, AnalysisQueryState.failed);
    expect(failed.value, settled.value);
    expect(failed.sourceRevision, settled.sourceRevision);

    final fresh = queries.readCategoryBreakdown(
      period: _may,
      mode: AnalysisPeriodMode.month,
      kind: CategoryKind.expense,
      level: BreakdownLevel.subcategories,
    );
    expect(fresh.state, AnalysisQueryState.failed);
    expect(fresh.value, isNull);
    expect(fresh.sourceRevision, isNull);

    final retrying = queries.retry();
    runner.pending.last.complete(Accounting.analysisItems(ledger.state));
    await retrying;
    await pumpEventQueue();

    final recovered = queries.readCategoryBreakdown(
      period: _may,
      mode: AnalysisPeriodMode.month,
      kind: CategoryKind.expense,
      level: BreakdownLevel.categories,
    );
    expect(recovered.state, AnalysisQueryState.ready);
    expect(recovered.sourceRevision, ledger.revision);
    expect(recovered.value?.total, Decimal.parse('86.00'));
  });

  test('memoIdentitySeparatesByKindLevelModeAndPeriod', () async {
    final setup = _setup();
    _populate(setup.ledger);
    await _settle(setup.runner, setup.ledger);
    final queries = setup.queries;

    AnalysisQueryResult<PeriodBreakdown> read({
      DateTime? period,
      AnalysisPeriodMode? mode,
      CategoryKind? kind,
      BreakdownLevel? level,
    }) => queries.readCategoryBreakdown(
      period: period ?? _may,
      mode: mode ?? AnalysisPeriodMode.month,
      kind: kind ?? CategoryKind.expense,
      level: level ?? BreakdownLevel.categories,
    );

    final first = read();
    expect(first.state, AnalysisQueryState.ready);
    expect(identical(read(), first), isTrue);
    expect(
      identical(
        queries.readCategoryBreakdown(
          period: DateTime(2027, 5, 20, 14, 45),
          mode: AnalysisPeriodMode.month,
          kind: CategoryKind.expense,
          level: BreakdownLevel.categories,
        ),
        first,
      ),
      isTrue,
    );

    expect(identical(read(kind: CategoryKind.income), first), isFalse);
    expect(
      identical(read(level: BreakdownLevel.subcategories), first),
      isFalse,
    );
    expect(identical(read(mode: AnalysisPeriodMode.year), first), isFalse);
    expect(identical(read(period: _june), first), isFalse);
  });

  test('dayRolloverKeepsBreakdownTotalsWithoutRunnerWork', () async {
    final setup = _setup();
    _populate(setup.ledger);
    await _settle(setup.runner, setup.ledger);
    final queries = setup.queries;
    final calls = setup.runner.calls;

    final before = queries.readCategoryBreakdown(
      period: _may,
      mode: AnalysisPeriodMode.month,
      kind: CategoryKind.expense,
      level: BreakdownLevel.categories,
    );
    expect(before.state, AnalysisQueryState.ready);

    queries.setToday(DateTime.utc(2027, 6, 1));
    expect(setup.runner.calls, calls);

    final after = queries.readCategoryBreakdown(
      period: _may,
      mode: AnalysisPeriodMode.month,
      kind: CategoryKind.expense,
      level: BreakdownLevel.categories,
    );
    expect(after.state, AnalysisQueryState.ready);
    expect(after.value, before.value);
    expect(after.value?.total, Decimal.parse(_mayExpenseTotal));
  });

  test('futurePeriodsAreReadyAndEmptyUnlessBooked', () async {
    final setup = _setup();
    _populate(setup.ledger);
    await _settle(setup.runner, setup.ledger);
    final queries = setup.queries;

    final june = _readyBreakdown(
      queries,
      period: _june,
      mode: AnalysisPeriodMode.month,
      kind: CategoryKind.expense,
      level: BreakdownLevel.categories,
    );
    expect(june.total, Decimal.parse(_juneExpenseTotal));
    expect(june.rows.map((row) => row.bucketID), [_mainID]);
    final failedSpread = queries.readMonthSpread(
      endMonth: _june,
      kind: CategoryKind.expense,
    );
    expect(failedSpread.state, AnalysisQueryState.failed);

    final july = _readyBreakdown(
      queries,
      period: DateTime.utc(2027, 7, 1),
      mode: AnalysisPeriodMode.month,
      kind: CategoryKind.expense,
      level: BreakdownLevel.subcategories,
    );
    expect(july.total, Decimal.zero);
    expect(july.rows, isEmpty);

    final farYear = _readyBreakdown(
      queries,
      period: DateTime.utc(2029, 3, 10),
      mode: AnalysisPeriodMode.year,
      kind: CategoryKind.expense,
      level: BreakdownLevel.categories,
    );
    expect(farYear.total, Decimal.zero);
    expect(farYear.rows, isEmpty);
  });
}
