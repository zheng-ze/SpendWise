import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ledger/analysis/analysis_category_scope.dart';
import 'package:spendwise/ledger/analysis/analysis_query_result.dart';
import 'package:spendwise/ledger/analysis/category_breakdown.dart';
import 'package:spendwise/ledger/analysis/month_spread.dart';
import 'package:spendwise/ledger/analysis/scoped_trend.dart';
import 'package:spendwise/ledger/analysis_cache.dart';
import 'package:spendwise/ledger/analysis_queries.dart';
import 'package:spendwise/ledger/ledger.dart';

import 'analysis_test_support.dart';

const _checkingID = '11111111-1111-1111-1111-111111111111';
const _mainID = 'bbbbbbbb-3333-3333-3333-333333333333';
const _childAID = 'aaaaaaaa-4444-4444-4444-444444444444';
const _childBID = '55555555-5555-5555-5555-555555555555';
const _childlessID = '66666666-6666-6666-6666-666666666666';
const _payID = '77777777-7777-7777-7777-777777777777';
const _literalUncategorizedMain = 'uncategorized';
const _prefixedUncategorizedMain = 'bucket:uncategorized';

const _janAllTotal = '10.00';
const _mayAllTotal = '31.00';
const _twoEditMaySlotTotal = '141.00';
const _firstEditID = 'c0000000-0000-0000-0000-000000000001';
const _secondEditID = 'c0000000-0000-0000-0000-000000000002';
const _june2026AllTotal = '1.00';
const _monthAllTotal = '42.00';
const _yearAllTotal = '51.00';
const _mayUncategorizedTotal = '9.00';
const _decemberAllTotal = '6.00';
const _mayIncomeTotal = '50.00';
const _childlessMayTotal = '100.00';
const _mutatedMayTotal = '36.00';
const _mutatedYearTotal = '56.00';
const _staleNewestMayTotal = '34.00';
const _recoveredMayTotal = '32.00';

final _decemberToday = DateTime.utc(2027, 12, 15);
final _may = DateTime.utc(2027, 5, 1);
final _january = DateTime.utc(2027, 1, 1);
final _june = DateTime.utc(2027, 6, 1);
final _june2026 = DateTime.utc(2026, 6, 1);
final _december = DateTime.utc(2027, 12, 1);
final _yearPeriod = DateTime.utc(2027, 6, 15);

void _populate(Ledger ledger) {
  ledger.addAccount(
    Account(id: _checkingID, name: 'Checking', type: AccountType.checking),
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
      id: _childAID,
      name: 'Child A',
      kind: CategoryKind.expense,
      colorHex: '#000000',
      includeInAnalysis: true,
      parentID: _mainID,
      symbol: 'tag',
    ),
    TransactionCategory(
      id: _childBID,
      name: 'Child B',
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
  ]) {
    ledger.addCategory(category);
  }
  void entry(String id, String amount, DateTime date, {String? categoryID}) {
    ledger.addEntry(
      Entry(
        id: id,
        amount: Decimal.parse(amount),
        name: 'entry',
        sourceID: _checkingID,
        categoryID: categoryID,
        date: date,
      ),
    );
  }

  const p = 'e0000000-0000-0000-0000-';
  entry(
    '${p}000000000001',
    '-1.00',
    DateTime.utc(2026, 6, 1),
    categoryID: _childAID,
  );
  entry(
    '${p}000000000002',
    '-2.00',
    DateTime.utc(2027, 1, 5),
    categoryID: _childAID,
  );
  entry(
    '${p}000000000003',
    '-3.00',
    DateTime.utc(2027, 1, 6),
    categoryID: _childBID,
  );
  entry(
    '${p}000000000004',
    '-5.00',
    DateTime.utc(2027, 1, 7),
    categoryID: _mainID,
  );
  entry(
    '${p}000000000005',
    '-7.00',
    DateTime.utc(2027, 5, 10),
    categoryID: _childAID,
  );
  entry(
    '${p}000000000006',
    '-11.00',
    DateTime.utc(2027, 5, 11),
    categoryID: _childBID,
  );
  entry(
    '${p}000000000007',
    '-13.00',
    DateTime.utc(2027, 5, 12),
    categoryID: _mainID,
  );
  entry(
    '${p}000000000008',
    '-100.00',
    DateTime.utc(2027, 5, 12),
    categoryID: _childlessID,
  );
  entry(
    '${p}000000000009',
    '-4.00',
    DateTime.utc(2027, 6, 15),
    categoryID: _childAID,
  );
  entry(
    '${p}000000000010',
    '-6.00',
    DateTime.utc(2027, 12, 20),
    categoryID: _childBID,
  );
  entry(
    '${p}000000000011',
    '50.00',
    DateTime.utc(2027, 5, 10),
    categoryID: _payID,
  );
  entry('${p}000000000012', '-9.00', DateTime.utc(2027, 5, 14));
}

