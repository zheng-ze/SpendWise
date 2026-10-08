import 'dart:async';

import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ledger/analysis/analysis_query_result.dart';
import 'package:spendwise/ledger/analysis_cache.dart';
import 'package:spendwise/ledger/analysis_queries.dart';
import 'package:spendwise/ledger/ledger.dart';

const _checkingID = '11111111-1111-1111-1111-111111111111';
const _savingsID = '22222222-2222-2222-2222-222222222222';
const _foodID = '33333333-3333-3333-3333-333333333333';

final _today = DateTime.utc(2027, 4, 7);

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
    Account(id: _checkingID, name: 'Checking', type: AccountType.checking),
  );
  ledger.addAccount(
    Account(id: _savingsID, name: 'Savings', type: AccountType.savings),
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
    today: today ?? _today,
  );
  addTearDown(() async {
    queries.dispose();
    await cache.dispose();
  });
  return (ledger: ledger, cache: cache, queries: queries, runner: runner);
}

void main() {
  test('duplicateScopeIDsShareOneMemoIdentity', () async {
    const holderID = 'ab12cd34-ef56-ab78-cd90-ef1234567890';
    final ledger = Ledger();
    ledger.addAccount(
      Account(id: holderID, name: 'Checking', type: AccountType.checking),
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
      today: _today,
    );
    addTearDown(() async {
      queries.dispose();
      await cache.dispose();
    });

    runner.pending.last.complete(const []);
    await pumpEventQueue();

    final window = DateRange(
      DateTime.utc(2027, 4, 1),
      DateTime.utc(2027, 5, 1),
    );
    final first = queries.readPeriod(window: window, sourceIDs: {holderID});
    expect(first.state, AnalysisQueryState.ready);
    final duplicate = queries.readPeriod(
      window: window,
      sourceIDs: {holderID, holderID.toUpperCase()},
    );
    expect(identical(duplicate, first), isTrue);

    ledger.addEntry(
      Entry(
        id: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
        amount: Decimal.parse('-13.50'),
        name: 'lunch',
        sourceID: holderID,
        categoryID: _foodID,
        date: _today,
      ),
    );

    final retained = queries.readPeriod(
      window: window,
      sourceIDs: {holderID, holderID.toUpperCase()},
    );
    expect(retained.value, first.value);
    expect(retained.sourceRevision, first.sourceRevision);
    expect(retained.state, AnalysisQueryState.loading);
  });

  test('equivalentRangesAndNormalizedScopesReuseResults', () async {
    final setup = _setup();
    final queries = setup.queries;
    final runner = setup.runner;

    runner.pending.last.complete(const []);
    await pumpEventQueue();

    final window = DateRange(
      DateTime.utc(2027, 4, 1),
      DateTime.utc(2027, 5, 1),
    );
    final first = queries.readPeriod(
      window: window,
      sourceIDs: {_savingsID.toUpperCase(), _checkingID},
    );
    final second = queries.readPeriod(
      window: DateRange(DateTime.utc(2027, 4, 1), DateTime.utc(2027, 5, 1)),
      sourceIDs: {_checkingID, _savingsID},
    );
    expect(identical(second, first), isTrue);

    final todayFirst = queries.readToday();
    expect(identical(queries.readToday(), todayFirst), isTrue);

    final otherWindow = queries.readPeriod(
      window: DateRange(DateTime.utc(2027, 4, 1), DateTime.utc(2027, 6, 1)),
      sourceIDs: {_checkingID, _savingsID},
    );
    expect(identical(otherWindow, first), isFalse);

    final otherScope = queries.readPeriod(
      window: window,
      sourceIDs: {_checkingID},
    );
    expect(identical(otherScope, first), isFalse);
  });

  test('callerSetMutationCannotAlterAStoredKey', () async {
    final setup = _setup();
    final queries = setup.queries;
    final runner = setup.runner;

    runner.pending.last.complete(const []);
    await pumpEventQueue();

    final window = DateRange(
      DateTime.utc(2027, 4, 1),
      DateTime.utc(2027, 5, 1),
    );
    final scope = {_checkingID, _savingsID};
    final first = queries.readPeriod(window: window, sourceIDs: scope);

    scope.remove(_savingsID);
    scope.add('99999999-9999-9999-9999-999999999999');

    final second = queries.readPeriod(
      window: window,
      sourceIDs: {_checkingID, _savingsID},
    );
    expect(identical(second, first), isTrue);
  });

  test('dayRolloverNeedsNoRunnerCallAndNotifiesOnceWhenSettled', () async {
    final setup = _setup();
    final queries = setup.queries;
    final runner = setup.runner;
    var notifications = 0;
    queries.addListener(() => notifications++);

    runner.pending.last.complete(const []);
    await pumpEventQueue();
    expect(notifications, 1);

    queries.setToday(DateTime.utc(2027, 4, 8));
    expect(runner.calls, 1);
    expect(notifications, 2);

    final today = queries.readToday();
    expect(today.state, AnalysisQueryState.ready);
    expect(today.value?.day, DateTime.utc(2027, 4, 8));

    final sameDay = DateTime(2027, 4, 8, 15, 30);
    queries.setToday(sameDay);
    expect(notifications, 2);
  });

  test('mismatchRetainsLatestValueAndNewParametersStayNull', () async {
    final setup = _setup();
    final ledger = setup.ledger;
    final queries = setup.queries;
    final runner = setup.runner;

    runner.pending.last.complete(const []);
    await pumpEventQueue();

    final window = DateRange(
      DateTime.utc(2027, 4, 1),
      DateTime.utc(2027, 5, 1),
    );
    final settled = queries.readPeriod(window: window);
    expect(settled.state, AnalysisQueryState.ready);

    ledger.addEntry(
      Entry(
        id: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
        amount: Decimal.parse('-13.50'),
        name: 'lunch',
        sourceID: _checkingID,
        categoryID: _foodID,
        date: _today,
      ),
    );

    final retained = queries.readPeriod(window: window);
    expect(retained.value, settled.value);
    expect(retained.sourceRevision, settled.sourceRevision);
    expect(retained.state, AnalysisQueryState.loading);

    final fresh = queries.readPeriod(
      window: DateRange(DateTime.utc(2027, 4, 1), DateTime.utc(2027, 6, 1)),
    );
    expect(fresh.value, isNull);
    expect(fresh.sourceRevision, isNull);
    expect(fresh.state, AnalysisQueryState.loading);

    runner.pending.last.complete(Accounting.analysisItems(ledger.state));
    await pumpEventQueue();

    final updated = queries.readPeriod(window: window);
    expect(updated.state, AnalysisQueryState.ready);
    expect(updated.sourceRevision, ledger.revision);
    expect(updated.value?.spent, Decimal.parse('13.50'));
  });

  test('dayChangeWhilePendingRetainsPreviousValuesUntilAcceptance', () async {
    final setup = _setup();
    final ledger = setup.ledger;
    final queries = setup.queries;
    final runner = setup.runner;
    var notifications = 0;
    queries.addListener(() => notifications++);

    runner.pending.last.complete(const []);
    await pumpEventQueue();
    expect(notifications, 1);

    final window = DateRange(
      DateTime.utc(2027, 4, 1),
      DateTime.utc(2027, 5, 1),
    );
    final settledToday = queries.readToday();
    final settledPeriod = queries.readPeriod(window: window);
    expect(settledToday.state, AnalysisQueryState.ready);
    expect(settledPeriod.state, AnalysisQueryState.ready);

    ledger.addEntry(
      Entry(
        id: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
        amount: Decimal.parse('-13.50'),
        name: 'lunch',
        sourceID: _checkingID,
        categoryID: _foodID,
        date: DateTime.utc(2027, 4, 8),
      ),
    );

    queries.setToday(DateTime.utc(2027, 4, 8));
    expect(runner.calls, 2);

    final retainedToday = queries.readToday();
    expect(retainedToday.value, settledToday.value);
    expect(retainedToday.sourceRevision, settledToday.sourceRevision);
    expect(retainedToday.state, AnalysisQueryState.loading);
    final retainedPeriod = queries.readPeriod(window: window);
    expect(retainedPeriod.value, settledPeriod.value);
    expect(retainedPeriod.sourceRevision, settledPeriod.sourceRevision);
    expect(retainedPeriod.state, AnalysisQueryState.loading);

    runner.pending.last.complete(Accounting.analysisItems(ledger.state));
    await pumpEventQueue();

    expect(notifications, 2);
    final updatedToday = queries.readToday();
    expect(updatedToday.state, AnalysisQueryState.ready);
    expect(updatedToday.value?.day, DateTime.utc(2027, 4, 8));
    expect(updatedToday.value?.spent, Decimal.parse('13.50'));
    final updatedPeriod = queries.readPeriod(window: window);
    expect(updatedPeriod.state, AnalysisQueryState.ready);
    expect(updatedPeriod.value?.spent, Decimal.parse('13.50'));
  });

  test('calculationFailureFailsOnlyItsQueryAndChangedInputRecovers', () async {
    final state = LedgerState();
    state.addBudget(null, Decimal.parse('300'), now: DateTime.utc(2027, 4, 2));
    final stored = state.budgets.values.single;
    final invalid = Budget(
      id: stored.id,
      categoryID: stored.categoryID,
      limitEvents: const [],
      createdAtMonth: stored.createdAtMonth,
    );
    final invalidState = LedgerState(
      moneySources: state.moneySources,
      budgets: {invalid.id: invalid},
    );
    final ledger = Ledger(state: invalidState);
    final cache = AnalysisCache(runner: syncComputeRunner)
      ..start(ledger.bus, sourceRevision: () => ledger.revision);
    final queries = AnalysisQueries(
      ledger: ledger,
      cache: cache,
      today: _today,
    );
    addTearDown(() async {
      queries.dispose();
      await cache.dispose();
    });
    for (
      var i = 0;
      i < 50 && cache.itemsSourceRevision != ledger.revision;
      i++
    ) {
      await pumpEventQueue();
    }

    final today = queries.readToday();
    expect(today.state, AnalysisQueryState.failed);
    expect(today.value, isNull);

    final period = queries.readPeriod(
      window: DateRange(DateTime.utc(2027, 4, 1), DateTime.utc(2027, 5, 1)),
    );
    expect(period.state, AnalysisQueryState.ready);

    await queries.retry();
    expect(queries.readToday().state, AnalysisQueryState.failed);

    ledger.deleteBudget(invalid.id);
    for (
      var i = 0;
      i < 50 && cache.itemsSourceRevision != ledger.revision;
      i++
    ) {
      await pumpEventQueue();
    }

    final recovered = queries.readToday();
    expect(recovered.state, AnalysisQueryState.ready);
    expect(recovered.value?.dailyGuide, isNull);
  });
}
