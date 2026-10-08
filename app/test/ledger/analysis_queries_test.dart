import 'dart:async';

import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ledger/analysis/analysis_query_result.dart';
import 'package:spendwise/ledger/analysis_cache.dart';
import 'package:spendwise/ledger/analysis_queries.dart';
import 'package:spendwise/ledger/ledger.dart';

const _accountID = '11111111-1111-1111-1111-111111111111';
const _foodID = '33333333-3333-3333-3333-333333333333';

final _today = DateTime.utc(2027, 4, 7);

DateRange _april() =>
    DateRange(DateTime.utc(2027, 4, 1), DateTime.utc(2027, 5, 1));

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
_setup() {
  final ledger = Ledger();
  final account = Account(
    id: _accountID,
    name: 'Checking',
    type: AccountType.checking,
  );
  ledger.addAccount(account);
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
  final queries = AnalysisQueries(ledger: ledger, cache: cache, today: _today);
  addTearDown(() async {
    queries.dispose();
    await cache.dispose();
  });
  return (ledger: ledger, cache: cache, queries: queries, runner: runner);
}

void _addExpense(Ledger ledger, String id, String amount, {DateTime? date}) {
  ledger.addEntry(
    Entry(
      id: id,
      amount: Decimal.parse(amount),
      name: 'lunch',
      sourceID: _accountID,
      categoryID: _foodID,
      date: date ?? _today,
    ),
  );
}

