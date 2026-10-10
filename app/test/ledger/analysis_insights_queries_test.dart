import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/boot/seed_data.dart';
import 'package:spendwise/ledger/analysis/analysis_query_result.dart';
import 'package:spendwise/ledger/analysis/insight_rules.dart';
import 'package:spendwise/ledger/analysis_cache.dart';
import 'package:spendwise/ledger/analysis_queries.dart';
import 'package:spendwise/ledger/ledger.dart';

import 'analysis_test_support.dart';

final _seedToday = DateTime.utc(2026, 10, 3);

class _ThrowingRules extends InsightRules {
  bool throwing = false;

  int calls = 0;

  @override
  bool qualifies(
    Decimal observedTotal,
    Decimal baselineTotal,
    int baselineExpenseCount,
  ) {
    calls++;
    if (throwing) throw StateError('rules failed');
    return super.qualifies(observedTotal, baselineTotal, baselineExpenseCount);
  }
}

final _checkingID = testId(100);
final _foodID = testId(101);
final _queriesToday = DateTime.utc(2027, 5, 15);

int _entryCounter = 0;

void _expense(Ledger ledger, String amount, DateTime date) {
  ledger.addEntry(
    Entry(
      id: testId(1000 + _entryCounter++),
      amount: Decimal.parse('-$amount'),
      name: 'entry',
      sourceID: _checkingID,
      categoryID: _foodID,
      date: date,
    ),
  );
}

