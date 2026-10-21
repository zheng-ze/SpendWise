import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ledger/analysis_queries.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ledger/analysis/analysis_query_result.dart';

import 'analysis_test_support.dart';

final _today = DateTime.utc(2026, 10, 3);

Decimal dec(String value) => Decimal.parse(value);

TransactionCategory dining() => TransactionCategory(
  id: testId(1),
  name: 'Dining',
  kind: CategoryKind.expense,
  colorHex: '#FF9500',
  includeInAnalysis: true,
  parentID: null,
  symbol: 'restaurant',
);

Account checking() =>
    Account(id: testId(2), name: 'Checking', type: AccountType.checking);

void main() {
  late ({Ledger ledger, AnalysisQueries queries, ManualRunner runner}) fixture;

  setUp(() {
    final setup = setupAnalysis(today: _today);
    fixture = (
      ledger: setup.ledger,
      queries: setup.queries,
      runner: setup.runner,
    );
    setup.ledger.addAccount(checking());
    setup.ledger.addCategory(dining());
  });

  String addDiningBudget() {
    fixture.ledger.addBudget(testId(1), dec('350'), now: _today);
    return fixture.ledger.state.budgets.values.single.id;
  }

  test(
    'readBudgets stays pending until the cache accepts the revision',
    () async {
      addDiningBudget();

      final pending = fixture.queries.readBudgets(month: _today);
      await settle(fixture.runner, fixture.ledger);
      final ready = fixture.queries.readBudgets(month: _today);

      expect(pending.state, AnalysisQueryState.loading);
      expect(pending.value, isNull);
      expect(ready.state, AnalysisQueryState.ready);
      expect(ready.value?.categoryBudgets.single.limit, dec('350'));
      expect(ready.sourceRevision, fixture.ledger.revision);
    },
  );
  test('a ledger change recomputes the overview at the new revision', () async {
    addDiningBudget();
    await settle(fixture.runner, fixture.ledger);
    fixture.queries.readBudgets(month: _today);
    fixture.ledger.addEntry(
      Entry(
        amount: dec('-30'),
        name: 'Lunch',
        sourceID: testId(2),
        categoryID: testId(1),
        date: DateTime.utc(2026, 10, 2),
      ),
    );

    final stale = fixture.queries.readBudgets(month: _today);
    await settle(fixture.runner, fixture.ledger);
    final fresh = fixture.queries.readBudgets(month: _today);

    expect(stale.value?.allSpending.spent, Decimal.zero);
    expect(stale.state, AnalysisQueryState.loading);
    expect(fresh.value?.allSpending.spent, dec('30'));
    expect(fresh.sourceRevision, fixture.ledger.revision);
  });
}
