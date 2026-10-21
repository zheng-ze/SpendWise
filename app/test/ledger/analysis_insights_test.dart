import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ledger/analysis/insights/insight_rules.dart';
import 'package:spendwise/ledger/analysis/insights/matched_day_insights.dart';
import 'package:spendwise/ledger/analysis/summaries/week_so_far.dart';

import 'analysis_test_support.dart';

final _groceriesID = testId(1);
final _diningID = testId(2);
final _transportID = testId(3);
final _snacksID = testId(5);

final _today = DateTime.utc(2026, 10, 3);
final _julyFirst = DateTime.utc(2026, 7, 1);
final _septemberFirst = DateTime.utc(2026, 9, 1);

Decimal _d(String value) => Decimal.parse(value);

LedgerState _state() {
  final state = LedgerState();
  for (final (id, parent) in [
    (_groceriesID, null),
    (_diningID, null),
    (_transportID, null),
    (_snacksID, _groceriesID),
  ]) {
    state.addCategory(
      TransactionCategory(
        id: id,
        name: id,
        kind: CategoryKind.expense,
        colorHex: '#000000',
        includeInAnalysis: true,
        parentID: parent,
        symbol: 'tag',
      ),
    );
  }
  return state;
}

AnalysisItem _expense(String? bucketID, String amount, DateTime date) =>
    AnalysisItem(
      bucketID: bucketID,
      amount: _d(amount),
      date: date,
      kind: CategoryKind.expense,
    );

List<AnalysisItem> _monthly(
  String? bucketID,
  List<String> amounts, {
  int day = 2,
  List<int> months = const [7, 8, 9, 7, 8],
}) => [
  for (var i = 0; i < amounts.length; i++)
    _expense(bucketID, amounts[i], DateTime.utc(2026, months[i], day)),
];

MatchedDayInsights _categories(
  List<AnalysisItem> items, {
  DateTime? today,
  DateTime? firstRecord,
  bool neverRecorded = false,
  InsightRules? rules,
}) => matchedDayInsights(
  items: items,
  state: _state(),
  firstRecordMonth: neverRecorded ? null : firstRecord ?? _julyFirst,
  today: today ?? _today,
  rules: rules ?? InsightRules.defaults,
);

WeekSoFar _week(
  List<AnalysisItem> items, {
  DateTime? today,
  DateTime? firstRecord,
  bool neverRecorded = false,
  InsightRules? rules,
}) => weekSoFar(
  items: items,
  firstRecordMonth: neverRecorded ? null : firstRecord ?? _septemberFirst,
  today: today ?? _today,
  rules: rules ?? InsightRules.defaults,
);

List<AnalysisItem> _groceriesAndDining() => [
  ..._monthly(
    _groceriesID,
    ['20', '20', '25', '25', '45'],
    months: [7, 7, 8, 8, 9],
  ),
  _expense(_groceriesID, '40.00', DateTime.utc(2026, 10, 1)),
  _expense(_groceriesID, '33.50', DateTime.utc(2026, 10, 3)),
  ..._monthly(
    _diningID,
    ['30', '28', '29', '29', '58'],
    months: [7, 7, 8, 8, 9],
  ),
  _expense(_diningID, '50.00', DateTime.utc(2026, 10, 2)),
  _expense(_diningID, '33.90', DateTime.utc(2026, 10, 3)),
  ..._monthly(_transportID, ['30', '30', '30', '1', '1']),
  _expense(_transportID, '47.00', DateTime.utc(2026, 10, 3)),
];

