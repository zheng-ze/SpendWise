import 'package:decimal/decimal.dart';
import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ledger/analysis/analysis_query_result.dart';
import 'package:spendwise/ledger/analysis/compared_with_usual.dart';
import 'package:spendwise/ledger/analysis/completeness.dart';
import 'package:spendwise/ledger/analysis_queries.dart';
import 'package:spendwise/ledger/ledger.dart';

import 'analysis_test_support.dart';

const _checkingID = '11111111-1111-1111-1111-111111111111';
const _foodID = '33333333-3333-3333-3333-333333333333';
const _payID = '44444444-4444-4444-4444-444444444444';

final _today = DateTime.utc(2027, 5, 15);
final _may = DateTime.utc(2027, 5, 1);
final _firstRecord = DateTime.utc(2027, 1, 1);

void _accounts(Ledger ledger) {
  ledger.addAccount(
    Account(id: _checkingID, name: 'Checking', type: AccountType.checking),
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
  ]) {
    ledger.addCategory(category);
  }
}

int _entryCounter = 0;

void _entry(Ledger ledger, String amount, DateTime date, String categoryID) {
  _entryCounter++;
  final suffix = _entryCounter.toString().padLeft(12, '0');
  ledger.addEntry(
    Entry(
      id: 'e0000000-0000-0000-0000-$suffix',
      amount: Decimal.parse(amount),
      name: 'entry',
      sourceID: _checkingID,
      categoryID: categoryID,
      date: date,
    ),
  );
}

void _populateStandard(Ledger ledger) {
  _accounts(ledger);
  _entry(ledger, '-1.00', DateTime.utc(2027, 1, 5), _foodID);
  _entry(ledger, '-1000.00', DateTime.utc(2027, 1, 31), _foodID);
  _entry(ledger, '-10.00', DateTime.utc(2027, 2, 5), _foodID);
  _entry(ledger, '-100.00', DateTime.utc(2027, 2, 20), _foodID);
  _entry(ledger, '-20.00', DateTime.utc(2027, 3, 5), _foodID);
  _entry(ledger, '-200.00', DateTime.utc(2027, 3, 20), _foodID);
  _entry(ledger, '-30.00', DateTime.utc(2027, 4, 5), _foodID);
  _entry(ledger, '-300.00', DateTime.utc(2027, 4, 20), _foodID);
  _entry(ledger, '-7.00', _may.add(const Duration(days: 2)), _foodID);
  _entry(ledger, '50.00', _may.add(const Duration(days: 3)), _payID);
  _entry(ledger, '-70.00', _may.add(const Duration(days: 19)), _foodID);
}

void _populateSparse(Ledger ledger) {
  _accounts(ledger);
  _entry(ledger, '-5.00', DateTime.utc(2027, 1, 10), _foodID);
  _entry(ledger, '-7.00', _may.add(const Duration(days: 2)), _foodID);
  _entry(ledger, '-70.00', _may.add(const Duration(days: 19)), _foodID);
}

void _populateLateStart(Ledger ledger) {
  _accounts(ledger);
  _entry(ledger, '-4.00', DateTime.utc(2027, 3, 2), _foodID);
  _entry(ledger, '-30.00', DateTime.utc(2027, 4, 5), _foodID);
  _entry(ledger, '-7.00', _may.add(const Duration(days: 2)), _foodID);
}

ComparedWithUsual _readyUsual(
  AnalysisQueries queries,
  DateTime month,
  CategoryKind kind,
) {
  final read = queries.readComparedWithUsual(month: month, kind: kind);
  expect(read.state, AnalysisQueryState.ready);
  return read.value!;
}

