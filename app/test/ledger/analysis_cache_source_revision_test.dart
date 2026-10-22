import 'dart:async';

import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ledger/analysis_cache.dart';
import 'package:spendwise/ledger/event_bus.dart';
import 'package:spendwise/ledger/ledger.dart';

Account _account({String name = 'acc'}) =>
    Account(name: name, type: AccountType.savings);

TransactionCategory _category({String name = 'food'}) => TransactionCategory(
  name: name,
  kind: CategoryKind.expense,
  colorHex: '#000000',
  includeInAnalysis: true,
  parentID: null,
  symbol: 'tag',
);

LedgerState _fullState() {
  final state = LedgerState();
  final account = _account();
  state.addAccount(account);
  final category = _category();
  state.addCategory(category);
  state.addEntry(
    Entry(
      amount: Decimal.fromInt(-10),
      name: 'lunch',
      sourceID: account.id,
      categoryID: category.id,
    ),
  );
  state.addPlan(
    RecurringPlan(
      template: EntryTemplate(
        amount: Decimal.fromInt(-20),
        name: 'rent',
        sourceID: account.id,
      ),
      frequency: RecurrenceFrequency.monthly,
      anchor: DateTime.utc(2026, 1, 10),
      lastResolvedDate: DateTime.utc(2026, 1, 10),
    ),
  );
  state.addBudget(null, Decimal.fromInt(300), now: DateTime.utc(2026, 4, 7));
  return state;
}

List<AnalysisItem> _items(int amount) => [
  AnalysisItem(
    bucketID: null,
    amount: Decimal.fromInt(amount),
    date: DateTime.utc(2026, 4, 7),
    kind: CategoryKind.expense,
  ),
];

class _ManualRunner {
  final List<Completer<List<AnalysisItem>>> pending = [];
  final List<LedgerState> seen = [];

  Future<List<AnalysisItem>> call(LedgerState state) {
    seen.add(state);
    final completer = Completer<List<AnalysisItem>>();
    pending.add(completer);
    return completer.future;
  }
}