void main() {
  group('categoryChanges', () {
    test('sampleHistoryRanksGroceriesAndDiningAndExcludesTransport', () {
      final result = _categories(_groceriesAndDining());

      expect(result.state, InsightState.available);
      expect(
        result.observedWindow,
        DateRange(
          _today.subtract(const Duration(days: 2)),
          DateTime.utc(2026, 10, 4),
        ),
      );
      expect(result.elapsedDayCount, 3);
      expect(result.baselineWindows, [
        DateRange(DateTime.utc(2026, 7, 1), DateTime.utc(2026, 7, 4)),
        DateRange(DateTime.utc(2026, 8, 1), DateTime.utc(2026, 8, 4)),
        DateRange(DateTime.utc(2026, 9, 1), DateTime.utc(2026, 9, 4)),
      ]);
      expect(result.changes.map((c) => c.bucketID), [_groceriesID, _diningID]);
      final groceries = result.changes[0];
      expect(groceries.observedTotal, _d('73.50'));
      expect(groceries.observedExpenseCount, 2);
      expect(groceries.baselineTotal, _d('135'));
      expect(groceries.baselineExpenseCount, 5);
      expect(groceries.usualMean, _d('45'));
      expect(groceries.difference, _d('28.5'));
      expect(groceries.relativeChangePercent, _d('63.333333333333'));
      final dining = result.changes[1];
      expect(dining.observedTotal, _d('83.90'));
      expect(dining.usualMean, _d('58'));
      expect(dining.difference, _d('25.9'));
    });
    test('childEntriesRollIntoTheirMainCategory', () {
      final items = [
        ..._monthly(_groceriesID, ['30', '30', '30']),
        ..._monthly(_snacksID, ['0', '0'], day: 3),
        _expense(_snacksID, '150', _today),
        _expense(_groceriesID, '50', _today),
      ];

      final change = _categories(items).changes.single;
      expect(change.bucketID, _groceriesID);
      expect(change.observedTotal, _d('200'));
      expect(change.observedExpenseCount, 2);
      expect(change.baselineExpenseCount, 5);
    });

    test('aCategoryOnlyInTheBaselineCanQualifyAsADecrease', () {
      final change = _categories(
        _monthly(_groceriesID, ['100', '100', '100', '0', '0']),
      ).changes.single;

      expect(change.observedTotal, Decimal.zero);
      expect(change.difference, _d('-100'));
      expect(change.relativeChangePercent, _d('-100'));
    });
    test('nullAndSyntheticBucketsAreCategoriesAndTiesSortByIdNullLast', () {
      final synthetic = syntheticTransferExpenseBucketID(AccountType.savings);
      final items = [
        for (final bucket in [null, synthetic, _transportID]) ...[
          ..._monthly(bucket, ['30', '30', '30', '0', '0']),
          _expense(bucket, '100', _today),
        ],
      ];

      final changes = _categories(
        items,
        rules: InsightRules(maximumCategoryChanges: 3),
      ).changes;
      final ids = [synthetic, _transportID]..sort();
      expect(changes.map((c) => c.bucketID), [...ids, null]);
      expect(changes.map((c) => c.difference).toSet(), hasLength(1));
    });
    test('missingOrIncompleteHistoryNeedsHistory', () {
      final items = _groceriesAndDining();
      for (final (:first, :never) in [
        (first: null, never: true),
        (first: DateTime.utc(2026, 8, 1), never: false),
      ]) {
        final result = _categories(
          items,
          firstRecord: first,
          neverRecorded: never,
        );
        expect(result.state, InsightState.historyNeeded);
        expect(result.baselineWindows, isEmpty);
        expect(result.changes, isEmpty);
        expect(result.observedWindow.start, DateTime.utc(2026, 10, 1));
      }
    });
  });

  group('insightRules', () {
    final rules = InsightRules();
    bool qualifies(String observed, String baseline, [int count = 5]) =>
        rules.qualifies(_d(observed), _d(baseline), count);
    test('decreasesQualifyAndZeroChangeOrZeroBaselineDoNot', () {
      expect(qualifies('160', '600'), isTrue);
      expect(qualifies('200', '600'), isFalse);
      expect(qualifies('500', '0'), isFalse);
    });
  });

  group('weekSoFar', () {
    List<AnalysisItem> mondays(List<(int, String)> spec) => [
      for (final (day, amount) in spec)
        _expense(_groceriesID, amount, DateTime.utc(2026, 9, day)),
    ];

    final fiveBaseline = mondays([
      (7, '20'),
      (8, '20'),
      (14, '20'),
      (16, '20'),
      (23, '20'),
    ]);

    test('comparesElapsedWeekdaysWithThreePrecedingWeeks', () {
      final items = [
        ...fiveBaseline,
        _expense(_groceriesID, '200', DateTime.utc(2026, 9, 28)),
        _expense(_groceriesID, '40', _today),
        _expense(_groceriesID, '999', DateTime.utc(2026, 10, 4)),
        _expense(_groceriesID, '999', DateTime.utc(2026, 9, 13)),
        _expense(_groceriesID, '999', DateTime.utc(2026, 9, 6)),
      ];

      final result = _week(items);
      expect(result.weekStart, DateTime.utc(2026, 9, 28));
      expect(
        result.observedWindow,
        DateRange(DateTime.utc(2026, 9, 28), DateTime.utc(2026, 10, 4)),
      );
      expect(result.elapsedDayCount, 6);
      expect(result.observedTotal, _d('240'));
      expect(result.observedExpenseCount, 2);
      expect(result.state, InsightState.available);
      expect(result.baselineWindows, [
        DateRange(DateTime.utc(2026, 9, 7), DateTime.utc(2026, 9, 13)),
        DateRange(DateTime.utc(2026, 9, 14), DateTime.utc(2026, 9, 20)),
        DateRange(DateTime.utc(2026, 9, 21), DateTime.utc(2026, 9, 27)),
      ]);
      expect(result.baselineEvidence.map((e) => e.total), [
        _d('40'),
        _d('40'),
        _d('20'),
      ]);
      expect(result.baselineTotal, _d('100'));
      expect(result.baselineExpenseCount, 5);
      expect(result.usualMean, _d('33.333333333333'));
      expect(result.difference, _d('206.666666666666'));
      expect(result.relativeChangePercent, _d('620'));
      expect(result.qualifies, isTrue);
    });
    test('anyBaselineWeekBeforeTheFirstRecordNeedsHistory', () {
      for (final (:first, :never) in [
        (first: null, never: true),
        (first: DateTime.utc(2026, 10, 1), never: false),
      ]) {
        final result = _week(
          fiveBaseline,
          firstRecord: first,
          neverRecorded: never,
        );
        expect(result.state, InsightState.historyNeeded);
        expect(result.baselineWindows, isEmpty);
        expect(result.baselineEvidence, isEmpty);
        expect(result.baselineTotal, isNull);
        expect(result.usualMean, isNull);
        expect(result.qualifies, isFalse);
        expect(result.observedExpenseCount, 0);
      }
      final straddling = _week(
        const [],
        today: DateTime.utc(2026, 9, 20),
        firstRecord: DateTime.utc(2026, 9, 1),
      );
      expect(straddling.state, InsightState.historyNeeded);
    });

    test('fewerThanFiveBaselineExpensesKeepEvidenceButNeedHistory', () {
      final result = _week([
        ...fiveBaseline.take(4),
        _expense(_groceriesID, '500', _today),
      ]);

      expect(result.state, InsightState.historyNeeded);
      expect(result.baselineEvidence, hasLength(3));
      expect(result.baselineExpenseCount, 4);
      expect(result.qualifies, isFalse);
    });
    test('fiveZeroAmountExpensesGiveAZeroBaselineAndNoPercent', () {
      final result = _week([
        for (var i = 0; i < 5; i++)
          _expense(_groceriesID, '0', DateTime.utc(2026, 9, 7 + i)),
        _expense(_groceriesID, '90', _today),
      ]);

      expect(result.state, InsightState.available);
      expect(result.baselineTotal, Decimal.zero);
      expect(result.relativeChangePercent, isNull);
      expect(result.qualifies, isFalse);
    });

    test('resultsAreValueObjectsWithUnmodifiableCollections', () {
      final first = _week(fiveBaseline);
      final second = _week(fiveBaseline);

      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(() => first.baselineEvidence.clear(), throwsUnsupportedError);
      expect(() => first.baselineWindows.clear(), throwsUnsupportedError);
    });
  });
}