MonthSlot _slot(ScopedTrend trend, DateTime month) =>
    trend.slots.singleWhere((candidate) => candidate.month == month);

Decimal _slotsTotal(ScopedTrend trend) =>
    trend.slots.fold(Decimal.zero, (sum, slot) => sum + slot.total);

ScopedTrend _readyTrend(
  AnalysisQueries queries, {
  required DateTime period,
  required AnalysisPeriodMode mode,
  required CategoryKind kind,
  required String? mainBucketID,
  required AnalysisCategoryScope scope,
}) {
  final read = queries.readScopedTrend(
    period: period,
    mode: mode,
    kind: kind,
    mainBucketID: mainBucketID,
    scope: scope,
  );
  expect(read.state, AnalysisQueryState.ready);
  return read.value!;
}

Future<int> _editTwiceAndAcceptFirst(
  Ledger ledger,
  ManualRunner runner,
  AnalysisCache cache,
  int settledRevision,
) async {
  final base = runner.pending.length;
  ledger.addEntry(
    Entry(
      id: _firstEditID,
      amount: Decimal.parse('-10.00'),
      name: 'entry',
      sourceID: _checkingID,
      categoryID: _childAID,
      date: DateTime.utc(2027, 5, 20),
    ),
  );
  final itemsAfterFirst = Accounting.analysisItems(ledger.state);
  ledger.addEntry(
    Entry(
      id: _secondEditID,
      amount: Decimal.parse('-100.00'),
      name: 'entry',
      sourceID: _checkingID,
      categoryID: _childAID,
      date: DateTime.utc(2027, 5, 21),
    ),
  );
  expect(runner.pending.length, base + 2);
  runner.pending[base].complete(itemsAfterFirst);
  await pumpEventQueue();
  expect(cache.itemsSourceRevision, settledRevision + 1);
  expect(ledger.revision, settledRevision + 2);
  return base;
}

