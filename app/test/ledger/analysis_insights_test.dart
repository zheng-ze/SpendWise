import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ledger/analysis/insight_rules.dart';
import 'package:spendwise/ledger/analysis/matched_day_insights.dart';
import 'package:spendwise/ledger/analysis/week_so_far.dart';

import 'analysis_test_support.dart';

final _groceriesID = testId(1);
final _diningID = testId(2);
final _transportID = testId(3);
final _hobbiesID = testId(4);
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
    (_hobbiesID, null),
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

    test('evidenceHasThreeRecordsSummingToTheBaseline', () {
      final groceries = _categories(_groceriesAndDining()).changes.first;

      expect(groceries.baselineEvidence.map((e) => e.total), [
        _d('40'),
        _d('50'),
        _d('45'),
      ]);
      expect(groceries.baselineEvidence.map((e) => e.expenseItemCount), [
        2,
        2,
        1,
      ]);
      expect(
        groceries.baselineEvidence.fold(Decimal.zero, (s, e) => s + e.total),
        groceries.baselineTotal,
      );
    });

    test('theCapKeepsTheLargestChangesAndRulesReplaceIt', () {
      final items = [
        ..._groceriesAndDining(),
        ..._monthly(_hobbiesID, ['10', '10', '10', '0', '0']),
        _expense(_hobbiesID, '200', DateTime.utc(2026, 10, 2)),
      ];

      expect(_categories(items).changes.map((c) => c.bucketID), [
        _hobbiesID,
        _groceriesID,
      ]);
      expect(
        _categories(
          items,
          rules: InsightRules(maximumCategoryChanges: 1),
        ).changes.map((c) => c.bucketID),
        [_hobbiesID],
      );
    });

    test('baselineCountIsPerCategoryNotAggregate', () {
      final items = [
        ..._monthly(_groceriesID, ['30', '30', '30', '0', '0']),
        _expense(_groceriesID, '200', _today),
        ..._monthly(_diningID, ['30', '30', '30', '30']),
        _expense(_diningID, '200', _today),
      ];

      expect(_categories(items).changes.map((c) => c.bucketID), [_groceriesID]);
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

    test('aCategoryOnlyInTheCurrentWindowNeverQualifies', () {
      final result = _categories([_expense(_groceriesID, '500', _today)]);

      expect(result.state, InsightState.available);
      expect(result.changes, isEmpty);
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

    test('incomeIsIgnored', () {
      final items = [
        ..._monthly(_groceriesID, ['30', '30', '30', '0', '0']),
        _expense(_groceriesID, '30', _today),
        AnalysisItem(
          bucketID: _groceriesID,
          amount: _d('900'),
          date: _today,
          kind: CategoryKind.income,
        ),
      ];

      expect(_categories(items).changes, isEmpty);
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

    test('windowsStartInclusiveEndExclusiveAndNormalizeToday', () {
      final items = [
        ..._monthly(_groceriesID, ['30', '30', '30']),
        _expense(_groceriesID, '30', DateTime.utc(2026, 7, 4)),
        _expense(_groceriesID, '30', DateTime.utc(2026, 7, 1)),
        _expense(_groceriesID, '30', DateTime.utc(2026, 8, 3)),
        _expense(_groceriesID, '30', DateTime.utc(2026, 9, 3)),
        _expense(_groceriesID, '100', DateTime.utc(2026, 10, 1)),
        _expense(_groceriesID, '100', DateTime.utc(2026, 10, 4)),
        _expense(_groceriesID, '100', DateTime.utc(2026, 9, 30)),
      ];

      final change = _categories(
        items,
        today: DateTime.utc(2026, 10, 3, 18, 30),
      ).changes.single;
      expect(change.observedTotal, _d('100'));
      expect(change.baselineTotal, _d('180'));
      expect(change.baselineExpenseCount, 6);
    });

    test('shortAndLeapMonthsClipBaselineWindows', () {
      final leap = _categories(
        const [],
        today: DateTime.utc(2028, 5, 31),
        firstRecord: DateTime.utc(2028, 1, 1),
      );
      expect(
        leap.baselineWindows.first,
        DateRange(DateTime.utc(2028, 2, 1), DateTime.utc(2028, 3, 1)),
      );
      final rollover = _categories(
        const [],
        today: DateTime.utc(2027, 1, 31),
        firstRecord: DateTime.utc(2026, 10, 1),
      );
      expect(rollover.baselineWindows, [
        DateRange(DateTime.utc(2026, 10, 1), DateTime.utc(2026, 11, 1)),
        DateRange(DateTime.utc(2026, 11, 1), DateTime.utc(2026, 12, 1)),
        DateRange(DateTime.utc(2026, 12, 1), DateTime.utc(2027, 1, 1)),
      ]);
    });

    test('resultsAreValueObjectsWithUnmodifiableCollections', () {
      final first = _categories(_groceriesAndDining());
      final second = _categories(_groceriesAndDining());

      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(first.changes.first, second.changes.first);
      expect(() => first.changes.clear(), throwsUnsupportedError);
      expect(() => first.baselineWindows.clear(), throwsUnsupportedError);
      expect(
        () => first.changes.first.baselineEvidence.clear(),
        throwsUnsupportedError,
      );
    });
  });

  group('insightRules', () {
    final rules = InsightRules();
    bool qualifies(String observed, String baseline, [int count = 5]) =>
        rules.qualifies(_d(observed), _d(baseline), count);

    test('defaultsMatchTheProvisionalThresholds', () {
      expect(rules.minimumUsual, _d('10'));
      expect(rules.minimumAbsoluteChange, _d('20'));
      expect(rules.minimumRelativeChange, _d('0.20'));
      expect(rules.minimumExpenseCount, 5);
      expect(rules.maximumCategoryChanges, 2);
    });

    test('everyGateIsInclusive', () {
      expect(qualifies('30', '30'), isTrue);
      expect(qualifies('30', '29.99'), isFalse, reason: 'usual below 10');
      expect(qualifies('240', '600'), isTrue);
      expect(qualifies('239.99', '600'), isFalse, reason: 'relative below 20%');
      expect(qualifies('30', '30'), isTrue);
      expect(qualifies('29.99', '30'), isFalse, reason: 'change below 20');
      expect(qualifies('240', '600', 5), isTrue);
      expect(qualifies('240', '600', 4), isFalse, reason: 'fewer than 5');
    });

    test('decreasesQualifyAndZeroChangeOrZeroBaselineDoNot', () {
      expect(qualifies('160', '600'), isTrue);
      expect(qualifies('200', '600'), isFalse);
      expect(qualifies('500', '0'), isFalse);
    });

    test('zeroChangeNeverQualifiesEvenWithZeroThresholds', () {
      final open = InsightRules(
        minimumAbsoluteChange: Decimal.zero,
        minimumRelativeChange: Decimal.zero,
      );
      final flat = [
        ..._monthly(_groceriesID, ['10', '10', '10', '0', '0']),
        _expense(_groceriesID, '10', _today),
        ..._monthly(_diningID, ['10', '10', '10', '0', '0']),
        _expense(_diningID, '15', _today),
      ];
      final weekFlat = [
        for (var day = 7; day < 12; day++)
          _expense(_groceriesID, '6', DateTime.utc(2026, 9, day)),
        _expense(_groceriesID, '10', _today),
      ];

      expect(open.qualifies(_d('10'), _d('30'), 5), isFalse);
      expect(open.qualifies(_d('11'), _d('30'), 5), isTrue);
      expect(_categories(flat, rules: open).changes.map((c) => c.bucketID), [
        _diningID,
      ]);
      expect(_week(weekFlat, rules: open).qualifies, isFalse);
    });

    test('comparisonIsExactForRepeatingMeans', () {
      final strict = InsightRules(
        minimumUsual: _d('1'),
        minimumAbsoluteChange: _d('0.07'),
        minimumRelativeChange: _d('0'),
      );

      expect(strict.qualifies(_d('3.4'), _d('10'), 5), isFalse);
      expect(strict.qualifies(_d('3.44'), _d('10'), 5), isTrue);
    });

    test('invalidConstructionThrows', () {
      expect(
        () => InsightRules(minimumUsual: Decimal.zero),
        throwsArgumentError,
      );
      expect(
        () => InsightRules(minimumAbsoluteChange: _d('-1')),
        throwsArgumentError,
      );
      expect(
        () => InsightRules(minimumRelativeChange: _d('-0.1')),
        throwsArgumentError,
      );
      expect(() => InsightRules(minimumExpenseCount: 0), throwsArgumentError);
      expect(
        () => InsightRules(maximumCategoryChanges: 0),
        throwsArgumentError,
      );
    });

    test('replacementRulesChangeBothComputations', () {
      final loose = InsightRules(minimumExpenseCount: 2);
      final items = [
        _expense(_groceriesID, '60', DateTime.utc(2026, 9, 8)),
        _expense(_groceriesID, '60', DateTime.utc(2026, 9, 15)),
        _expense(_groceriesID, '300', _today),
      ];

      expect(_week(items).state, InsightState.historyNeeded);
      expect(_week(items, rules: loose).qualifies, isTrue);
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

    test('aWeekWithoutExpensesStaysInTheMean', () {
      final result = _week(
        mondays([(7, '20'), (8, '20'), (9, '20'), (10, '20'), (11, '20')]),
      );

      expect(result.baselineEvidence.map((e) => e.expenseItemCount), [5, 0, 0]);
      expect(result.usualMean, _d('33.333333333333'));
    });

    test('mondayOnlyAndPriorWeekEndingTodayAreMatched', () {
      final monday = _week([
        _expense(_groceriesID, '1', DateTime.utc(2026, 9, 28)),
        _expense(_groceriesID, '1', DateTime.utc(2026, 9, 14)),
        _expense(_groceriesID, '1', DateTime.utc(2026, 9, 15)),
        _expense(_groceriesID, '5', DateTime.utc(2026, 10, 5)),
      ], today: DateTime.utc(2026, 10, 5));

      expect(monday.elapsedDayCount, 1);
      expect(
        monday.observedWindow,
        DateRange(DateTime.utc(2026, 10, 5), DateTime.utc(2026, 10, 6)),
      );
      expect(
        monday.baselineWindows.last,
        DateRange(DateTime.utc(2026, 9, 28), DateTime.utc(2026, 9, 29)),
      );
      expect(monday.baselineExpenseCount, 2);
      expect(monday.observedTotal, _d('5'));
    });

    test('sundayUsesWholeWeeks', () {
      final sunday = _week(fiveBaseline, today: DateTime.utc(2026, 10, 4));

      expect(sunday.elapsedDayCount, 7);
      expect(
        sunday.baselineWindows.first,
        DateRange(DateTime.utc(2026, 9, 7), DateTime.utc(2026, 9, 14)),
      );
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

    test('sufficientHistoryBelowThresholdsIsAvailableButDoesNotQualify', () {
      final result = _week([
        ...fiveBaseline,
        _expense(_groceriesID, '33', _today),
      ]);

      expect(result.state, InsightState.available);
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
