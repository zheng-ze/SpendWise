import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ledger/analysis/analysis_query_result.dart';
import 'package:spendwise/ledger/analysis/breakdowns/compared_with_usual.dart';
import 'package:spendwise/ledger/analysis_queries.dart';
import 'package:spendwise/ledger/ledger.dart';

import 'analysis_test_support.dart';

const _checkingID = '11111111-1111-1111-1111-111111111111';
const _foodID = '33333333-3333-3333-3333-333333333333';
const _payID = '44444444-4444-4444-4444-444444444444';

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