void main() {
  test('currentMonthComparesEntriesUpToTodayAgainstThreePrefixes', () async {
    final setup = setupAnalysis();
    _populateStandard(setup.ledger);
    await settle(setup.runner, setup.ledger);
    final usual = _readyUsual(setup.queries, _may, CategoryKind.expense);

    expect(usual.selectedMonth, _may);
    expect(usual.kind, CategoryKind.expense);
    expect(usual.firstRecordMonth, _firstRecord);
    expect(usual.observedWindow, DateRange(_may, DateTime.utc(2027, 5, 16)));
    expect(usual.elapsedDayCount, 15);
    expect(usual.observedTotal, Decimal.parse('7.00'));
    expect(usual.state, ComparedWithUsualState.available);
    expect(usual.baselineWindows, [
      DateRange(DateTime.utc(2027, 2, 1), DateTime.utc(2027, 2, 16)),
      DateRange(DateTime.utc(2027, 3, 1), DateTime.utc(2027, 3, 16)),
      DateRange(DateTime.utc(2027, 4, 1), DateTime.utc(2027, 4, 16)),
    ]);
    expect(usual.baselineTotal, Decimal.parse('60.00'));
    expect(usual.usualMean, Decimal.parse('20.00'));

    final period = setup.queries.readPeriod(
      window: DateRange(_may, DateTime.utc(2027, 6, 1)),
    );
    expect(period.state, AnalysisQueryState.ready);
    expect(period.value?.spent, Decimal.parse('77.00'));

    final income = _readyUsual(setup.queries, _may, CategoryKind.income);
    expect(income.observedTotal, Decimal.parse('50.00'));
    expect(income.state, ComparedWithUsualState.available);
    expect(income.baselineTotal, Decimal.zero);
    expect(income.usualMean, Decimal.zero);
  });

  test('pastMonthComparesWholeMonthWithClippedPrefixes', () async {
    final setup = setupAnalysis();
    _populateStandard(setup.ledger);
    await settle(setup.runner, setup.ledger);
    final usual = _readyUsual(
      setup.queries,
      DateTime.utc(2027, 4, 1),
      CategoryKind.expense,
    );

    expect(
      usual.observedWindow,
      DateRange(DateTime.utc(2027, 4, 1), DateTime.utc(2027, 5, 1)),
    );
    expect(usual.elapsedDayCount, 30);
    expect(usual.observedTotal, Decimal.parse('330.00'));
    expect(usual.state, ComparedWithUsualState.available);
    expect(usual.baselineWindows, [
      DateRange(DateTime.utc(2027, 1, 1), DateTime.utc(2027, 1, 31)),
      DateRange(DateTime.utc(2027, 2, 1), DateTime.utc(2027, 3, 1)),
      DateRange(DateTime.utc(2027, 3, 1), DateTime.utc(2027, 3, 31)),
    ]);
    expect(usual.baselineTotal, Decimal.parse('331.00'));
    expect(usual.usualMean, Decimal.parse('110.333333333333'));
  });

  test('shortMonthsClipPrefixesWithoutSpill', () {
    final leap = previousCompleteMonthWindows(
      selectedMonth: DateTime.utc(2028, 5, 1),
      elapsedDayCount: 31,
      firstRecordMonth: DateTime.utc(2028, 1, 1),
      today: DateTime.utc(2028, 6, 1),
    );
    expect(leap, [
      DateRange(DateTime.utc(2028, 2, 1), DateTime.utc(2028, 3, 1)),
      DateRange(DateTime.utc(2028, 3, 1), DateTime.utc(2028, 4, 1)),
      DateRange(DateTime.utc(2028, 4, 1), DateTime.utc(2028, 5, 1)),
    ]);

    final rollover = previousCompleteMonthWindows(
      selectedMonth: DateTime.utc(2028, 2, 1),
      elapsedDayCount: 29,
      firstRecordMonth: DateTime.utc(2027, 1, 1),
      today: DateTime.utc(2028, 3, 1),
    );
    expect(rollover, [
      DateRange(DateTime.utc(2027, 11, 1), DateTime.utc(2027, 11, 30)),
      DateRange(DateTime.utc(2027, 12, 1), DateTime.utc(2027, 12, 30)),
      DateRange(DateTime.utc(2028, 1, 1), DateTime.utc(2028, 1, 30)),
    ]);

    expect(
      () => previousCompleteMonthWindows(
        selectedMonth: _may,
        elapsedDayCount: 0,
        firstRecordMonth: _firstRecord,
        today: _today,
      ),
      throwsArgumentError,
    );
    expect(
      () => previousCompleteMonthWindows(
        selectedMonth: _may,
        elapsedDayCount: 32,
        firstRecordMonth: _firstRecord,
        today: _today,
      ),
      throwsArgumentError,
    );
  });

  test('incompleteBaselineReturnsNullWithoutFutureRejection', () {
    final windows = previousCompleteMonthWindows(
      selectedMonth: _may,
      elapsedDayCount: 15,
      firstRecordMonth: _firstRecord,
      today: DateTime.utc(2027, 4, 15),
    );
    expect(windows, isNull);
  });

  test('futureSelectionFailsAtFacadeButNotHelper', () async {
    final setup = setupAnalysis(today: DateTime.utc(2027, 4, 15));
    _populateStandard(setup.ledger);
    await settle(setup.runner, setup.ledger);

    final failed = setup.queries.readComparedWithUsual(
      month: _may,
      kind: CategoryKind.expense,
    );
    expect(failed.state, AnalysisQueryState.failed);
    expect(failed.value, isNull);
    expect(failed.sourceRevision, isNull);
  });

  test('preRecordBaselineIsUnavailableThroughFacadeAndHelper', () async {
    expect(
      previousCompleteMonthWindows(
        selectedMonth: _may,
        elapsedDayCount: 15,
        firstRecordMonth: DateTime.utc(2027, 3, 1),
        today: _today,
      ),
      isNull,
    );

    final setup = setupAnalysis();
    _populateLateStart(setup.ledger);
    await settle(setup.runner, setup.ledger);
    final usual = _readyUsual(setup.queries, _may, CategoryKind.expense);
    expect(usual.state, ComparedWithUsualState.notEnoughData);
    expect(usual.baselineWindows, isEmpty);
    expect(usual.baselineTotal, isNull);
    expect(usual.usualMean, isNull);
    expect(usual.observedTotal, Decimal.parse('7.00'));
    expect(usual.firstRecordMonth, DateTime.utc(2027, 3, 1));
  });

  test('emptyBaselinesStayAvailableWithZeroMean', () async {
    final setup = setupAnalysis();
    _populateSparse(setup.ledger);
    await settle(setup.runner, setup.ledger);
    final usual = _readyUsual(setup.queries, _may, CategoryKind.expense);
    expect(usual.state, ComparedWithUsualState.available);
    expect(usual.baselineWindows, hasLength(3));
    expect(usual.baselineTotal, Decimal.zero);
    expect(usual.usualMean, Decimal.zero);
    expect(usual.observedTotal, Decimal.parse('7.00'));
  });

  test('repeatingMeanUsesScaleTwelve', () {
    final usual = comparedWithUsual(
      items: [
        AnalysisItem(
          bucketID: null,
          amount: Decimal.parse('10.00'),
          date: DateTime.utc(2027, 2, 2),
          kind: CategoryKind.expense,
        ),
      ],
      selectedMonth: _may,
      kind: CategoryKind.expense,
      firstRecordMonth: _firstRecord,
      today: _today,
    );
    expect(usual.state, ComparedWithUsualState.available);
    expect(usual.observedTotal, Decimal.zero);
    expect(usual.baselineTotal, Decimal.parse('10.00'));
    expect(usual.usualMean, Decimal.parse('3.333333333333'));
    expect(
      usual.usualMean,
      (Decimal.parse('10.00') / Decimal.fromInt(3)).toDecimal(
        scaleOnInfinitePrecision: 12,
      ),
    );
  });

  test('usualEqualityIsListAwareAndWindowsAreImmutable', () {
    ComparedWithUsual build() => comparedWithUsual(
      items: Accounting.analysisItems(_standardState()),
      selectedMonth: _may,
      kind: CategoryKind.expense,
      firstRecordMonth: _firstRecord,
      today: _today,
    );
    final first = build();
    final second = build();
    expect(identical(first.baselineWindows, second.baselineWindows), isFalse);
    expect(second, first);
    expect(second.hashCode, first.hashCode);

    final reordered = ComparedWithUsual(
      selectedMonth: first.selectedMonth,
      kind: first.kind,
      firstRecordMonth: first.firstRecordMonth,
      observedWindow: first.observedWindow,
      elapsedDayCount: first.elapsedDayCount,
      observedTotal: first.observedTotal,
      state: first.state,
      baselineWindows: first.baselineWindows.reversed.toList(),
      baselineTotal: first.baselineTotal,
      usualMean: first.usualMean,
    );
    expect(reordered == first, isFalse);

    ComparedWithUsual unavailable() => comparedWithUsual(
      items: const [],
      selectedMonth: _may,
      kind: CategoryKind.expense,
      firstRecordMonth: DateTime.utc(2027, 3, 1),
      today: _today,
    );
    expect(unavailable(), unavailable());
    expect(unavailable().hashCode, unavailable().hashCode);
    expect(unavailable() == first, isFalse);

    expect(
      () => first.baselineWindows.add(first.baselineWindows.first),
      throwsUnsupportedError,
    );
  });

  test('usualFollowsMixedMemoAndRevisionGate', () async {
    final setup = setupAnalysis();
    final ledger = setup.ledger;
    final queries = setup.queries;
    final runner = setup.runner;

    final loading = queries.readComparedWithUsual(
      month: _may,
      kind: CategoryKind.expense,
    );
    expect(loading.state, AnalysisQueryState.loading);
    expect(loading.value, isNull);

    _populateStandard(ledger);
    await settle(runner, ledger);
    final settled = queries.readComparedWithUsual(
      month: _may,
      kind: CategoryKind.expense,
    );
    expect(settled.state, AnalysisQueryState.ready);
    expect(settled.sourceRevision, ledger.revision);
    expect(
      identical(
        queries.readComparedWithUsual(
          month: DateTime(2027, 5, 20, 14, 45),
          kind: CategoryKind.expense,
        ),
        settled,
      ),
      isTrue,
    );
    expect(
      identical(
        queries.readComparedWithUsual(month: _may, kind: CategoryKind.income),
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
    final retained = queries.readComparedWithUsual(
      month: _may,
      kind: CategoryKind.expense,
    );
    expect(retained.state, AnalysisQueryState.loading);
    expect(retained.value, settled.value);
    expect(retained.sourceRevision, settled.sourceRevision);

    await settle(runner, ledger);
    final updated = queries.readComparedWithUsual(
      month: _may,
      kind: CategoryKind.expense,
    );
    expect(updated.state, AnalysisQueryState.ready);
    expect(updated.sourceRevision, ledger.revision);
    expect(updated.value?.observedTotal, Decimal.parse('9.00'));

    final calls = runner.calls;
    var notifications = 0;
    queries.addListener(() => notifications++);
    queries.setToday(DateTime.utc(2027, 5, 16));
    expect(runner.calls, calls);
    expect(notifications, 1);
    final rolled = queries.readComparedWithUsual(
      month: _may,
      kind: CategoryKind.expense,
    );
    expect(rolled.state, AnalysisQueryState.ready);
    expect(rolled.value?.elapsedDayCount, 16);
    expect(
      rolled.value?.observedWindow,
      DateRange(_may, DateTime.utc(2027, 5, 17)),
    );
  });

  test('movingEarliestDuringPendingRefreshKeepsUsualCoherent', () async {
    final setup = setupAnalysis();
    final ledger = setup.ledger;
    final queries = setup.queries;
    final runner = setup.runner;
    _populateStandard(ledger);
    await settle(runner, ledger);

    final revision = ledger.revision;
    final settled = queries.readComparedWithUsual(
      month: _may,
      kind: CategoryKind.expense,
    );
    expect(settled.sourceRevision, revision);
    expect(settled.value?.state, ComparedWithUsualState.available);

    for (final id in ledger.state.entries.keys.toList()) {
      final entry = ledger.state.entries[id]!;
      if (entry.date.isBefore(DateTime.utc(2027, 3, 1))) {
        ledger.deleteEntry(id);
      }
    }

    final retained = queries.readComparedWithUsual(
      month: _may,
      kind: CategoryKind.expense,
    );
    expect(retained.state, AnalysisQueryState.loading);
    expect(retained.value, settled.value);
    expect(retained.sourceRevision, revision);

    final freshMonth = queries.readMonthCompleteness(
      month: DateTime.utc(2027, 1, 15),
    );
    expect(freshMonth.state, AnalysisQueryState.ready);
    expect(freshMonth.sourceRevision, ledger.revision);
    expect(freshMonth.value?.state, PeriodCompleteness.preRecord);
    expect(retained.sourceRevision, isNot(freshMonth.sourceRevision));

    await settle(runner, ledger);
    final accepted = queries.readComparedWithUsual(
      month: _may,
      kind: CategoryKind.expense,
    );
    expect(accepted.sourceRevision, ledger.revision);
    expect(accepted.value?.firstRecordMonth, DateTime.utc(2027, 3, 1));
    expect(accepted.value?.state, ComparedWithUsualState.notEnoughData);
  });

  test('usualFailureIsIsolated', () async {
    final setup = setupAnalysis();
    _populateStandard(setup.ledger);
    await settle(setup.runner, setup.ledger);
    final queries = setup.queries;

    final failed = queries.readComparedWithUsual(
      month: DateTime.utc(2027, 6, 1),
      kind: CategoryKind.expense,
    );
    expect(failed.state, AnalysisQueryState.failed);

    final period = queries.readPeriod(
      window: DateRange(_may, DateTime.utc(2027, 6, 1)),
    );
    expect(period.state, AnalysisQueryState.ready);
    expect(period.value?.spent, Decimal.parse('77.00'));

    await queries.retry();
    final usual = queries.readComparedWithUsual(
      month: _may,
      kind: CategoryKind.expense,
    );
    expect(usual.state, AnalysisQueryState.ready);
  });
}

LedgerState _standardState() {
  final ledger = Ledger();
  _populateStandard(ledger);
  return ledger.state;
}
