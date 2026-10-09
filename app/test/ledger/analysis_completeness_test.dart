import 'dart:async';

import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ledger/analysis/analysis_query_result.dart';
import 'package:spendwise/ledger/analysis/completeness.dart';
import 'package:spendwise/ledger/analysis_cache.dart';
import 'package:spendwise/ledger/analysis_queries.dart';
import 'package:spendwise/ledger/ledger.dart';

const _accountID = '11111111-1111-1111-1111-111111111111';
const _foodID = '33333333-3333-3333-3333-333333333333';

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
  ledger.addAccount(
    Account(id: _accountID, name: 'Checking', type: AccountType.checking),
  );
  ledger.addCategory(
    TransactionCategory(
      id: _foodID,
      name: 'Food',
      kind: CategoryKind.expense,
      colorHex: '#000000',
      includeInAnalysis: true,
      parentID: null,
      symbol: 'tag',
    ),
  );
  final runner = _ManualRunner();
  final cache = AnalysisCache(runner: runner.call)
    ..start(ledger.bus, sourceRevision: () => ledger.revision);
  final queries = AnalysisQueries(
    ledger: ledger,
    cache: cache,
    today: today ?? DateTime.utc(2027, 5, 15),
  );
  addTearDown(() async {
    queries.dispose();
    await cache.dispose();
  });
  return (ledger: ledger, cache: cache, queries: queries, runner: runner);
}

void _addExpense(
  Ledger ledger,
  String id,
  String amount, {
  required DateTime date,
  bool includeInAnalysis = true,
}) {
  ledger.addEntry(
    Entry(
      id: id,
      amount: Decimal.parse(amount),
      name: 'lunch',
      sourceID: _accountID,
      categoryID: _foodID,
      date: date,
      includeInAnalysis: includeInAnalysis,
    ),
  );
}

LedgerState _stateWithHistory() {
  final state = LedgerState();
  state.addAccount(
    Account(id: _accountID, name: 'Checking', type: AccountType.checking),
  );
  state.addCategory(
    TransactionCategory(
      id: _foodID,
      name: 'Food',
      kind: CategoryKind.expense,
      colorHex: '#000000',
      includeInAnalysis: true,
      parentID: null,
      symbol: 'tag',
    ),
  );
  state.setOpeningBalance(
    Decimal.parse('100'),
    _accountID,
    date: DateTime.utc(2027, 2, 10),
  );
  state.addEntry(
    Entry(
      id: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      amount: Decimal.parse('-13.50'),
      name: 'lunch',
      sourceID: _accountID,
      categoryID: _foodID,
      date: DateTime.utc(2027, 1, 20),
      includeInAnalysis: false,
    ),
  );
  state.addEntry(
    Entry(
      id: 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
      amount: Decimal.parse('-7.00'),
      name: 'lunch',
      sourceID: _accountID,
      categoryID: _foodID,
      date: DateTime.utc(2027, 3, 5),
    ),
  );
  return state;
}