void _populateHistory(Ledger ledger) {
  ledger.addAccount(
    Account(id: _checkingID, name: 'Checking', type: AccountType.checking),
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
  for (final date in [
    DateTime.utc(2027, 1, 2),
    DateTime.utc(2027, 2, 2),
    DateTime.utc(2027, 2, 3),
    DateTime.utc(2027, 3, 2),
    DateTime.utc(2027, 3, 3),
    DateTime.utc(2027, 4, 2),
    DateTime.utc(2027, 4, 20),
    DateTime.utc(2027, 4, 21),
    DateTime.utc(2027, 4, 27),
    DateTime.utc(2027, 5, 4),
    DateTime.utc(2027, 5, 5),
  ]) {
    _expense(ledger, '30.00', date);
  }
  _expense(ledger, '200.00', DateTime.utc(2027, 5, 11));
}

void main() {
  test('theSeedAtItsPinnedDayNeedsHistoryForBothReads', () async {
    final state = LedgerState();
    buildSeed(state, today: _seedToday);
    final ledger = Ledger(state: state);
    final cache = AnalysisCache(
      runner: (s) async => Accounting.analysisItems(s),
    )..start(ledger.bus, sourceRevision: () => ledger.revision);
    final queries = AnalysisQueries(
      ledger: ledger,
      cache: cache,
      today: _seedToday,
    );
    addTearDown(() async {
      queries.dispose();
      await cache.dispose();
    });
    await pumpEventQueue();

    final categories = queries.readMatchedDayInsights();
    final week = queries.readWeekSoFar();

    expect(categories.state, AnalysisQueryState.ready);
    expect(categories.value?.state, InsightState.historyNeeded);
    expect(week.state, AnalysisQueryState.ready);
    expect(week.value?.state, InsightState.historyNeeded);
    expect(week.value?.baselineWindows, [
      DateRange(DateTime.utc(2026, 9, 7), DateTime.utc(2026, 9, 13)),
      DateRange(DateTime.utc(2026, 9, 14), DateTime.utc(2026, 9, 20)),
      DateRange(DateTime.utc(2026, 9, 21), DateTime.utc(2026, 9, 27)),
    ]);
    expect(week.value?.baselineExpenseCount, 2);
    expect(week.value?.qualifies, isFalse);
  });

  test('sameKeyReadsReuseResultsAndIdentitiesStayIndependent', () async {
    final setup = setupAnalysis(today: _queriesToday);
    _populateHistory(setup.ledger);
    await settle(setup.runner, setup.ledger);

    final categories = setup.queries.readMatchedDayInsights();
    final week = setup.queries.readWeekSoFar();

    expect(categories.value?.state, InsightState.available);
    expect(week.value?.state, InsightState.available);
    expect(
      identical(setup.queries.readMatchedDayInsights(), categories),
      isTrue,
    );
    expect(identical(setup.queries.readWeekSoFar(), week), isTrue);
    expect(
      categories.value?.changes.single.observedTotal,
      Decimal.parse('260'),
    );
    expect(week.value?.qualifies, isTrue);
  });

  test('aPendingRevisionKeepsPriorValuesUntilItemsCatchUp', () async {
    final setup = setupAnalysis(today: _queriesToday);
    _populateHistory(setup.ledger);
    await settle(setup.runner, setup.ledger);
    final before = setup.queries.readWeekSoFar().value;

    _expense(setup.ledger, '10.00', DateTime.utc(2027, 5, 12));
    final pending = setup.queries.readWeekSoFar();
    expect(pending.state, AnalysisQueryState.loading);
    expect(pending.value, before);

    await settle(setup.runner, setup.ledger);
    final after = setup.queries.readWeekSoFar();
    expect(after.state, AnalysisQueryState.ready);
    expect(after.value?.observedTotal, Decimal.parse('210'));
  });

  test('advancingTodayRecomputesAcrossDayMonthAndMondayBoundaries', () async {
    final setup = setupAnalysis(today: _queriesToday);
    _populateHistory(setup.ledger);
    await settle(setup.runner, setup.ledger);
    final saturday = setup.queries.readWeekSoFar().value;

    setup.queries.setToday(DateTime.utc(2027, 5, 16));
    final sunday = setup.queries.readWeekSoFar().value;
    expect(sunday?.elapsedDayCount, 7);
    expect(sunday, isNot(saturday));

    setup.queries.setToday(DateTime.utc(2027, 5, 17));
    final monday = setup.queries.readWeekSoFar().value;
    expect(monday?.weekStart, DateTime.utc(2027, 5, 17));

    setup.queries.setToday(DateTime.utc(2027, 6, 1));
    final june = setup.queries.readMatchedDayInsights().value;
    expect(june?.selectedMonth, DateTime.utc(2027, 6, 1));
    expect(june?.elapsedDayCount, 1);
  });

  test('aFailingRuleFailsOnlyItsKeyAndRetryRecovers', () async {
    final rules = _ThrowingRules();
    final ledger = Ledger();
    final runner = ManualRunner();
    final cache = AnalysisCache(runner: runner.call)
      ..start(ledger.bus, sourceRevision: () => ledger.revision);
    final queries = AnalysisQueries(
      ledger: ledger,
      cache: cache,
      today: _queriesToday,
      rules: rules,
    );
    addTearDown(() async {
      queries.dispose();
      await cache.dispose();
    });
    _populateHistory(ledger);
    await settle(runner, ledger);
    final success = queries.readMatchedDayInsights();
    expect(success.state, AnalysisQueryState.ready);

    rules.throwing = true;
    _expense(ledger, '1.00', DateTime.utc(2027, 5, 12));
    await settle(runner, ledger);
    final failed = queries.readMatchedDayInsights();
    expect(failed.state, AnalysisQueryState.failed);
    expect(failed.value, success.value);
    final callsAfterFailure = rules.calls;
    expect(queries.readMatchedDayInsights().state, AnalysisQueryState.failed);
    expect(rules.calls, callsAfterFailure);
    expect(
      queries
          .readComparedWithUsual(
            month: _queriesToday,
            kind: CategoryKind.expense,
          )
          .state,
      AnalysisQueryState.ready,
    );

    rules.throwing = false;
    await queries.retry();
    final recovered = queries.readMatchedDayInsights();
    expect(recovered.state, AnalysisQueryState.ready);
    expect(queries.readWeekSoFar().state, AnalysisQueryState.ready);
  });
}
