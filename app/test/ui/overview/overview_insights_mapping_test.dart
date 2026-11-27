import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ledger/analysis/insights/insight_rules.dart';
import 'package:spendwise/ledger/analysis/insights/matched_day_insights.dart';
import 'package:spendwise/ledger/analysis/summaries/week_so_far.dart';
import 'package:spendwise/ui/format/money_format.dart';
import 'package:spendwise/ui/overview/overview_insights_mapping.dart';

import 'overview_fixture.dart';

final _today = DateTime.utc(2026, 10, 14);
final _monday = DateTime.utc(2026, 10, 12);

Decimal _d(String value) => Decimal.parse(value);

CategoryChange _change(String? bucketID, String difference) => CategoryChange(
  bucketID: bucketID,
  observedTotal: _d('100'),
  observedExpenseCount: 2,
  baselineEvidence: const [],
  baselineTotal: _d('150'),
  baselineExpenseCount: 3,
  usualMean: _d('50'),
  difference: _d(difference),
  relativeChangePercent: null,
);

MatchedDayInsights _insights(
  List<CategoryChange> changes, {
  InsightState state = InsightState.available,
}) => MatchedDayInsights(
  today: _today,
  selectedMonth: DateTime.utc(2026, 10),
  firstRecordMonth: DateTime.utc(2026, 1),
  observedWindow: DateRange(DateTime.utc(2026, 10), DateTime.utc(2026, 10, 15)),
  elapsedDayCount: 14,
  state: state,
  baselineWindows: const [],
  changes: changes,
);

List<OverviewInsightRow> _rows(OverviewInsights result) =>
    (result as OverviewInsightsAvailable).rows;

BaselineEvidence _evidence(int weekOffset, String total) {
  final start = _monday.subtract(Duration(days: 7 * weekOffset));
  return (
    window: DateRange(start, start.add(const Duration(days: 3))),
    total: _d(total),
    expenseItemCount: 1,
  );
}

WeekSoFar _week({
  InsightState state = InsightState.available,
  bool qualifies = true,
  String difference = '40',
  int elapsedDayCount = 3,
  DateTime? today,
}) {
  final day = today ?? _today;
  final weekStart = day.subtract(Duration(days: elapsedDayCount - 1));
  return WeekSoFar(
    today: day,
    weekStart: weekStart,
    firstRecordMonth: DateTime.utc(2026, 1),
    observedWindow: DateRange(weekStart, day.add(const Duration(days: 1))),
    elapsedDayCount: elapsedDayCount,
    observedTotal: _d('130'),
    observedExpenseCount: 4,
    state: state,
    baselineWindows: const [],
    baselineEvidence: [
      _evidence(3, '60'),
      _evidence(2, '90'),
      _evidence(1, '120'),
    ],
    baselineTotal: _d('270'),
    baselineExpenseCount: 3,
    usualMean: _d('90'),
    difference: _d(difference),
    relativeChangePercent: null,
    qualifies: qualifies,
  );
}

void main() {
  final state = emptyState();

  test('a higher category change reads higher with expense kind', () {
    final result = overviewInsights(
      _insights([_change(groceriesID, '25')]),
      state,
    );

    final row = _rows(result).single;
    expect(row.lead, 'Groceries is ');
    expect(row.amount, formatMoney(_d('25')));
    expect(row.tail, ' higher than your usual start.');
    expect(row.amountKind, AmountKind.expense);
  });

  test('a lower category change reads lower with income kind', () {
    final result = overviewInsights(
      _insights([_change(groceriesID, '-25')]),
      state,
    );

    final row = _rows(result).single;
    expect(row.amount, formatMoney(_d('25')));
    expect(row.tail, ' lower than your usual start.');
    expect(row.amountKind, AmountKind.income);
  });

  test('a null bucket reads Uncategorized is', () {
    final result = overviewInsights(_insights([_change(null, '25')]), state);

    expect(_rows(result).single.lead, 'Uncategorized is ');
  });

  test('a synthetic transfer bucket reads plural with are', () {
    final bucketID = syntheticTransferExpenseBucketID(AccountType.savings);

    final result = overviewInsights(
      _insights([_change(bucketID, '25')]),
      state,
    );

    expect(_rows(result).single.lead, 'Savings transfers are ');
  });

  test('rows keep the given order and are not capped again', () {
    final changes = [
      _change(null, '10'),
      _change(groceriesID, '-20'),
      _change(syntheticTransferExpenseBucketID(AccountType.savings), '30'),
      _change(syntheticTransferExpenseBucketID(AccountType.investment), '40'),
    ];

    final result = overviewInsights(_insights(changes), state);

    final leads = [for (final row in _rows(result)) row.lead];
    expect(leads, [
      'Uncategorized is ',
      'Groceries is ',
      'Savings transfers are ',
      'Investment transfers are ',
    ]);
  });

  test('history needed insights map to the history needed type', () {
    final result = overviewInsights(
      _insights(const [], state: InsightState.historyNeeded),
      state,
    );

    expect(result, isA<OverviewInsightsHistoryNeeded>());
  });

  test('a qualifying week has comparison and a usual note with the totals', () {
    final result = overviewWeekSoFar(_week()) as OverviewWeekAvailable;

    expect(result.total, formatMoney(_d('130')));
    expect(result.comparison, '${formatMoney(_d('40'))} more than usual');
    expect(
      result.usualNote,
      'Usual is ${formatMoney(_d('90'))}, the average of '
      '${formatMoney(_d('60'))}, ${formatMoney(_d('90'))} and '
      '${formatMoney(_d('120'))} over the same days of the last three weeks.',
    );
  });

  test('a qualifying lower week reads less than usual', () {
    final result =
        overviewWeekSoFar(_week(difference: '-40')) as OverviewWeekAvailable;

    expect(result.comparison, '${formatMoney(_d('40'))} less than usual');
  });

  test('an available week that does not qualify has no comparison', () {
    final result =
        overviewWeekSoFar(_week(qualifies: false)) as OverviewWeekAvailable;

    expect(result.comparison, isNull);
  });

  test('a qualifying week above usual has the expense total tone', () {
    final result = overviewWeekSoFar(_week()) as OverviewWeekAvailable;

    expect(result.totalTone, AmountKind.expense);
  });

  test('a qualifying week below usual has the income total tone', () {
    final result =
        overviewWeekSoFar(_week(difference: '-40')) as OverviewWeekAvailable;

    expect(result.totalTone, AmountKind.income);
  });

  test('an available week that does not qualify has no total tone', () {
    final result =
        overviewWeekSoFar(_week(qualifies: false)) as OverviewWeekAvailable;

    expect(result.totalTone, isNull);
  });

  test('a history needed week maps to the history needed type', () {
    final result = overviewWeekSoFar(_week(state: InsightState.historyNeeded));

    expect(result, isA<OverviewWeekHistoryNeeded>());
  });

  test('a Monday range reads a single day', () {
    final result = overviewWeekSoFar(
      _week(elapsedDayCount: 1, today: _monday),
    ) as OverviewWeekAvailable;

    expect(result.range.endsWith(' / 1 day'), isTrue);
    expect(result.range.contains(' - '), isFalse);
  });

  test('a mid-week range reads the number of days', () {
    final result = overviewWeekSoFar(_week()) as OverviewWeekAvailable;

    expect(result.range.endsWith(' / 3 days'), isTrue);
    expect(result.range.contains(' - '), isTrue);
  });
}
