import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ledger/analysis/breakdowns/analysis_category_scope.dart';
import 'package:spendwise/ledger/analysis/analysis_query_result.dart';
import 'package:spendwise/ledger/analysis/breakdowns/category_breakdown.dart';
import 'package:spendwise/ledger/analysis/summaries/month_spread.dart';
import 'package:spendwise/ledger/analysis/breakdowns/scoped_trend.dart';
import 'package:spendwise/ledger/analysis_queries.dart';
import 'package:spendwise/ledger/ledger.dart';

import 'analysis_test_support.dart';

const _checkingID = '11111111-1111-1111-1111-111111111111';
const _mainID = 'bbbbbbbb-3333-3333-3333-333333333333';
const _childAID = 'aaaaaaaa-4444-4444-4444-444444444444';
const _childBID = '55555555-5555-5555-5555-555555555555';
const _childlessID = '66666666-6666-6666-6666-666666666666';
const _payID = '77777777-7777-7777-7777-777777777777';

const _janAllTotal = '10.00';
const _mayAllTotal = '31.00';
const _yearAllTotal = '51.00';
const _recoveredMayTotal = '32.00';

final _may = DateTime.utc(2027, 5, 1);
final _january = DateTime.utc(2027, 1, 1);
final _june = DateTime.utc(2027, 6, 1);
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

void main() {
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
