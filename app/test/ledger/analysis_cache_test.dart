import 'dart:async';

import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ledger/analysis_cache.dart';
import 'package:spendwise/ledger/event_bus.dart';

Account _account({String name = 'acc'}) =>
    Account(name: name, type: AccountType.savings);

// One expense, so a real compute over it yields exactly one item.
LedgerState _stateWithExpense(String amount) {
  final state = LedgerState();
  final account = _account();
  state.addAccount(account);
  state.addEntry(
    Entry(amount: Decimal.parse(amount), name: 'e', sourceID: account.id),
  );
  return state;
}

// Hands the test the completer for each compute so the interleaving is fixed
// by the test rather than by scheduling.
class _ManualRunner {
  final List<Completer<List<AnalysisItem>>> pending = [];

  Future<List<AnalysisItem>> call(LedgerState state) {
    final completer = Completer<List<AnalysisItem>>();
    pending.add(completer);
    return completer.future;
  }
}

void main() {
  test('initialValuesLeaveTheFirstRefreshWorkToDo', () {
    final cache = AnalysisCache();

    expect(cache.items, isEmpty);
    expect(cache.revision, 0);
    expect(cache.itemsRevision, 0);
  });

  test('busEventBumpsRevision', () {
    final bus = EventBus();
    final cache = AnalysisCache()..start(bus);

    bus.publish([UpsertAccount(_account())]);

    expect(cache.revision, 1);
  });

  test('revisionCountsBatchesNotChanges', () {
    final bus = EventBus();
    final cache = AnalysisCache()..start(bus);

    bus.publish([
      UpsertAccount(_account(name: 'a')),
      UpsertAccount(_account(name: 'b')),
    ]);

    expect(cache.revision, 1);
  });

  test('startIsIdempotent', () {
    final bus = EventBus();
    final cache = AnalysisCache()
      ..start(bus)
      ..start(bus);

    bus.publish([UpsertAccount(_account())]);

    expect(cache.revision, 1);
  });

  test('startOnANewBusMovesTheSubscription', () {
    final first = EventBus();
    final second = EventBus();
    final cache = AnalysisCache()
      ..start(first)
      ..start(second);

    second.publish([UpsertAccount(_account(name: 'b'))]);
    expect(cache.revision, 1);

    first.publish([UpsertAccount(_account(name: 'a'))]);
    expect(cache.revision, 1, reason: 'the discarded bus is no longer counted');
  });

  test('disposeStopsCountingBusEvents', () async {
    final bus = EventBus();
    final cache = AnalysisCache()..start(bus);

    bus.publish([UpsertAccount(_account(name: 'a'))]);
    await cache.dispose();
    bus.publish([UpsertAccount(_account(name: 'b'))]);

    expect(cache.revision, 1);
  });

  test('refreshComputesOnFirstCallWithoutBusEvent', () async {
    final runner = _ManualRunner();
    final cache = AnalysisCache(runner: runner.call);

    cache.refresh(_stateWithExpense('-10'));

    expect(runner.pending, hasLength(1));
  });

  test('refreshIsNoOpWhenRevisionUnchanged', () async {
    final runner = _ManualRunner();
    final cache = AnalysisCache(runner: runner.call);
    final state = _stateWithExpense('-10');

    cache.refresh(state);
    runner.pending.single.complete(const []);
    await pumpEventQueue();

    cache.refresh(state);

    expect(runner.pending, hasLength(1));
  });

  test('refreshRecomputesAfterBusEvent', () async {
    final bus = EventBus();
    final runner = _ManualRunner();
    final cache = AnalysisCache(runner: runner.call)..start(bus);
    final state = _stateWithExpense('-10');

    cache.refresh(state);
    runner.pending.single.complete(const []);
    await pumpEventQueue();

    bus.publish([UpsertAccount(_account())]);
    cache.refresh(state);

    expect(runner.pending, hasLength(2));
  });

  test('staleComputeResultIsDiscarded', () async {
    final bus = EventBus();
    final runner = _ManualRunner();
    final cache = AnalysisCache(runner: runner.call)..start(bus);
    final state = _stateWithExpense('-10');

    final fromA = [
      AnalysisItem(
        bucketID: null,
        amount: Decimal.fromInt(1),
        date: DateTime.utc(2026),
        kind: CategoryKind.expense,
      ),
    ];
    final fromB = [
      AnalysisItem(
        bucketID: null,
        amount: Decimal.fromInt(2),
        date: DateTime.utc(2026),
        kind: CategoryKind.expense,
      ),
    ];

    cache.refresh(state);
    bus.publish([UpsertAccount(_account())]);
    cache.refresh(state);

    expect(runner.pending, hasLength(2));

    // B claimed the newer generation, so A's late result must not land.
    runner.pending[1].complete(fromB);
    await pumpEventQueue();
    runner.pending[0].complete(fromA);
    await pumpEventQueue();

    expect(cache.items, fromB);
  });

  test('itemsRevisionBumpsOnlyOnAcceptedResult', () async {
    final bus = EventBus();
    final runner = _ManualRunner();
    final cache = AnalysisCache(runner: runner.call)..start(bus);
    final state = _stateWithExpense('-10');

    cache.refresh(state);
    bus.publish([UpsertAccount(_account())]);
    cache.refresh(state);

    runner.pending[1].complete(const []);
    await pumpEventQueue();
    final afterAccepted = cache.itemsRevision;

    runner.pending[0].complete(const []);
    await pumpEventQueue();

    expect(afterAccepted, 1);
    expect(cache.itemsRevision, 1);
  });

  test('syncFallbackComputesInline', () async {
    final cache = AnalysisCache(runner: syncComputeRunner);

    cache.refresh(_stateWithExpense('-10'));
    await pumpEventQueue();

    expect(cache.items, hasLength(1));
    expect(cache.items.single.amount, Decimal.fromInt(10));
    expect(cache.itemsRevision, 1);
  });

  test('isolateRunnerRoundTripsDecimalMoney', () async {
    final cache = AnalysisCache();

    cache.refresh(_stateWithExpense('-1234.56'));
    await pumpEventQueue();

    expect(cache.items, hasLength(1));
    expect(cache.items.single.amount, Decimal.parse('1234.56'));
    expect(cache.items.single.kind, CategoryKind.expense);
  });
}