void main() {
  test('firstRecordMonthUsesEarliestEntryOfAnyKind', () {
    expect(firstRecordMonth(_stateWithHistory()), DateTime.utc(2027, 1, 1));
  });

  test('firstRecordMonthIsNullForAnEmptyLedger', () {
    expect(firstRecordMonth(LedgerState()), isNull);
  });

  test('classifyPeriodCoversMonthCases', () {
    final firstRecord = DateTime.utc(2027, 1, 1);
    final today = DateTime.utc(2027, 5, 15);
    expect(
      classifyPeriod(
        window: DateRange(DateTime.utc(2027, 4, 1), DateTime.utc(2027, 5, 1)),
        firstRecordMonth: firstRecord,
        today: today,
      ),
      PeriodCompleteness.complete,
    );
    expect(
      classifyPeriod(
        window: DateRange(DateTime.utc(2027, 5, 1), DateTime.utc(2027, 6, 1)),
        firstRecordMonth: firstRecord,
        today: today,
      ),
      PeriodCompleteness.incomplete,
    );
    expect(
      classifyPeriod(
        window: DateRange(DateTime.utc(2027, 7, 1), DateTime.utc(2027, 8, 1)),
        firstRecordMonth: firstRecord,
        today: today,
      ),
      PeriodCompleteness.incomplete,
    );
    expect(
      classifyPeriod(
        window: DateRange(DateTime.utc(2026, 12, 1), DateTime.utc(2027, 1, 1)),
        firstRecordMonth: firstRecord,
        today: today,
      ),
      PeriodCompleteness.preRecord,
    );
    expect(
      classifyPeriod(
        window: DateRange(DateTime.utc(2027, 4, 1), DateTime.utc(2027, 5, 1)),
        firstRecordMonth: null,
        today: today,
      ),
      PeriodCompleteness.preRecord,
    );
  });

  test('monthEndingExactlyTodayIsComplete', () {
    final today = DateTime.utc(2027, 6, 1);
    final firstRecord = DateTime.utc(2027, 1, 1);
    expect(
      classifyPeriod(
        window: DateRange(DateTime.utc(2027, 5, 1), DateTime.utc(2027, 6, 1)),
        firstRecordMonth: firstRecord,
        today: today,
      ),
      PeriodCompleteness.complete,
    );
    expect(
      classifyPeriod(
        window: DateRange(DateTime.utc(2027, 6, 1), DateTime.utc(2027, 7, 1)),
        firstRecordMonth: firstRecord,
        today: today,
      ),
      PeriodCompleteness.incomplete,
    );
  });

  test('classifyPeriodCoversWeekCases', () {
    final firstRecord = DateTime.utc(2027, 1, 1);
    expect(
      classifyPeriod(
        window: DateRange(DateTime.utc(2027, 5, 3), DateTime.utc(2027, 5, 10)),
        firstRecordMonth: firstRecord,
        today: DateTime.utc(2027, 5, 10),
      ),
      PeriodCompleteness.complete,
    );
    expect(
      classifyPeriod(
        window: DateRange(DateTime.utc(2027, 5, 10), DateTime.utc(2027, 5, 17)),
        firstRecordMonth: firstRecord,
        today: DateTime.utc(2027, 5, 12),
      ),
      PeriodCompleteness.incomplete,
    );
    expect(
      classifyPeriod(
        window: DateRange(DateTime.utc(2026, 12, 28), DateTime.utc(2027, 1, 4)),
        firstRecordMonth: firstRecord,
        today: DateTime.utc(2027, 5, 15),
      ),
      PeriodCompleteness.preRecord,
    );
  });

  test('ledgerOnlyReadsAreReadyWhileCacheIsPending', () async {
    final setup = _setup();
    final queries = setup.queries;

    final first = queries.readFirstRecordMonth();
    expect(first.state, AnalysisQueryState.ready);
    expect(first.value, isNull);
    expect(first.sourceRevision, isNotNull);

    final month = queries.readMonthCompleteness(
      month: DateTime.utc(2027, 4, 1),
    );
    expect(month.state, AnalysisQueryState.ready);
    expect(month.value?.state, PeriodCompleteness.preRecord);
    expect(month.value?.firstRecordMonth, isNull);

    final week = queries.readWeekCompleteness(
      containingDay: DateTime.utc(2027, 4, 7),
    );
    expect(week.state, AnalysisQueryState.ready);
    expect(week.value?.state, PeriodCompleteness.preRecord);
  });

  test('firstRecordMonthReadFindsEarliestAcrossKinds', () async {
    final setup = _setup();
    final ledger = setup.ledger;
    final queries = setup.queries;

    ledger.setOpeningBalance(
      Decimal.parse('100'),
      _accountID,
      date: DateTime.utc(2027, 2, 10),
    );
    _addExpense(
      ledger,
      'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      '-13.50',
      date: DateTime.utc(2027, 1, 20),
      includeInAnalysis: false,
    );
    _addExpense(
      ledger,
      'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
      '-7.00',
      date: DateTime.utc(2027, 3, 5),
    );

    final first = queries.readFirstRecordMonth();
    expect(first.state, AnalysisQueryState.ready);
    expect(first.value, DateTime.utc(2027, 1, 1));
    expect(first.sourceRevision, ledger.revision);
  });

  test('monthCompletenessNormalizesInputsAndClassifies', () async {
    final setup = _setup();
    final ledger = setup.ledger;
    final queries = setup.queries;

    _addExpense(
      ledger,
      'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      '-13.50',
      date: DateTime.utc(2027, 1, 20),
    );

    final april = queries.readMonthCompleteness(
      month: DateTime(2027, 4, 15, 10, 30),
    );
    expect(april.state, AnalysisQueryState.ready);
    expect(
      april.value?.window,
      DateRange(DateTime.utc(2027, 4, 1), DateTime.utc(2027, 5, 1)),
    );
    expect(april.value?.state, PeriodCompleteness.complete);
    expect(april.value?.firstRecordMonth, DateTime.utc(2027, 1, 1));
    expect(april.value?.today, DateTime.utc(2027, 5, 15));
    expect(april.sourceRevision, ledger.revision);

    expect(
      queries
          .readMonthCompleteness(month: DateTime.utc(2027, 5, 2))
          .value
          ?.state,
      PeriodCompleteness.incomplete,
    );
    expect(
      queries
          .readMonthCompleteness(month: DateTime.utc(2026, 12, 25))
          .value
          ?.state,
      PeriodCompleteness.preRecord,
    );
  });

  test('weekCompletenessNormalizesToMondayAndClassifies', () async {
    final setup = _setup();
    final ledger = setup.ledger;
    final queries = setup.queries;

    _addExpense(
      ledger,
      'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      '-13.50',
      date: DateTime.utc(2027, 1, 20),
    );

    final past = queries.readWeekCompleteness(
      containingDay: DateTime(2027, 5, 5, 15, 30),
    );
    expect(past.state, AnalysisQueryState.ready);
    expect(
      past.value?.window,
      DateRange(DateTime.utc(2027, 5, 3), DateTime.utc(2027, 5, 10)),
    );
    expect(past.value?.state, PeriodCompleteness.complete);
    expect(past.sourceRevision, ledger.revision);

    expect(
      queries
          .readWeekCompleteness(containingDay: DateTime.utc(2027, 5, 12))
          .value
          ?.state,
      PeriodCompleteness.incomplete,
    );
    expect(
      queries
          .readWeekCompleteness(containingDay: DateTime.utc(2027, 1, 1))
          .value
          ?.state,
      PeriodCompleteness.preRecord,
    );
    expect(
      queries
          .readWeekCompleteness(containingDay: DateTime.utc(2027, 1, 1))
          .value
          ?.window,
      DateRange(DateTime.utc(2026, 12, 28), DateTime.utc(2027, 1, 4)),
    );
  });

  test('weekEndingExactlyTodayIsComplete', () async {
    final setup = _setup(today: DateTime.utc(2027, 5, 10));
    final queries = setup.queries;

    _addExpense(
      setup.ledger,
      'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      '-13.50',
      date: DateTime.utc(2027, 1, 20),
    );

    expect(
      queries
          .readWeekCompleteness(containingDay: DateTime.utc(2027, 5, 5))
          .value
          ?.state,
      PeriodCompleteness.complete,
    );
  });

  test('deletingEarliestEntryMovesTheBoundary', () async {
    final setup = _setup();
    final ledger = setup.ledger;
    final queries = setup.queries;

    _addExpense(
      ledger,
      'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      '-13.50',
      date: DateTime.utc(2027, 1, 4),
    );
    _addExpense(
      ledger,
      'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
      '-7.00',
      date: DateTime.utc(2027, 4, 1),
    );
    expect(queries.readFirstRecordMonth().value, DateTime.utc(2027, 1, 1));

    ledger.deleteEntry('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa');

    expect(queries.readFirstRecordMonth().value, DateTime.utc(2027, 4, 1));
    expect(queries.readFirstRecordMonth().sourceRevision, ledger.revision);
    expect(
      queries
          .readMonthCompleteness(month: DateTime.utc(2027, 1, 15))
          .value
          ?.state,
      PeriodCompleteness.preRecord,
    );
  });

  test('equivalentMonthInputsShareOneMemoEntry', () async {
    final setup = _setup();
    final queries = setup.queries;
    final runner = setup.runner;

    runner.pending.last.complete(const []);
    await pumpEventQueue();

    final first = queries.readMonthCompleteness(
      month: DateTime.utc(2027, 4, 1),
    );
    final second = queries.readMonthCompleteness(
      month: DateTime(2027, 4, 15, 10, 30),
    );
    expect(identical(second, first), isTrue);

    final otherMonth = queries.readMonthCompleteness(
      month: DateTime.utc(2027, 5, 1),
    );
    expect(identical(otherMonth, first), isFalse);

    final firstWeek = queries.readWeekCompleteness(
      containingDay: DateTime.utc(2027, 5, 5),
    );
    expect(
      identical(
        queries.readWeekCompleteness(
          containingDay: DateTime(2027, 5, 6, 23, 45),
        ),
        firstWeek,
      ),
      isTrue,
    );
  });

  test('dayRolloverRecomputesCompletenessWithoutRunnerWork', () async {
    final setup = _setup(today: DateTime.utc(2027, 4, 30));
    final ledger = setup.ledger;
    final queries = setup.queries;
    final runner = setup.runner;
    var notifications = 0;
    queries.addListener(() => notifications++);

    runner.pending.last.complete(const []);
    await pumpEventQueue();
    expect(notifications, 1);

    _addExpense(
      ledger,
      'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      '-13.50',
      date: DateTime.utc(2027, 4, 5),
    );

    expect(
      queries
          .readMonthCompleteness(month: DateTime.utc(2027, 4, 1))
          .value
          ?.state,
      PeriodCompleteness.incomplete,
    );

    queries.setToday(DateTime.utc(2027, 5, 1));
    expect(runner.calls, 2);
    expect(notifications, 3);

    expect(
      queries
          .readMonthCompleteness(month: DateTime.utc(2027, 4, 1))
          .value
          ?.state,
      PeriodCompleteness.complete,
    );

    queries.setToday(DateTime(2027, 5, 1, 18, 45));
    expect(notifications, 3);
  });

  test('completenessStaysReadyWhileMixedReadsFail', () async {
    final setup = _setup();
    final ledger = setup.ledger;
    final queries = setup.queries;
    final runner = setup.runner;

    runner.pending.last.complete(const []);
    await pumpEventQueue();

    _addExpense(
      ledger,
      'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      '-13.50',
      date: DateTime.utc(2027, 1, 4),
    );
    runner.pending.last.completeError(StateError('boom'));
    await pumpEventQueue();

    final period = queries.readPeriod(
      window: DateRange(DateTime.utc(2027, 1, 1), DateTime.utc(2027, 2, 1)),
    );
    expect(period.state, AnalysisQueryState.failed);

    final month = queries.readMonthCompleteness(
      month: DateTime.utc(2027, 1, 15),
    );
    expect(month.state, AnalysisQueryState.ready);
    expect(month.sourceRevision, ledger.revision);
    expect(month.value?.state, PeriodCompleteness.complete);
  });

  test('deletingEarliestEntryDuringPendingRefreshSplitsCompletenessFromTotalsUntilAcceptance', () async {
    final setup = _setup();
    final ledger = setup.ledger;
    final queries = setup.queries;
    final runner = setup.runner;

    runner.pending.last.complete(const []);
    await pumpEventQueue();

    _addExpense(
      ledger,
      'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      '-13.50',
      date: DateTime.utc(2027, 1, 4),
    );
    runner.pending.last.complete(Accounting.analysisItems(ledger.state));
    await pumpEventQueue();
    _addExpense(
      ledger,
      'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
      '-7.00',
      date: DateTime.utc(2027, 4, 1),
    );
    runner.pending.last.complete(Accounting.analysisItems(ledger.state));
    await pumpEventQueue();

    final january = DateRange(
      DateTime.utc(2027, 1, 1),
      DateTime.utc(2027, 2, 1),
    );
    final revision = ledger.revision;
    final period = queries.readPeriod(window: january);
    final weeks = queries.readWeeks(window: january);
    final month = queries.readMonthCompleteness(
      month: DateTime.utc(2027, 1, 15),
    );
    final week = queries.readWeekCompleteness(
      containingDay: DateTime.utc(2027, 1, 4),
    );
    for (final read in [period, weeks, month, week]) {
      expect(read.state, AnalysisQueryState.ready);
      expect(read.sourceRevision, revision);
    }
    expect(period.value?.spent, Decimal.parse('13.50'));
    expect(month.value?.state, PeriodCompleteness.complete);
    expect(month.value?.window, january);
    expect(
      week.value?.window,
      DateRange(DateTime.utc(2027, 1, 4), DateTime.utc(2027, 1, 11)),
    );
    expect(week.value?.state, PeriodCompleteness.complete);
    expect(queries.readFirstRecordMonth().value, DateTime.utc(2027, 1, 1));

    ledger.deleteEntry('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa');

    final freshMonth = queries.readMonthCompleteness(
      month: DateTime.utc(2027, 1, 15),
    );
    expect(freshMonth.state, AnalysisQueryState.ready);
    expect(freshMonth.sourceRevision, ledger.revision);
    expect(freshMonth.value?.state, PeriodCompleteness.preRecord);
    expect(freshMonth.value?.firstRecordMonth, DateTime.utc(2027, 4, 1));
    final freshWeek = queries.readWeekCompleteness(
      containingDay: DateTime.utc(2027, 1, 4),
    );
    expect(freshWeek.state, AnalysisQueryState.ready);
    expect(freshWeek.sourceRevision, ledger.revision);
    expect(freshWeek.value?.state, PeriodCompleteness.preRecord);

    final retainedPeriod = queries.readPeriod(window: january);
    expect(retainedPeriod.state, AnalysisQueryState.loading);
    expect(retainedPeriod.sourceRevision, revision);
    expect(retainedPeriod.value?.spent, Decimal.parse('13.50'));
    final retainedWeeks = queries.readWeeks(window: january);
    expect(retainedWeeks.state, AnalysisQueryState.loading);
    expect(retainedWeeks.sourceRevision, revision);

    runner.pending.last.complete(Accounting.analysisItems(ledger.state));
    await pumpEventQueue();

    final acceptedPeriod = queries.readPeriod(window: january);
    final acceptedMonth = queries.readMonthCompleteness(
      month: DateTime.utc(2027, 1, 15),
    );
    final acceptedWeeks = queries.readWeeks(window: january);
    expect(acceptedPeriod.sourceRevision, ledger.revision);
    expect(acceptedMonth.sourceRevision, ledger.revision);
    expect(acceptedWeeks.sourceRevision, ledger.revision);
    expect(acceptedPeriod.value?.spent, Decimal.zero);
    expect(acceptedMonth.value?.state, PeriodCompleteness.preRecord);
    expect(
      acceptedWeeks.value!.fold(
        Decimal.zero,
        (sum, total) => sum + total.spent,
      ),
      Decimal.zero,
    );
  });
}
