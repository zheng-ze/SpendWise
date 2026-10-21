import 'dart:async';

import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ledger/analysis_cache.dart';
import 'package:spendwise/ledger/event_bus.dart';

Account _account({String name = 'acc'}) =>
    Account(name: name, type: AccountType.savings);

LedgerState _stateWithExpense(String amount) {
  final state = LedgerState();
  final account = _account();
  state.addAccount(account);
  state.addEntry(
    Entry(amount: Decimal.parse(amount), name: 'e', sourceID: account.id),
  );
  return state;
}

class _ManualRunner {
  final List<Completer<List<AnalysisItem>>> pending = [];

  Future<List<AnalysisItem>> call(LedgerState state) {
    final completer = Completer<List<AnalysisItem>>();
    pending.add(completer);
    return completer.future;
  }
}

void main() {
  test('busEventBumpsRevision', () {
    final bus = EventBus();
    final cache = AnalysisCache()..start(bus);

    bus.publish([UpsertAccount(_account())]);

    expect(cache.revision, 1);
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

    runner.pending[1].complete(fromB);
    await pumpEventQueue();
    runner.pending[0].complete(fromA);
    await pumpEventQueue();

    expect(cache.items, fromB);
  });
  test('isolateRunnerRoundTripsDecimalMoney', () async {
    final cache = AnalysisCache();

    await cache.refresh(_stateWithExpense('-1234.56'));

    expect(cache.items, hasLength(1));
    expect(cache.items.single.amount, Decimal.parse('1234.56'));
    expect(cache.items.single.kind, CategoryKind.expense);
  });
}
