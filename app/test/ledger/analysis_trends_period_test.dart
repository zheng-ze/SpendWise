import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/settings/display_preferences.dart' as settings;
import 'package:spendwise/ledger/analysis/analysis_query_result.dart';
import 'package:spendwise/ledger/analysis/breakdowns/scoped_trend.dart';
import 'package:spendwise/ledger/analysis/summaries/trends_period.dart';
import 'package:spendwise/ledger/analysis/breakdowns/category_breakdown.dart';
import 'package:spendwise/ledger/analysis_queries.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/stats/trends/trends_body.dart';
import 'package:spendwise/ui/stats/trends/trends_intent.dart';
import 'package:spendwise/ui/stats/trends/trends_projection.dart';

import 'analysis_test_support.dart';

const _accountID = '11111111-1111-1111-1111-111111111111';
const _foodID = '33333333-3333-3333-3333-333333333333';
const _otherID = '44444444-4444-4444-4444-444444444444';
const _currentOnlyID = '55555555-5555-5555-5555-555555555555';
final _today = DateTime.utc(2026, 10, 15);
final _endMonth = DateTime.utc(2026, 10, 1);

void _addCategory(Ledger ledger, String id, String name, {String? parentID}) {
  ledger.addCategory(
    TransactionCategory(
      id: id,
      name: name,
      kind: CategoryKind.expense,
      colorHex: '#000000',
      includeInAnalysis: true,
      parentID: parentID,
      symbol: 'tag',
    ),
  );
}

void _addEntry(
  Ledger ledger,
  String id,
  String amount,
  DateTime date,
  String categoryID,
) {
  ledger.addEntry(
    Entry(
      id: id,
      amount: Decimal.parse(amount),
      name: 'entry',
      sourceID: _accountID,
      categoryID: categoryID,
      date: date,
    ),
  );
}

void _populate(Ledger ledger, {bool currentOnly = false}) {
  ledger.addAccount(
    Account(id: _accountID, name: 'Checking', type: AccountType.checking),
  );
  _addCategory(ledger, _foodID, 'Food');
  if (currentOnly) {
    _addEntry(
      ledger,
      'e0000000-0000-0000-0000-000000000009',
      '-10',
      _endMonth,
      _foodID,
    );
    return;
  }
  _addCategory(ledger, _otherID, 'Other');
  _addEntry(
    ledger,
    'e0000000-0000-0000-0000-000000000001',
    '-30',
    DateTime.utc(2026, 7, 2),
    _foodID,
  );
  _addEntry(
    ledger,
    'e0000000-0000-0000-0000-000000000002',
    '-60',
    DateTime.utc(2026, 9, 2),
    _foodID,
  );
  _addEntry(
    ledger,
    'e0000000-0000-0000-0000-000000000003',
    '-900',
    DateTime.utc(2026, 10, 2),
    _otherID,
  );
}

void _populateForEdit(Ledger ledger) {
  ledger.addAccount(
    Account(id: _accountID, name: 'Checking', type: AccountType.checking),
  );
  _addCategory(ledger, _foodID, 'A');
  _addCategory(ledger, _otherID, 'B');
  _addEntry(
    ledger,
    'e0000000-0000-0000-0000-000000000004',
    '-1000',
    DateTime.utc(2025, 10, 4),
    _foodID,
  );
  _addEntry(
    ledger,
    'e0000000-0000-0000-0000-000000000005',
    '-40',
    DateTime.utc(2026, 7, 2),
    _otherID,
  );
  _addEntry(
    ledger,
    'e0000000-0000-0000-0000-000000000006',
    '-25',
    DateTime.utc(2026, 10, 2),
    _otherID,
  );
}

AnalysisQueryResult<MonthTrendsPeriod> _read(
  AnalysisQueries queries, {
  BreakdownLevel level = BreakdownLevel.categories,
  DateTime? endPeriod,
}) {
  final result = queries.readTrendsPeriod(
    endPeriod: endPeriod ?? _endMonth,
    mode: AnalysisPeriodMode.month,
    kind: CategoryKind.expense,
    level: level,
  );
  return AnalysisQueryResult<MonthTrendsPeriod>(
    value: result.value as MonthTrendsPeriod?,
    state: result.state,
    sourceRevision: result.sourceRevision,
  );
}