void main() {
  test(
    'readsStartLoadingThenRetainWhilePendingAndPublishOnceAtEquality',
    () async {
      final setup = _setup();
      final ledger = setup.ledger;
      final queries = setup.queries;
      final runner = setup.runner;
      var notifications = 0;
      queries.addListener(() => notifications++);

      expect(queries.readToday().state, AnalysisQueryState.loading);
      expect(queries.readToday().value, isNull);
      expect(queries.readToday().sourceRevision, isNull);

      runner.pending.last.complete(const []);
      await pumpEventQueue();
      expect(notifications, 1);

      final before = queries.readPeriod(window: _april());
      expect(before.state, AnalysisQueryState.ready);
      expect(before.sourceRevision, ledger.revision);
      expect(before.value?.spent, Decimal.zero);

      _addExpense(ledger, 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '-13.50');
      expect(runner.calls, 2);

      final pending = queries.readPeriod(window: _april());
      expect(pending.value?.spent, Decimal.zero);
      expect(pending.sourceRevision, before.sourceRevision);
      expect(pending.state, AnalysisQueryState.loading);
      expect(notifications, 2);

      runner.pending.last.complete(Accounting.analysisItems(ledger.state));
      await pumpEventQueue();

      expect(notifications, 3);
      final after = queries.readPeriod(window: _april());
      expect(after.state, AnalysisQueryState.ready);
      expect(after.sourceRevision, ledger.revision);
      expect(after.value?.spent, Decimal.parse('13.50'));
      expect(queries.readToday().value?.spent, Decimal.parse('13.50'));
    },
  );

  test('mutationWithoutViewModelsStillRefreshesTodayAndPeriod', () async {
    final setup = _setup();
    final ledger = setup.ledger;
    final cache = setup.cache;
    final queries = setup.queries;
    final runner = setup.runner;

    runner.pending.last.complete(const []);
    await pumpEventQueue();
    expect(cache.itemsSourceRevision, ledger.revision);

    _addExpense(ledger, 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '-13.50');

    expect(runner.calls, 2);
    runner.pending.last.complete(Accounting.analysisItems(ledger.state));
    await pumpEventQueue();

    expect(queries.readToday().value?.spent, Decimal.parse('13.50'));
    expect(
      queries.readPeriod(window: _april()).value?.spent,
      Decimal.parse('13.50'),
    );
  });

  test(
    'failingRunnerKeepsLastResultAndRecoversOnRetryAndNotification',
    () async {
      final setup = _setup();
      final ledger = setup.ledger;
      final queries = setup.queries;
      final runner = setup.runner;
      var notifications = 0;
      queries.addListener(() => notifications++);

      runner.pending.last.complete(const []);
      await pumpEventQueue();
      expect(notifications, 1);
      expect(queries.readPeriod(window: _april()).value?.spent, Decimal.zero);
      expect(queries.readToday().value?.spent, Decimal.zero);

      _addExpense(ledger, 'cccccccc-cccc-cccc-cccc-cccccccccccc', '-13.50');
      runner.pending.last.completeError(StateError('boom'));
      await pumpEventQueue();

      expect(notifications, 3);
      final failed = queries.readPeriod(window: _april());
      expect(failed.state, AnalysisQueryState.failed);
      expect(failed.value?.spent, Decimal.zero);
      expect(failed.sourceRevision, 2);

      expect(
        queries.readPeriod(window: _april()).state,
        AnalysisQueryState.failed,
      );
      expect(queries.readToday().state, AnalysisQueryState.failed);
      await pumpEventQueue();
      expect(runner.calls, 2);
      expect(notifications, 3);

      final retrying = queries.retry();
      expect(runner.calls, 3);
      runner.pending.last.complete(Accounting.analysisItems(ledger.state));
      await retrying;
      await pumpEventQueue();

      expect(notifications, 4);
      final recovered = queries.readPeriod(window: _april());
      expect(recovered.state, AnalysisQueryState.ready);
      expect(recovered.value?.spent, Decimal.parse('13.50'));

      _addExpense(ledger, 'dddddddd-dddd-dddd-dddd-dddddddddddd', '-7.00');
      runner.pending.last.completeError(StateError('again'));
      await pumpEventQueue();
      expect(
        queries.readPeriod(window: _april()).state,
        AnalysisQueryState.failed,
      );

      _addExpense(ledger, 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', '-1.00');
      expect(runner.calls, 5);
      runner.pending.last.complete(Accounting.analysisItems(ledger.state));
      await pumpEventQueue();

      final settled = queries.readPeriod(window: _april());
      expect(settled.state, AnalysisQueryState.ready);
      expect(settled.value?.spent, Decimal.parse('21.50'));
    },
  );

  test('failedRefreshStartsNoRecursiveWork', () async {
    final setup = _setup();
    final queries = setup.queries;
    final runner = setup.runner;
    var notifications = 0;
    queries.addListener(() => notifications++);

    runner.pending.last.complete(const []);
    await pumpEventQueue();

    _addExpense(setup.ledger, 'ffffffff-ffff-ffff-ffff-ffffffffffff', '-13.50');
    runner.pending.last.completeError(StateError('boom'));
    await pumpEventQueue();
    await pumpEventQueue();

    expect(runner.calls, 2);
    expect(notifications, 3);

    queries.readToday();
    queries.readPeriod(window: _april());
    await pumpEventQueue();

    expect(runner.calls, 2);
    expect(notifications, 3);
  });

  test('olderFailureAfterNewerFailureKeepsTheNewerFailure', () async {
    final setup = _setup();
    final ledger = setup.ledger;
    final queries = setup.queries;
    final runner = setup.runner;
    var notifications = 0;
    queries.addListener(() => notifications++);

    runner.pending[0].complete(const []);
    await pumpEventQueue();
    expect(notifications, 1);
    final settledToday = queries.readToday();
    final settledPeriod = queries.readPeriod(window: _april());
    expect(settledToday.state, AnalysisQueryState.ready);
    expect(settledPeriod.state, AnalysisQueryState.ready);

    _addExpense(ledger, 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '-13.50');
    _addExpense(ledger, 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '-7.00');
    expect(runner.calls, 3);

    runner.pending[2].completeError(StateError('newer'));
    await pumpEventQueue();

    expect(notifications, 4);
    final failedToday = queries.readToday();
    expect(failedToday.state, AnalysisQueryState.failed);
    expect(failedToday.value, settledToday.value);
    expect(failedToday.sourceRevision, settledToday.sourceRevision);
    final failedPeriod = queries.readPeriod(window: _april());
    expect(failedPeriod.state, AnalysisQueryState.failed);
    expect(failedPeriod.value, settledPeriod.value);
    expect(failedPeriod.sourceRevision, settledPeriod.sourceRevision);

    runner.pending[1].completeError(StateError('older'));
    await pumpEventQueue();

    expect(notifications, 4);
    expect(queries.readToday().state, AnalysisQueryState.failed);
    expect(
      queries.readPeriod(window: _april()).state,
      AnalysisQueryState.failed,
    );

    final retrying = queries.retry();
    expect(runner.calls, 4);
    runner.pending[3].complete(Accounting.analysisItems(ledger.state));
    await retrying;
    await pumpEventQueue();

    expect(notifications, 5);
    expect(
      queries.readPeriod(window: _april()).value?.spent,
      Decimal.parse('20.50'),
    );
  });

  test('bothFailingBeforeDrainingPublishesTheFailureOnce', () async {
    final setup = _setup();
    final ledger = setup.ledger;
    final queries = setup.queries;
    final runner = setup.runner;
    var notifications = 0;
    queries.addListener(() => notifications++);

    runner.pending[0].complete(const []);
    await pumpEventQueue();
    expect(notifications, 1);
    final settledPeriod = queries.readPeriod(window: _april());

    _addExpense(ledger, 'cccccccc-cccc-cccc-cccc-cccccccccccc', '-13.50');
    _addExpense(ledger, 'dddddddd-dddd-dddd-dddd-dddddddddddd', '-7.00');

    runner.pending[2].completeError(StateError('newer'));
    runner.pending[1].completeError(StateError('older'));
    await pumpEventQueue();

    expect(notifications, 4);
    final failed = queries.readPeriod(window: _april());
    expect(failed.state, AnalysisQueryState.failed);
    expect(failed.value, settledPeriod.value);
    expect(failed.sourceRevision, settledPeriod.sourceRevision);
    expect(queries.readToday().state, AnalysisQueryState.failed);

    final retrying = queries.retry();
    runner.pending[3].complete(Accounting.analysisItems(ledger.state));
    await retrying;
    await pumpEventQueue();

    expect(
      queries.readPeriod(window: _april()).state,
      AnalysisQueryState.ready,
    );
  });

  test('initialFailureHasNullValueAndRecoversOnRetry', () async {
    final setup = _setup();
    final ledger = setup.ledger;
    final queries = setup.queries;
    final runner = setup.runner;
    var notifications = 0;
    queries.addListener(() => notifications++);

    runner.pending.last.completeError(StateError('early'));
    await pumpEventQueue();

    expect(notifications, 1);
    final failed = queries.readToday();
    expect(failed.state, AnalysisQueryState.failed);
    expect(failed.value, isNull);
    expect(failed.sourceRevision, isNull);

    final retrying = queries.retry();
    runner.pending.last.complete(const []);
    await retrying;
    await pumpEventQueue();

    final ready = queries.readToday();
    expect(ready.state, AnalysisQueryState.ready);
    expect(ready.value?.spent, Decimal.zero);
    expect(ready.sourceRevision, ledger.revision);
  });

  test(
    'failedRefreshThenDayChangeNotifiesOnceAndMovesLedgerOnlyReads',
    () async {
      final setup = _setup();
      final ledger = setup.ledger;
      final queries = setup.queries;
      final runner = setup.runner;
      var notifications = 0;
      queries.addListener(() => notifications++);

      runner.pending.last.complete(const []);
      await pumpEventQueue();
      expect(notifications, 1);
      final settledToday = queries.readToday();
      expect(settledToday.state, AnalysisQueryState.ready);

      _addExpense(
        ledger,
        'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
        '-13.50',
        date: DateTime.utc(2027, 4, 8),
      );
      expect(notifications, 2);

      runner.pending.last.completeError(StateError('boom'));
      await pumpEventQueue();
      expect(notifications, 3);

      final failedToday = queries.readToday();
      expect(failedToday.state, AnalysisQueryState.failed);
      expect(failedToday.value, settledToday.value);
      expect(failedToday.sourceRevision, settledToday.sourceRevision);

      final window = DateRange(
        DateTime.utc(2027, 4, 7),
        DateTime.utc(2027, 4, 9),
      );
      final upcomingBefore = queries.readUpcoming(window: window);
      expect(upcomingBefore.state, AnalysisQueryState.ready);
      expect(upcomingBefore.value, hasLength(1));

      queries.setToday(DateTime.utc(2027, 4, 8));
      expect(notifications, 4);

      final upcomingAfter = queries.readUpcoming(window: window);
      expect(upcomingAfter.state, AnalysisQueryState.ready);
      expect(upcomingAfter.value, isEmpty);
      expect(
        queries.readRecent().value!.single.entry.date,
        DateTime.utc(2027, 4, 8),
      );

      final retainedToday = queries.readToday();
      expect(retainedToday.state, AnalysisQueryState.failed);
      expect(retainedToday.value, settledToday.value);
      expect(retainedToday.sourceRevision, settledToday.sourceRevision);
      expect(notifications, 4);
    },
  );

  test('pendingRefreshNotifiesLedgerChangeBeforeCacheAcceptance', () async {
    final setup = _setup();
    final ledger = setup.ledger;
    final queries = setup.queries;
    final runner = setup.runner;
    var notifications = 0;
    queries.addListener(() => notifications++);

    runner.pending.last.complete(const []);
    await pumpEventQueue();
    expect(notifications, 1);
    final settled = queries.readPeriod(window: _april());
    expect(settled.state, AnalysisQueryState.ready);

    _addExpense(ledger, 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '-13.50');
    expect(notifications, 2);

    final recent = queries.readRecent();
    expect(recent.state, AnalysisQueryState.ready);
    expect(recent.value, hasLength(1));

    final pending = queries.readPeriod(window: _april());
    expect(pending.state, AnalysisQueryState.loading);
    expect(pending.value, settled.value);
    expect(pending.sourceRevision, settled.sourceRevision);

    runner.pending.last.complete(Accounting.analysisItems(ledger.state));
    await pumpEventQueue();
    expect(notifications, 3);

    final updated = queries.readPeriod(window: _april());
    expect(updated.state, AnalysisQueryState.ready);
    expect(updated.value?.spent, Decimal.parse('13.50'));
  });
}