void main() {
  test('monthTrendScopesReturnCommittedSlotTotals', () async {
    final setup = setupAnalysis();
    _populate(setup.ledger);
    await settle(setup.runner, setup.ledger);
    final queries = setup.queries;

    ScopedTrend read(String? main, AnalysisCategoryScope scope) => _readyTrend(
      queries,
      period: _may,
      mode: AnalysisPeriodMode.month,
      kind: CategoryKind.expense,
      mainBucketID: main,
      scope: scope,
    );

    final all = read(_mainID, const AnalysisCategoryScope.all());
    expect(all.endMonth, _may);
    expect(all.slots.map((slot) => slot.month).toList(), [
      for (var back = 11; back >= 0; back--) DateTime.utc(2027, 5 - back, 1),
    ]);
    expect(_slot(all, _june2026).total, Decimal.parse(_june2026AllTotal));
    expect(_slot(all, _june2026).itemCount, 1);
    expect(_slot(all, _january).total, Decimal.parse(_janAllTotal));
    expect(_slot(all, _january).itemCount, 3);
    expect(_slot(all, _may).total, Decimal.parse(_mayAllTotal));
    expect(_slot(all, _may).itemCount, 3);
    expect(_slot(all, DateTime.utc(2027, 2, 1)).total, Decimal.zero);
    expect(_slot(all, DateTime.utc(2027, 2, 1)).itemCount, 0);
    expect(_slotsTotal(all), Decimal.parse(_monthAllTotal));

    final childA = read(_mainID, AnalysisCategoryScope.subcategory(_childAID));
    expect(_slot(childA, _june2026).total, Decimal.parse('1.00'));
    expect(_slot(childA, _january).total, Decimal.parse('2.00'));
    expect(_slot(childA, _may).total, Decimal.parse('7.00'));
    expect(_slotsTotal(childA), Decimal.parse('10.00'));

    final childB = read(_mainID, AnalysisCategoryScope.subcategory(_childBID));
    expect(_slot(childB, _january).total, Decimal.parse('3.00'));
    expect(_slot(childB, _may).total, Decimal.parse('11.00'));
    expect(_slotsTotal(childB), Decimal.parse('14.00'));

    final direct = read(_mainID, const AnalysisCategoryScope.direct());
    expect(_slot(direct, _june2026).total, Decimal.zero);
    expect(_slot(direct, _january).total, Decimal.parse('5.00'));
    expect(_slot(direct, _january).itemCount, 1);
    expect(_slot(direct, _may).total, Decimal.parse('13.00'));
    expect(_slotsTotal(direct), Decimal.parse('18.00'));

    final otherMain = read(_childlessID, const AnalysisCategoryScope.all());
    expect(_slot(otherMain, _may).total, Decimal.parse(_childlessMayTotal));

    final uncategorized = read(null, const AnalysisCategoryScope.all());
    expect(
      _slot(uncategorized, _may).total,
      Decimal.parse(_mayUncategorizedTotal),
    );
    expect(_slot(uncategorized, _may).itemCount, 1);

    final income = _readyTrend(
      queries,
      period: _may,
      mode: AnalysisPeriodMode.month,
      kind: CategoryKind.income,
      mainBucketID: _payID,
      scope: const AnalysisCategoryScope.all(),
    );
    expect(_slot(income, _may).total, Decimal.parse(_mayIncomeTotal));
    expect(_slot(income, _may).itemCount, 1);
  });

  test('yearTrendCountsEntriesAfterToday', () async {
    final setup = setupAnalysis();
    _populate(setup.ledger);
    await settle(setup.runner, setup.ledger);
    final queries = setup.queries;

    ScopedTrend read(String? main, AnalysisCategoryScope scope) => _readyTrend(
      queries,
      period: _yearPeriod,
      mode: AnalysisPeriodMode.year,
      kind: CategoryKind.expense,
      mainBucketID: main,
      scope: scope,
    );

    final all = read(_mainID, const AnalysisCategoryScope.all());
    expect(all.endMonth, _december);
    expect(all.slots.map((slot) => slot.month).toList(), [
      for (var month = 1; month <= 12; month++) DateTime.utc(2027, month, 1),
    ]);
    expect(_slot(all, _january).total, Decimal.parse(_janAllTotal));
    expect(_slot(all, _january).itemCount, 3);
    expect(_slot(all, _may).total, Decimal.parse(_mayAllTotal));
    expect(_slot(all, _may).itemCount, 3);
    expect(_slot(all, _june).total, Decimal.parse('4.00'));
    expect(_slot(all, _june).itemCount, 1);
    expect(_slot(all, _december).total, Decimal.parse('6.00'));
    expect(_slot(all, _december).itemCount, 1);
    expect(_slot(all, DateTime.utc(2027, 3, 1)).total, Decimal.zero);
    expect(_slot(all, DateTime.utc(2027, 3, 1)).itemCount, 0);
    expect(_slotsTotal(all), Decimal.parse(_yearAllTotal));

    final childA = read(_mainID, AnalysisCategoryScope.subcategory(_childAID));
    expect(_slotsTotal(childA), Decimal.parse('13.00'));

    final childB = read(_mainID, AnalysisCategoryScope.subcategory(_childBID));
    expect(_slot(childB, _december).total, Decimal.parse('6.00'));
    expect(_slotsTotal(childB), Decimal.parse('20.00'));

    final direct = read(_mainID, const AnalysisCategoryScope.direct());
    expect(_slotsTotal(direct), Decimal.parse('18.00'));
  });

  test('trendFollowsMixedMemoAndRevisionGate', () async {
    final setup = setupAnalysis();
    final ledger = setup.ledger;
    final queries = setup.queries;
    final runner = setup.runner;

    AnalysisQueryResult<ScopedTrend> monthRead() => queries.readScopedTrend(
      period: _may,
      mode: AnalysisPeriodMode.month,
      kind: CategoryKind.expense,
      mainBucketID: _mainID,
      scope: const AnalysisCategoryScope.all(),
    );
    AnalysisQueryResult<ScopedTrend> yearRead() => queries.readScopedTrend(
      period: _yearPeriod,
      mode: AnalysisPeriodMode.year,
      kind: CategoryKind.expense,
      mainBucketID: _mainID,
      scope: const AnalysisCategoryScope.all(),
    );

    final loadingMonth = monthRead();
    expect(loadingMonth.state, AnalysisQueryState.loading);
    expect(loadingMonth.value, isNull);
    expect(loadingMonth.sourceRevision, isNull);
    final loadingYear = yearRead();
    expect(loadingYear.state, AnalysisQueryState.loading);
    expect(loadingYear.value, isNull);
    expect(loadingYear.sourceRevision, isNull);

    _populate(ledger);
    await settle(runner, ledger);

    final settledMonth = monthRead();
    expect(settledMonth.state, AnalysisQueryState.ready);
    expect(settledMonth.sourceRevision, ledger.revision);
    expect(_slot(settledMonth.value!, _may).total, Decimal.parse(_mayAllTotal));
    final settledYear = yearRead();
    expect(settledYear.state, AnalysisQueryState.ready);
    expect(settledYear.sourceRevision, ledger.revision);
    expect(_slotsTotal(settledYear.value!), Decimal.parse(_yearAllTotal));

    ledger.addEntry(
      Entry(
        id: 'f0000000-0000-0000-0000-000000000001',
        amount: Decimal.parse('-5.00'),
        name: 'entry',
        sourceID: _checkingID,
        categoryID: _childAID,
        date: DateTime.utc(2027, 5, 20),
      ),
    );
    final retained = monthRead();
    expect(retained.state, AnalysisQueryState.loading);
    expect(retained.value, settledMonth.value);
    expect(retained.sourceRevision, settledMonth.sourceRevision);

    final freshWhilePending = queries.readScopedTrend(
      period: _may,
      mode: AnalysisPeriodMode.month,
      kind: CategoryKind.expense,
      mainBucketID: _childlessID,
      scope: const AnalysisCategoryScope.all(),
    );
    expect(freshWhilePending.state, AnalysisQueryState.loading);
    expect(freshWhilePending.value, isNull);
    expect(freshWhilePending.sourceRevision, isNull);

    await settle(runner, ledger);
    final updatedMonth = monthRead();
    expect(updatedMonth.state, AnalysisQueryState.ready);
    expect(updatedMonth.sourceRevision, ledger.revision);
    expect(
      _slot(updatedMonth.value!, _may).total,
      Decimal.parse(_mutatedMayTotal),
    );
    final updatedYear = yearRead();
    expect(updatedYear.state, AnalysisQueryState.ready);
    expect(updatedYear.sourceRevision, ledger.revision);
    expect(_slotsTotal(updatedYear.value!), Decimal.parse(_mutatedYearTotal));
  });

  test('staleCompletionKeepsTheNewerTrend', () async {
    final setup = setupAnalysis();
    final ledger = setup.ledger;
    final queries = setup.queries;
    final runner = setup.runner;
    _populate(ledger);
    await settle(runner, ledger);
    final base = runner.pending.length;

    ScopedTrend read() => _readyTrend(
      queries,
      period: _may,
      mode: AnalysisPeriodMode.month,
      kind: CategoryKind.expense,
      mainBucketID: _mainID,
      scope: const AnalysisCategoryScope.all(),
    );
    read();

    ledger.addEntry(
      Entry(
        id: 'b0000000-0000-0000-0000-000000000001',
        amount: Decimal.parse('-1.00'),
        name: 'entry',
        sourceID: _checkingID,
        categoryID: _childAID,
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
        categoryID: _childAID,
        date: DateTime.utc(2027, 5, 13),
      ),
    );
    final itemsAfterBoth = Accounting.analysisItems(ledger.state);

    runner.pending[base + 1].complete(itemsAfterBoth);
    await pumpEventQueue();
    final newest = queries.readScopedTrend(
      period: _may,
      mode: AnalysisPeriodMode.month,
      kind: CategoryKind.expense,
      mainBucketID: _mainID,
      scope: const AnalysisCategoryScope.all(),
    );
    expect(newest.state, AnalysisQueryState.ready);
    expect(newest.sourceRevision, ledger.revision);
    expect(
      _slot(newest.value!, _may).total,
      Decimal.parse(_staleNewestMayTotal),
    );

    runner.pending[base].complete(itemsAfterFirst);
    await pumpEventQueue();
    final afterStale = queries.readScopedTrend(
      period: _may,
      mode: AnalysisPeriodMode.month,
      kind: CategoryKind.expense,
      mainBucketID: _mainID,
      scope: const AnalysisCategoryScope.all(),
    );
    expect(afterStale.state, AnalysisQueryState.ready);
    expect(afterStale.sourceRevision, ledger.revision);
    expect(afterStale.value, newest.value);
    expect(
      _slot(afterStale.value!, _may).total,
      Decimal.parse(_staleNewestMayTotal),
    );
  });

  test('acceptedOlderRefreshDuringNewerPendingRetainsPublishedTrend', () async {
    final setup = setupAnalysis();
    final ledger = setup.ledger;
    final queries = setup.queries;
    final runner = setup.runner;
    final cache = setup.cache;
    _populate(ledger);
    await settle(runner, ledger);
    final settledRevision = ledger.revision;

    AnalysisQueryResult<ScopedTrend> read() => queries.readScopedTrend(
      period: _may,
      mode: AnalysisPeriodMode.month,
      kind: CategoryKind.expense,
      mainBucketID: _mainID,
      scope: const AnalysisCategoryScope.all(),
    );
    final settled = read();
    expect(settled.state, AnalysisQueryState.ready);
    expect(settled.sourceRevision, settledRevision);
    expect(_slot(settled.value!, _may).total, Decimal.parse(_mayAllTotal));

    final base = await _editTwiceAndAcceptFirst(
      ledger,
      runner,
      cache,
      settledRevision,
    );
    final intermediate = read();
    expect(intermediate.state, AnalysisQueryState.loading);
    expect(intermediate.value, settled.value);
    expect(intermediate.sourceRevision, settled.sourceRevision);
    expect(_slot(intermediate.value!, _may).total, Decimal.parse(_mayAllTotal));

    runner.pending[base + 1].complete(Accounting.analysisItems(ledger.state));
    await pumpEventQueue();
    final updated = read();
    expect(updated.state, AnalysisQueryState.ready);
    expect(updated.sourceRevision, ledger.revision);
    expect(
      _slot(updated.value!, _may).total,
      Decimal.parse(_twoEditMaySlotTotal),
    );
  });

  test(
    'acceptedOlderRefreshDuringNewerPendingLeavesUnreadTrendLoading',
    () async {
      final setup = setupAnalysis();
      final ledger = setup.ledger;
      final queries = setup.queries;
      final runner = setup.runner;
      final cache = setup.cache;
      _populate(ledger);
      await settle(runner, ledger);
      final settledRevision = ledger.revision;

      AnalysisQueryResult<ScopedTrend> read() => queries.readScopedTrend(
        period: _may,
        mode: AnalysisPeriodMode.month,
        kind: CategoryKind.expense,
        mainBucketID: _mainID,
        scope: const AnalysisCategoryScope.all(),
      );

      final base = await _editTwiceAndAcceptFirst(
        ledger,
        runner,
        cache,
        settledRevision,
      );
      final intermediate = read();
      expect(intermediate.state, AnalysisQueryState.loading);
      expect(intermediate.value, isNull);
      expect(intermediate.sourceRevision, isNull);

      runner.pending[base + 1].complete(Accounting.analysisItems(ledger.state));
      await pumpEventQueue();
      final updated = read();
      expect(updated.state, AnalysisQueryState.ready);
      expect(updated.sourceRevision, ledger.revision);
      expect(
        _slot(updated.value!, _may).total,
        Decimal.parse(_twoEditMaySlotTotal),
      );
    },
  );

  test('failedRefreshRetainsTrendAndRetryRecovers', () async {
    final setup = setupAnalysis();
    final ledger = setup.ledger;
    final queries = setup.queries;
    final runner = setup.runner;
    _populate(ledger);
    await settle(runner, ledger);

    final settled = queries.readScopedTrend(
      period: _may,
      mode: AnalysisPeriodMode.month,
      kind: CategoryKind.expense,
      mainBucketID: _mainID,
      scope: const AnalysisCategoryScope.all(),
    );
    expect(settled.state, AnalysisQueryState.ready);

    ledger.addEntry(
      Entry(
        id: 'f0000000-0000-0000-0000-000000000001',
        amount: Decimal.parse('-1.00'),
        name: 'entry',
        sourceID: _checkingID,
        categoryID: _childAID,
        date: DateTime.utc(2027, 5, 12),
      ),
    );
    runner.pending.last.completeError(StateError('boom'));
    await pumpEventQueue();
    await pumpEventQueue();

    final failed = queries.readScopedTrend(
      period: _may,
      mode: AnalysisPeriodMode.month,
      kind: CategoryKind.expense,
      mainBucketID: _mainID,
      scope: const AnalysisCategoryScope.all(),
    );
    expect(failed.state, AnalysisQueryState.failed);
    expect(failed.value, settled.value);
    expect(failed.sourceRevision, settled.sourceRevision);

    final fresh = queries.readScopedTrend(
      period: _may,
      mode: AnalysisPeriodMode.month,
      kind: CategoryKind.expense,
      mainBucketID: _childlessID,
      scope: const AnalysisCategoryScope.all(),
    );
    expect(fresh.state, AnalysisQueryState.failed);
    expect(fresh.value, isNull);
    expect(fresh.sourceRevision, isNull);

    final retrying = queries.retry();
    runner.pending.last.complete(Accounting.analysisItems(ledger.state));
    await retrying;
    await pumpEventQueue();

    final recovered = queries.readScopedTrend(
      period: _may,
      mode: AnalysisPeriodMode.month,
      kind: CategoryKind.expense,
      mainBucketID: _mainID,
      scope: const AnalysisCategoryScope.all(),
    );
    expect(recovered.state, AnalysisQueryState.ready);
    expect(recovered.sourceRevision, ledger.revision);
    expect(
      _slot(recovered.value!, _may).total,
      Decimal.parse(_recoveredMayTotal),
    );
  });

  test('memoIdentitySharesEquivalentInputs', () async {
    final setup = setupAnalysis();
    _populate(setup.ledger);
    await settle(setup.runner, setup.ledger);
    final queries = setup.queries;

    AnalysisQueryResult<ScopedTrend> monthRead({
      DateTime? period,
      String? mainBucketID,
      AnalysisCategoryScope? scope,
    }) => queries.readScopedTrend(
      period: period ?? _may,
      mode: AnalysisPeriodMode.month,
      kind: CategoryKind.expense,
      mainBucketID: mainBucketID ?? _mainID,
      scope: scope ?? const AnalysisCategoryScope.all(),
    );

    final first = monthRead();
    expect(first.state, AnalysisQueryState.ready);
    expect(identical(monthRead(), first), isTrue);
    final upperMain = monthRead(mainBucketID: _mainID.toUpperCase());
    expect(identical(upperMain, first), isTrue);
    expect(upperMain.value, first.value);
    final lowerScope = monthRead(
      scope: AnalysisCategoryScope.subcategory(_childAID),
    );
    final upperScope = monthRead(
      scope: AnalysisCategoryScope.subcategory(_childAID.toUpperCase()),
    );
    expect(identical(upperScope, lowerScope), isTrue);
    expect(upperScope.value, lowerScope.value);
    expect(
      identical(monthRead(period: DateTime.utc(2027, 5, 20, 14, 45)), first),
      isTrue,
    );
    expect(
      identical(monthRead(period: DateTime(2027, 5, 20, 14, 45)), first),
      isTrue,
    );

    AnalysisQueryResult<ScopedTrend> yearRead(DateTime period) =>
        queries.readScopedTrend(
          period: period,
          mode: AnalysisPeriodMode.year,
          kind: CategoryKind.expense,
          mainBucketID: _mainID,
          scope: const AnalysisCategoryScope.all(),
        );
    final januaryAnchored = yearRead(DateTime.utc(2027, 1, 10));
    expect(januaryAnchored.state, AnalysisQueryState.ready);
    expect(januaryAnchored.value?.endMonth, _december);
    expect(
      identical(yearRead(DateTime(2027, 12, 31, 23, 59)), januaryAnchored),
      isTrue,
    );
  });

  test('memoIdentitySeparatesByKindModePeriodMainAndScope', () async {
    final setup = setupAnalysis();
    _populate(setup.ledger);
    await settle(setup.runner, setup.ledger);
    final queries = setup.queries;

    const useDefaultMain = Object();
    AnalysisQueryResult<ScopedTrend> read({
      DateTime? period,
      AnalysisPeriodMode? mode,
      CategoryKind? kind,
      Object? mainBucketID = useDefaultMain,
      AnalysisCategoryScope? scope,
    }) => queries.readScopedTrend(
      period: period ?? _may,
      mode: mode ?? AnalysisPeriodMode.month,
      kind: kind ?? CategoryKind.expense,
      mainBucketID: identical(mainBucketID, useDefaultMain)
          ? _mainID
          : mainBucketID as String?,
      scope: scope ?? const AnalysisCategoryScope.all(),
    );

    final first = read();
    expect(first.state, AnalysisQueryState.ready);
    expect(identical(read(), first), isTrue);

    expect(identical(read(kind: CategoryKind.income), first), isFalse);
    expect(identical(read(mode: AnalysisPeriodMode.year), first), isFalse);
    expect(identical(read(period: _june), first), isFalse);
    expect(identical(read(mainBucketID: _childlessID), first), isFalse);
    expect(identical(read(mainBucketID: null), first), isFalse);
    expect(
      identical(read(scope: const AnalysisCategoryScope.direct()), first),
      isFalse,
    );
    expect(
      identical(
        read(scope: AnalysisCategoryScope.subcategory(_childAID)),
        first,
      ),
      isFalse,
    );
    expect(
      identical(
        read(scope: AnalysisCategoryScope.subcategory(_childAID)),
        read(scope: AnalysisCategoryScope.subcategory(_childBID)),
      ),
      isFalse,
    );

    final januaryMonth = read(period: _january);
    final januaryYear = read(period: _january, mode: AnalysisPeriodMode.year);
    expect(januaryMonth.state, AnalysisQueryState.ready);
    expect(januaryYear.state, AnalysisQueryState.ready);
    expect(januaryMonth.value?.endMonth, _january);
    expect(januaryYear.value?.endMonth, _december);
    expect(identical(januaryYear, januaryMonth), isFalse);
    expect(
      _slot(januaryMonth.value!, _january).total,
      Decimal.parse(_janAllTotal),
    );
    expect(_slotsTotal(januaryYear.value!), Decimal.parse(_yearAllTotal));

    final decemberSetup = setupAnalysis(today: _decemberToday);
    _populate(decemberSetup.ledger);
    await settle(decemberSetup.runner, decemberSetup.ledger);
    final decemberQueries = decemberSetup.queries;
    final decemberMonth = decemberQueries.readScopedTrend(
      period: _december,
      mode: AnalysisPeriodMode.month,
      kind: CategoryKind.expense,
      mainBucketID: _mainID,
      scope: const AnalysisCategoryScope.all(),
    );
    final decemberYear = decemberQueries.readScopedTrend(
      period: _december,
      mode: AnalysisPeriodMode.year,
      kind: CategoryKind.expense,
      mainBucketID: _mainID,
      scope: const AnalysisCategoryScope.all(),
    );
    expect(decemberMonth.state, AnalysisQueryState.ready);
    expect(decemberYear.state, AnalysisQueryState.ready);
    expect(decemberMonth.value?.endMonth, _december);
    expect(decemberYear.value?.endMonth, _december);
    expect(identical(decemberYear, decemberMonth), isFalse);
    expect(
      _slot(decemberMonth.value!, _december).total,
      Decimal.parse(_decemberAllTotal),
    );
    expect(_slotsTotal(decemberYear.value!), Decimal.parse(_yearAllTotal));

    final nullMain = read(mainBucketID: null);
    final literalMain = read(mainBucketID: _literalUncategorizedMain);
    final prefixedMain = read(mainBucketID: _prefixedUncategorizedMain);
    expect(nullMain.state, AnalysisQueryState.ready);
    expect(literalMain.state, AnalysisQueryState.ready);
    expect(prefixedMain.state, AnalysisQueryState.ready);
    expect(identical(literalMain, nullMain), isFalse);
    expect(identical(prefixedMain, nullMain), isFalse);
    expect(identical(prefixedMain, literalMain), isFalse);
    expect(
      _slot(nullMain.value!, _may).total,
      Decimal.parse(_mayUncategorizedTotal),
    );
    expect(_slotsTotal(literalMain.value!), Decimal.zero);
    expect(_slotsTotal(prefixedMain.value!), Decimal.zero);
  });

  test('dayRolloverKeepsYearTrendWithoutRunnerWork', () async {
    final setup = setupAnalysis(today: DateTime.utc(2027, 5, 31));
    _populate(setup.ledger);
    await settle(setup.runner, setup.ledger);
    final queries = setup.queries;
    final calls = setup.runner.calls;

    final before = queries.readScopedTrend(
      period: _yearPeriod,
      mode: AnalysisPeriodMode.year,
      kind: CategoryKind.expense,
      mainBucketID: _mainID,
      scope: const AnalysisCategoryScope.all(),
    );
    expect(before.state, AnalysisQueryState.ready);
    expect(_slotsTotal(before.value!), Decimal.parse(_yearAllTotal));

    queries.setToday(DateTime.utc(2027, 6, 1));
    expect(setup.runner.calls, calls);

    final after = queries.readScopedTrend(
      period: _yearPeriod,
      mode: AnalysisPeriodMode.year,
      kind: CategoryKind.expense,
      mainBucketID: _mainID,
      scope: const AnalysisCategoryScope.all(),
    );
    expect(after.state, AnalysisQueryState.ready);
    expect(after.value, before.value);
    expect(_slotsTotal(after.value!), Decimal.parse(_yearAllTotal));
  });

  test('invalidTrendFailsOnlyItsIdentity', () async {
    final setup = setupAnalysis();
    _populate(setup.ledger);
    await settle(setup.runner, setup.ledger);
    final queries = setup.queries;

    final valid = queries.readScopedTrend(
      period: _may,
      mode: AnalysisPeriodMode.month,
      kind: CategoryKind.expense,
      mainBucketID: _mainID,
      scope: const AnalysisCategoryScope.all(),
    );
    expect(valid.state, AnalysisQueryState.ready);

    final futureMonth = queries.readScopedTrend(
      period: _june,
      mode: AnalysisPeriodMode.month,
      kind: CategoryKind.expense,
      mainBucketID: _mainID,
      scope: const AnalysisCategoryScope.all(),
    );
    expect(futureMonth.state, AnalysisQueryState.failed);
    expect(futureMonth.value, isNull);
    expect(futureMonth.sourceRevision, isNull);

    final invalidScope = queries.readScopedTrend(
      period: _may,
      mode: AnalysisPeriodMode.month,
      kind: CategoryKind.expense,
      mainBucketID: _childlessID,
      scope: AnalysisCategoryScope.subcategory(_childAID),
    );
    expect(invalidScope.state, AnalysisQueryState.failed);
    expect(invalidScope.value, isNull);
    expect(invalidScope.sourceRevision, isNull);

    final stillValid = queries.readScopedTrend(
      period: _may,
      mode: AnalysisPeriodMode.month,
      kind: CategoryKind.expense,
      mainBucketID: _mainID,
      scope: const AnalysisCategoryScope.all(),
    );
    expect(stillValid.state, AnalysisQueryState.ready);
    expect(stillValid.value, valid.value);
    expect(stillValid.sourceRevision, valid.sourceRevision);

    final breakdown = queries.readCategoryBreakdown(
      period: _may,
      mode: AnalysisPeriodMode.month,
      kind: CategoryKind.expense,
      level: BreakdownLevel.categories,
    );
    expect(breakdown.state, AnalysisQueryState.ready);
  });
}