AnalysisQueryResult<YearTrendsPeriod> _readYear(AnalysisQueries queries) {
  final result = queries.readTrendsPeriod(
    endPeriod: DateTime.utc(2026),
    mode: AnalysisPeriodMode.year,
    kind: CategoryKind.expense,
    level: BreakdownLevel.categories,
  );
  return AnalysisQueryResult<YearTrendsPeriod>(
    value: result.value as YearTrendsPeriod?,
    state: result.state,
    sourceRevision: result.sourceRevision,
  );
}

AnalysisQueryResult<TrendsPeriod> _readAt(
  AnalysisQueries queries, {
  required DateTime endPeriod,
  AnalysisPeriodMode mode = AnalysisPeriodMode.month,
}) => queries.readTrendsPeriod(
  endPeriod: endPeriod,
  mode: mode,
  kind: CategoryKind.expense,
  level: BreakdownLevel.categories,
);

void main() {
  test('December Trends aggregate includes committed future entries', () async {
    final fixture = setupAnalysis(today: _today);
    fixture.ledger.addAccount(
      Account(id: _accountID, name: 'Checking', type: AccountType.checking),
    );
    _addCategory(fixture.ledger, _foodID, 'Food');
    _addCategory(fixture.ledger, _otherID, 'Other');
    _addCategory(fixture.ledger, _currentOnlyID, 'Current only');
    _addEntry(
      fixture.ledger,
      'e0000000-0000-0000-0000-000000000021',
      '-30',
      DateTime.utc(2026, 7, 2),
      _foodID,
    );
    _addEntry(
      fixture.ledger,
      'e0000000-0000-0000-0000-000000000022',
      '-60',
      DateTime.utc(2026, 9, 2),
      _foodID,
    );
    _addEntry(
      fixture.ledger,
      'e0000000-0000-0000-0000-000000000023',
      '-900',
      DateTime.utc(2026, 10, 20),
      _currentOnlyID,
    );
    _addEntry(
      fixture.ledger,
      'e0000000-0000-0000-0000-000000000024',
      '-120',
      DateTime.utc(2026, 12, 2),
      _otherID,
    );
    _addEntry(
      fixture.ledger,
      'e0000000-0000-0000-0000-000000000027',
      '-700',
      DateTime.utc(2027, 1, 2),
      _otherID,
    );
    await settle(fixture.runner, fixture.ledger);

    final result = _readAt(
      fixture.queries,
      endPeriod: DateTime.utc(2026, 12, 31),
    );

    expect(result.state, AnalysisQueryState.ready);
    final summary = result.value! as MonthTrendsPeriod;
    expect(summary.spread.slots, hasLength(12));
    final actualMonths = summary.spread.slots
        .map((slot) => slot.month)
        .toList();
    final expectedMonths = List.generate(
      12,
      (index) => DateTime.utc(2026, index + 1),
    );
    expect(actualMonths, expectedMonths);
    final nextJanuary = DateTime.utc(2027, 1);
    final includesNextJanuary = actualMonths.contains(nextJanuary);
    expect(includesNextJanuary, isFalse);
    expect(summary.spread.slots.last.total, Decimal.fromInt(120));
    expect(summary.breakdown.total, Decimal.fromInt(1110));
    expect(
      summary.spread.slots.fold(Decimal.zero, (sum, slot) => sum + slot.total),
      summary.breakdown.total,
    );
    expect(summary.averages.completePeriodCount, 3);
    final food = summary.averages.rows.singleWhere(
      (row) => row.bucketID == _foodID,
    );
    expect(food.numerator, Decimal.fromInt(90));
    expect(food.mean, Decimal.fromInt(30));
    final other = summary.averages.rows.singleWhere(
      (row) => row.bucketID == _otherID,
    );
    expect(other.numerator, Decimal.zero);
    expect(other.mean, Decimal.zero);
    final currentOnly = summary.averages.rows.singleWhere(
      (row) => row.bucketID == _currentOnlyID,
    );
    expect(currentOnly.numerator, Decimal.zero);
    expect(currentOnly.mean, Decimal.zero);
    expect(summary.highestMonth?.month, DateTime.utc(2026, 9));
  });

  test(
    'future Trends month identities normalize and stay revision-gated',
    () async {
      final fixture = setupAnalysis(today: _today);
      _populate(fixture.ledger);
      _addEntry(
        fixture.ledger,
        'e0000000-0000-0000-0000-000000000026',
        '-80',
        DateTime.utc(2027, 1, 2),
        _foodID,
      );
      await settle(fixture.runner, fixture.ledger);
      final december = _readAt(
        fixture.queries,
        endPeriod: DateTime.utc(2026, 12, 1),
      );
      final equivalentDecember = _readAt(
        fixture.queries,
        endPeriod: DateTime.utc(2026, 12, 24),
      );

      expect(december.state, AnalysisQueryState.ready);
      expect(equivalentDecember, same(december));
      final january = _readAt(
        fixture.queries,
        endPeriod: DateTime.utc(2027, 1, 20),
      );
      expect(january.state, AnalysisQueryState.ready);
      expect(january.value, isA<MonthTrendsPeriod>());
      expect(
        (january.value! as MonthTrendsPeriod).spread.slots.first.month,
        DateTime.utc(2026, 2),
      );
      final futureYear = _readAt(
        fixture.queries,
        endPeriod: DateTime.utc(2027, 12),
      );
      expect(futureYear.state, AnalysisQueryState.ready);
      expect(
        (futureYear.value! as MonthTrendsPeriod).spread.endMonth,
        DateTime.utc(2027, 12),
      );
      final futureYearSummary = futureYear.value! as MonthTrendsPeriod;
      expect(futureYearSummary.breakdown.total, Decimal.fromInt(80));
      expect(futureYearSummary.averages.completePeriodCount, 0);
      expect(futureYearSummary.averages.rows.single.mean, isNull);
      final rejectedYear = _readAt(
        fixture.queries,
        endPeriod: DateTime.utc(2027),
        mode: AnalysisPeriodMode.year,
      );
      expect(rejectedYear.state, AnalysisQueryState.failed);

      _addEntry(
        fixture.ledger,
        'e0000000-0000-0000-0000-000000000025',
        '-500',
        DateTime.utc(2026, 12, 5),
        _foodID,
      );
      final pending = _readAt(
        fixture.queries,
        endPeriod: DateTime.utc(2026, 12, 15),
      );
      expect(pending.state, AnalysisQueryState.loading);
      expect(pending.value, december.value);
      expect(pending.sourceRevision, december.sourceRevision);
      await settle(fixture.runner, fixture.ledger);
      final refreshed = _readAt(
        fixture.queries,
        endPeriod: DateTime.utc(2026, 12, 15),
      );
      expect(refreshed.state, AnalysisQueryState.ready);
      expect(refreshed.sourceRevision, fixture.ledger.revision);
      expect(
        (refreshed.value! as MonthTrendsPeriod).breakdown.total,
        Decimal.fromInt(1490),
      );
    },
  );

  test('month aggregate separates whole spread, complete observations and averages', () async {
    final fixture = setupAnalysis(today: _today);
    _populate(fixture.ledger);
    await settle(fixture.runner, fixture.ledger);
    final result = _read(fixture.queries);

    expect(result.state, AnalysisQueryState.ready);
    final summary = result.value!;
    expect(summary.breakdown.total, Decimal.fromInt(990));
    expect(
      summary.spread.slots.fold(Decimal.zero, (sum, slot) => sum + slot.total),
      Decimal.fromInt(990),
    );
    expect(summary.largestRow?.bucketID, _otherID);
    expect(summary.highestMonth?.month, DateTime.utc(2026, 9));
    expect(summary.averages.completePeriodCount, 3);
    final food = summary.averages.rows.singleWhere(
      (row) => row.bucketID == _foodID,
    );
    expect(food.numerator, Decimal.fromInt(90));
    expect(food.mean, Decimal.fromInt(30));
    final other = summary.averages.rows.singleWhere(
      (row) => row.bucketID == _otherID,
    );
    expect(other.numerator, Decimal.zero);
    expect(other.mean, Decimal.zero);
  });

  test('empty history has no observations or available averages', () async {
    final fixture = setupAnalysis(today: _today);
    await settle(fixture.runner, fixture.ledger);
    final result = _read(fixture.queries);

    expect(result.value!.breakdown.total, Decimal.zero);
    expect(result.value!.largestRow, isNull);
    expect(result.value!.highestMonth, isNull);
    expect(result.value!.averages.available, isFalse);
    expect(result.value!.averages.completePeriodCount, 0);
  });

  test('year aggregate sums the displayed calendar-year slots', () async {
    final fixture = setupAnalysis(today: _today);
    _populate(fixture.ledger);
    _addEntry(
      fixture.ledger,
      'e0000000-0000-0000-0000-000000000007',
      '-15',
      DateTime.utc(2025, 3, 3),
      _foodID,
    );
    await settle(fixture.runner, fixture.ledger);
    final summary = _readYear(fixture.queries).value!;

    expect(summary.spread.slots, hasLength(3));
    expect(summary.breakdown.total, Decimal.fromInt(1005));
    expect(
      summary.spread.slots.fold(Decimal.zero, (sum, slot) => sum + slot.total),
      summary.breakdown.total,
    );
    expect(summary.largestRow?.bucketID, _otherID);
  });

  test(
    'year averages count complete empty years and exclude the incomplete year',
    () async {
      final fixture = setupAnalysis(today: _today);
      fixture.ledger.addAccount(
        Account(id: _accountID, name: 'Checking', type: AccountType.checking),
      );
      _addCategory(fixture.ledger, _foodID, 'Food');
      _addCategory(fixture.ledger, _otherID, 'Other');
      _addEntry(
        fixture.ledger,
        'e0000000-0000-0000-0000-000000000011',
        '-30',
        DateTime.utc(2024, 1, 2),
        _foodID,
      );
      _addEntry(
        fixture.ledger,
        'e0000000-0000-0000-0000-000000000012',
        '-900',
        DateTime.utc(2026, 2, 2),
        _otherID,
      );
      await settle(fixture.runner, fixture.ledger);
      final summary = _readYear(fixture.queries).value!;
      final food = summary.averages.rows.singleWhere(
        (row) => row.bucketID == _foodID,
      );

      expect(summary.averages.completePeriodCount, 2);
      expect(food.numerator, Decimal.fromInt(30));
      expect(food.mean, Decimal.fromInt(15));
      expect(summary.highestYear?.year, 2024);
    },
  );

  test('year averages are unavailable when no year has a baseline', () async {
    final fixture = setupAnalysis(today: _today);
    fixture.ledger.addAccount(
      Account(id: _accountID, name: 'Checking', type: AccountType.checking),
    );
    _addCategory(fixture.ledger, _foodID, 'Food');
    _addEntry(
      fixture.ledger,
      'e0000000-0000-0000-0000-000000000013',
      '-30',
      DateTime.utc(2025, 7, 2),
      _foodID,
    );
    await settle(fixture.runner, fixture.ledger);
    final summary = _readYear(fixture.queries).value!;

    expect(summary.averages.completePeriodCount, 0);
    expect(summary.averages.available, isFalse);
    expect(summary.averages.rows.single.mean, isNull);
    expect(summary.highestYear, isNull);
  });

  test('mixed read retains its aggregate through failure and retry', () async {
    final fixture = setupAnalysis(today: _today);
    _populate(fixture.ledger, currentOnly: true);
    final loading = _read(fixture.queries);
    expect(loading.state, AnalysisQueryState.loading);
    await settle(fixture.runner, fixture.ledger);
    final acceptedResult = _read(fixture.queries);
    final accepted = acceptedResult.value!;
    expect(accepted.averages.completePeriodCount, 0);
    expect(accepted.averages.available, isFalse);
    expect(accepted.averages.rows.single.mean, isNull);

    _addEntry(
      fixture.ledger,
      'e0000000-0000-0000-0000-000000000010',
      '-5',
      _endMonth,
      _foodID,
    );
    final pending = _read(fixture.queries);
    expect(pending.state, AnalysisQueryState.loading);
    expect(pending.value, accepted);
    fixture.runner.pending.last.completeError(StateError('compute failed'));
    await pumpEventQueue();
    final failed = _read(fixture.queries);
    expect(failed.state, AnalysisQueryState.failed);
    expect(failed.value, accepted);

    final retry = fixture.queries.retry();
    fixture.runner.pending.last.complete(
      Accounting.analysisItems(fixture.ledger.state),
    );
    await retry;
    expect(_read(fixture.queries).value!.breakdown.total, Decimal.fromInt(15));
  });

  test('saved subcategory ranking preserves the Direct row identity', () async {
    final fixture = setupAnalysis(today: _today);
    fixture.ledger.addAccount(
      Account(id: _accountID, name: 'Checking', type: AccountType.checking),
    );
    _addCategory(fixture.ledger, _foodID, 'Food');
    _addCategory(fixture.ledger, _otherID, 'Child', parentID: _foodID);
    _addEntry(
      fixture.ledger,
      'e0000000-0000-0000-0000-000000000007',
      '-30',
      DateTime.utc(2026, 7, 2),
      _foodID,
    );
    _addEntry(
      fixture.ledger,
      'e0000000-0000-0000-0000-000000000008',
      '-70',
      DateTime.utc(2026, 7, 3),
      _otherID,
    );
    await settle(fixture.runner, fixture.ledger);
    final summary = _read(
      fixture.queries,
      level: BreakdownLevel.subcategories,
    ).value!;

    expect(summary.breakdown.rows.map((row) => (row.bucketID, row.isDirect)), [
      (_otherID, false),
      (_foodID, true),
    ]);
    expect(summary.largestRow?.sharePercent, Decimal.fromInt(70));
  });

  test(
    'editing the earliest record keeps the projected aggregate on one revision',
    () async {
      final fixture = setupAnalysis(today: _today);
      _populateForEdit(fixture.ledger);
      final oldEntry = fixture.ledger.state.entries.values.first;
      await settle(fixture.runner, fixture.ledger);
      final acceptedResult = _read(
        fixture.queries,
        endPeriod: DateTime.utc(2026, 12),
      );
      final accepted = acceptedResult.value!;
      expect(acceptedResult.sourceRevision, fixture.ledger.revision);
      expect(accepted.spread.earliestSpreadEndMonth, DateTime.utc(2025, 10));
      expect(accepted.breakdown.total, Decimal.fromInt(65));
      expect(accepted.largestRow?.bucketID, _otherID);
      expect(accepted.highestMonth?.month, DateTime.utc(2026, 7));
      expect(accepted.averages.completePeriodCount, 9);

      fixture.ledger.updateEntry(
        Entry(
          id: oldEntry.id,
          amount: oldEntry.amount,
          name: oldEntry.name,
          sourceID: oldEntry.sourceID,
          categoryID: oldEntry.categoryID,
          destinationID: oldEntry.destinationID,
          includeInAnalysis: oldEntry.includeInAnalysis,
          lifecycle: oldEntry.lifecycle,
          systemKind: oldEntry.systemKind,
          note: oldEntry.note,
          date: DateTime.utc(2026, 9, 4),
        ),
      );
      final pending = _read(fixture.queries, endPeriod: DateTime.utc(2026, 12));
      expect(pending.state, AnalysisQueryState.loading);
      expect(pending.value, accepted);
      expect(pending.sourceRevision, acceptedResult.sourceRevision);
      expect(
        _project(fixture.queries, fixture.ledger),
        isA<TrendsLoadingBody>(),
      );

      await settle(fixture.runner, fixture.ledger);
      final revisedResult = _read(
        fixture.queries,
        endPeriod: DateTime.utc(2026, 12),
      );
      final revised = revisedResult.value!;
      final ready = _project(
        fixture.queries,
        fixture.ledger,
        intent: TrendsIntent(
          kind: TrendsKind.expense,
          mode: TrendsMode.month,
          spreadEnd: monthSerial(DateTime.utc(2026, 12)),
          selected: monthSerial(DateTime.utc(2026, 10)),
          rememberedMonth: 10,
          followsCurrent: false,
        ),
      ) as TrendsReadyBody;
      expect(revised.firstRecordMonth, DateTime.utc(2026, 7));
      expect(revised.spread.earliestSpreadEndMonth, DateTime.utc(2026, 10));
      expect(revised.breakdown.total, Decimal.fromInt(1065));
      expect(revised.largestRow?.bucketID, _foodID);
      expect(revised.highestMonth?.month, DateTime.utc(2026, 9));
      expect(revised.averages.completePeriodCount, 3);
      expect(revisedResult.sourceRevision, fixture.ledger.revision);
      expect(ready.periodSummary, same(revised));
    },
  );
}

TrendsBody _project(
  AnalysisQueries queries,
  Ledger ledger, {
  TrendsIntent? intent,
}) => projectTrends(
  queries: queries,
  intent: intent ?? TrendsIntent.initial(_today),
  today: _today,
  ledgerRevision: ledger.revision,
  categories: const {},
  preferences: (
    chart: settings.BreakdownChart.donut,
    level: settings.BreakdownLevel.categories,
    colours: settings.ChartColours.categoryColours,
  ),
);