void main() {
  test('sourceStampStartsUncomputedWithNoFailure', () {
    final cache = AnalysisCache();

    expect(cache.itemsSourceRevision, -1);
    expect(cache.lastFailure, isNull);
  });

  test('acceptanceStampsItemsAtomicallyWithOneNotification', () async {
    final runner = _ManualRunner();
    final cache = AnalysisCache(runner: runner.call);
    var notifications = 0;
    var seenItems = -1;
    var seenItemsRevision = -1;
    var seenSourceRevision = -2;
    cache.addListener(() {
      notifications++;
      seenItems = cache.items.single.amount.toBigInt().toInt();
      seenItemsRevision = cache.itemsRevision;
      seenSourceRevision = cache.itemsSourceRevision;
    });

    cache.refresh(_fullState());
    runner.pending.single.complete(_items(10));
    await pumpEventQueue();

    expect(notifications, 1);
    expect(seenItems, 10);
    expect(seenItemsRevision, 1);
    expect(seenSourceRevision, 0);
  });

  test('duplicatePendingRefreshesShareOneComputation', () async {
    final bus = EventBus();
    final runner = _ManualRunner();
    final cache = AnalysisCache(runner: runner.call)..start(bus);
    final state = _fullState();

    final first = cache.refresh(state);
    final second = cache.refresh(state);

    expect(identical(first, second), isTrue);
    expect(runner.pending, hasLength(1));

    runner.pending.single.complete(const []);
    await pumpEventQueue();
    await first;
    await second;
  });

  test('acceptedIdenticalRefreshDoesNoWork', () async {
    final runner = _ManualRunner();
    final cache = AnalysisCache(runner: runner.call);
    final state = _fullState();

    cache.refresh(state);
    runner.pending.single.complete(const []);
    await pumpEventQueue();

    cache.refresh(state);

    expect(runner.pending, hasLength(1));
  });

  test('legacyRefreshDuringPublicationStampsTheNewRevision', () async {
    final ledger = Ledger();
    final account = _account();
    ledger.addAccount(account);
    final runner = _ManualRunner();
    final cache = AnalysisCache(runner: runner.call)
      ..start(ledger.bus, sourceRevision: () => ledger.revision);
    ledger.bus.subscribe().listen((_) => cache.refresh(ledger.state));

    ledger.addEntry(
      Entry(amount: Decimal.fromInt(-10), name: 'lunch', sourceID: account.id),
    );
    expect(runner.pending, hasLength(1));

    runner.pending.single.complete(_items(10));
    await pumpEventQueue();

    expect(ledger.revision, 2);
    expect(cache.itemsSourceRevision, 2);
    expect(cache.items.single.amount, Decimal.fromInt(10));
  });

  test('runnerInputRetainsTheRequestedContentsOfAllFiveTables', () async {
    final runner = _ManualRunner();
    final cache = AnalysisCache(runner: runner.call);
    final state = _fullState();

    cache.refresh(state);
    state.addAccount(_account(name: 'late'));
    state.addCategory(_category(name: 'late'));
    runner.pending.single.complete(const []);
    await pumpEventQueue();

    final captured = runner.seen.single;
    expect(captured.moneySources, hasLength(1));
    expect(captured.entries, hasLength(1));
    expect(captured.categories, hasLength(1));
    expect(captured.plans, hasLength(1));
    expect(captured.budgets, hasLength(1));
  });

  test('olderCompletionAfterNewerAcceptanceCannotOverwrite', () async {
    final bus = EventBus();
    final runner = _ManualRunner();
    final cache = AnalysisCache(runner: runner.call)..start(bus);
    final state = _fullState();

    cache.refresh(state);
    bus.publish([UpsertAccount(_account(name: 'b'))]);
    cache.refresh(state);

    runner.pending[1].complete(_items(2));
    await pumpEventQueue();
    runner.pending[0].complete(_items(1));
    await pumpEventQueue();

    expect(cache.items.single.amount, Decimal.fromInt(2));
    expect(cache.itemsSourceRevision, 1);
    expect(cache.itemsRevision, 1);
  });

  test('failureRecordsSourceTaggedFailureAndAllowsSameRevisionRetry', () async {
    final runner = _ManualRunner();
    final cache = AnalysisCache(runner: runner.call);
    var notifications = 0;
    cache.addListener(() => notifications++);
    final state = _fullState();

    cache.refresh(state);
    runner.pending.single.completeError(StateError('boom'));
    await pumpEventQueue();

    expect(cache.items, isEmpty);
    expect(cache.itemsSourceRevision, -1);
    expect(cache.lastFailure, isNotNull);
    expect(cache.lastFailure!.sourceRevision, 0);
    expect(notifications, 0);

    cache.refresh(state);
    expect(runner.pending, hasLength(2));
    runner.pending[1].complete(_items(10));
    await pumpEventQueue();

    expect(cache.items.single.amount, Decimal.fromInt(10));
    expect(cache.itemsSourceRevision, 0);
    expect(cache.lastFailure, isNull);
    expect(notifications, 1);
  });

  test('staleFailureAfterNewerSuccessIsInert', () async {
    final bus = EventBus();
    final runner = _ManualRunner();
    final cache = AnalysisCache(runner: runner.call)..start(bus);
    final state = _fullState();

    cache.refresh(state);
    bus.publish([UpsertAccount(_account(name: 'b'))]);
    cache.refresh(state);

    runner.pending[1].complete(_items(2));
    await pumpEventQueue();
    runner.pending[0].completeError(StateError('stale'));
    await pumpEventQueue();

    expect(cache.items.single.amount, Decimal.fromInt(2));
    expect(cache.itemsSourceRevision, 1);
    expect(cache.lastFailure, isNull);
  });

  test('disposePreventsPublicationWorkAndLateAcceptance', () async {
    final bus = EventBus();
    final runner = _ManualRunner();
    final cache = AnalysisCache(runner: runner.call)..start(bus);
    var notifications = 0;
    cache.addListener(() => notifications++);

    cache.refresh(_fullState());
    final disposing = cache.dispose();
    bus.publish([UpsertAccount(_account(name: 'late'))]);
    runner.pending.single.complete(_items(10));
    await pumpEventQueue();
    await disposing;

    expect(notifications, 0);
    expect(cache.items, isEmpty);
    expect(cache.itemsSourceRevision, -1);
    expect(cache.revision, 0);
  });

  test('disposeMakesLateFailureInert', () async {
    final runner = _ManualRunner();
    final cache = AnalysisCache(runner: runner.call);

    cache.refresh(_fullState());
    await cache.dispose();
    runner.pending.single.completeError(StateError('late'));
    await pumpEventQueue();

    expect(cache.lastFailure, isNull);
  });

  test('rebindingToADifferentBusRequiresANewInstance', () {
    final cache = AnalysisCache()..start(EventBus());

    expect(() => cache.start(EventBus()), throwsStateError);
  });

  test('synchronousRunnerThrowDoesNotBlockRetryAtTheSameRevision', () async {
    var calls = 0;
    Future<List<AnalysisItem>> flaky(LedgerState state) {
      calls++;
      if (calls == 1) throw StateError('sync boom');
      return Future.value(_items(10));
    }

    final cache = AnalysisCache(runner: flaky);
    final state = _fullState();

    await cache.refresh(state);
    expect(calls, 1);
    expect(cache.lastFailure, isNotNull);

    await cache.refresh(state);
    expect(calls, 2);
    expect(cache.items.single.amount, Decimal.fromInt(10));
    expect(cache.itemsSourceRevision, 0);
  });
}
