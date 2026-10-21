import 'dart:async';

import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ledger/analysis/analysis_query_result.dart';
import 'package:spendwise/ledger/analysis_cache.dart';
import 'package:spendwise/ledger/analysis_queries.dart';
import 'package:spendwise/ledger/ledger.dart';

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
