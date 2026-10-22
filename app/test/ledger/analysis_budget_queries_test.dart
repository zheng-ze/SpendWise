import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ledger/analysis_queries.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ledger/analysis/analysis_query_result.dart';
import 'package:spendwise/ledger/analysis/budgets/budget_detail.dart';
import 'package:spendwise/ledger/analysis/insights/completeness.dart';

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

  test('equivalent month inputs reuse one memoised result', () async {
    addDiningBudget();
    await settle(fixture.runner, fixture.ledger);

    final first = fixture.queries.readBudgets(month: DateTime.utc(2026, 10, 1));
    final second = fixture.queries.readBudgets(
      month: DateTime.utc(2026, 10, 28),
    );

    expect(identical(first, second), isTrue);
  });

  test(
    'readBudgetDetail normalises the id and dates before memo identity',
    () async {
      final id = addDiningBudget();
      await settle(fixture.runner, fixture.ledger);

      final lower = fixture.queries.readBudgetDetail(
        budgetID: id,
        displayedYear: DateTime.utc(2026, 3, 9),
        selectedMonth: DateTime.utc(2026, 10, 1),
      );
      final upper = fixture.queries.readBudgetDetail(
        budgetID: id.toUpperCase(),
        displayedYear: DateTime.utc(2026),
        selectedMonth: DateTime.utc(2026, 10, 20),
      );

      expect(id, isNot(id.toUpperCase()));
      expect(identical(lower, upper), isTrue);
      expect(lower.value?.slots.length, 12);
    },
  );

  test('a missing budget reads as ready with no summary', () async {
    await settle(fixture.runner, fixture.ledger);

    final result = fixture.queries.readBudgetDetail(
      budgetID: testId(99),
      displayedYear: DateTime.utc(2026),
      selectedMonth: DateTime.utc(2026, 10),
    );

    expect(result.state, AnalysisQueryState.ready);
    expect(result.value?.summary, isNull);
    expect(result.value?.slots, isEmpty);
  });

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

  test('budget detail values compare their money and slot state', () {
    final month = YearMonth(2026, 10);
    final slot = BudgetMonthSlot(
      month: month,
      spend: dec('12'),
      limit: dec('30'),
      isOverride: true,
      recordCount: 1,
      completeness: PeriodCompleteness.complete,
    );
    final sameSlot = BudgetMonthSlot(
      month: month,
      spend: dec('12'),
      limit: dec('30'),
      isOverride: true,
      recordCount: 1,
      completeness: PeriodCompleteness.complete,
    );
    final summary = BudgetDetailSummary(
      categoryID: testId(1),
      createdAtMonth: YearMonth(2026, 1),
      spent: dec('12'),
      limit: dec('30'),
    );
    final detail = BudgetDetail(
      budgetID: testId(2),
      displayedYear: 2026,
      selectedMonth: month,
      summary: summary,
      slots: [slot],
    );
    final equalDetail = BudgetDetail(
      budgetID: testId(2),
      displayedYear: 2026,
      selectedMonth: month,
      summary: summary,
      slots: [sameSlot],
    );

    expect(slot, sameSlot);
    expect(slot.hashCode, sameSlot.hashCode);
    expect(summary.remaining, dec('18'));
    expect(detail, equalDetail);
    expect(detail.hashCode, equalDetail.hashCode);
    expect(detail.slots, hasLength(1));
  });
}
