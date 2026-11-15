import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ledger/analysis/budgets/budget_forecast.dart';

import 'analysis_pace_fixture.dart';
import 'analysis_test_support.dart';

final _diningBudgetID = testId(31);
final _groceriesBudgetID = testId(32);
final _transportBudgetID = testId(33);
final _unscopedBudgetID = testId(34);
final _childBudgetID = testId(35);
final _diningChildID = testId(20);
final _lastDayOfOctober = DateTime.utc(2026, 10, 31);
final _augustFirstRecord = DateTime.utc(2026, 8, 1);
final _october = DateTime.utc(2026, 10, 1);

Decimal dec(String value) => Decimal.parse(value);

TransactionCategory _category(String id, String name, {String? parentID}) {
  return TransactionCategory(
    id: id,
    name: name,
    kind: CategoryKind.expense,
    colorHex: '#000000',
    includeInAnalysis: true,
    parentID: parentID,
    symbol: 'tag',
  );
}

Budget _diningBudget([Decimal? limit]) => Budget(
  id: _diningBudgetID,
  categoryID: paceCategoryIDs[paceDining],
  limit: limit ?? paceDiningLimit,
);

Budget _groceriesBudget([Decimal? limit]) => Budget(
  id: _groceriesBudgetID,
  categoryID: paceCategoryIDs[paceGroceries],
  limit: limit ?? paceGroceriesLimit,
);

Budget _transportBudget([Decimal? limit]) => Budget(
  id: _transportBudgetID,
  categoryID: paceCategoryIDs[paceTransport],
  limit: limit ?? paceTransportLimit,
);

List<Budget> _paceBudgets() => [
  _diningBudget(),
  _groceriesBudget(),
  _transportBudget(),
];

LedgerState _state(List<Budget> budgets) {
  final categories = [
    for (final key in [paceDining, paceGroceries, paceTransport])
      _category(paceCategoryIDs[key]!, key),
    _category(_diningChildID, 'child', parentID: paceCategoryIDs[paceDining]),
  ];
  return LedgerState(
    categories: {for (final c in categories) c.id: c},
    budgets: {for (final b in budgets) b.id: b},
  );
}

BudgetForecasts _forecasts(
  List<Budget> budgets, {
  List<AnalysisItem>? items,
  DateTime? firstRecordMonth,
  DateTime? today,
}) {
  return budgetForecasts(
    state: _state(budgets),
    items: items ?? paceItems(),
    firstRecordMonth: firstRecordMonth ?? paceFirstRecordMonth,
    today: today ?? paceToday,
  );
}

BudgetForecast _forCategory(BudgetForecasts result, String key) {
  return result.categoryBudgets.singleWhere(
    (f) => f.categoryID == paceCategoryIDs[key],
  );
}

AnalysisItem _expense(String? bucketID, String amount, int day) {
  return AnalysisItem(
    bucketID: bucketID,
    amount: dec(amount),
    date: DateTime.utc(2026, 10, day),
    kind: CategoryKind.expense,
  );
}

void main() {
  group('category forecasts', () {
    test('average and project each category budget', () {
      final result = _forecasts(_paceBudgets());

      expect(_forCategory(result, paceDining).monthlyAverage, dec('403.28'));
      expect(_forCategory(result, paceGroceries).monthlyAverage, dec('304'));
      expect(_forCategory(result, paceTransport).monthlyAverage, dec('134.04'));
      expect(_forCategory(result, paceDining).projected, dec('448.15'));
      expect(_forCategory(result, paceGroceries).projected, dec('348.08'));
      expect(_forCategory(result, paceTransport).projected, dec('131.07'));
    });

    test('report spent so far through today and the over by amount', () {
      final result = _forecasts(_paceBudgets());
      final dining = _forCategory(result, paceDining);
      final groceries = _forCategory(result, paceGroceries);

      expect(dining.spentSoFar, dec('83.90'));
      expect(dining.limit, paceDiningLimit);
      expect(dining.overBy, dec('98.15'));
      expect(groceries.spentSoFar, dec('73.50'));
      expect(groceries.overBy, isNull);
      expect(_forCategory(result, paceTransport).overBy, dec('11.07'));
    });

    test('order by normalized budget ID', () {
      final result = _forecasts([
        _transportBudget(),
        _diningBudget(),
        _groceriesBudget(),
      ]);

      expect(result.categoryBudgets.map((f) => f.budgetID), [
        _diningBudgetID,
        _groceriesBudgetID,
        _transportBudgetID,
      ]);
    });

    test('a projection equal to the limit at cents is on pace', () {
      final onPace = _forecasts([_groceriesBudget(dec('348.08'))]);
      final over = _forecasts([_groceriesBudget(dec('348.07'))]);

      expect(_forCategory(onPace, paceGroceries).isOver, isFalse);
      expect(_forCategory(over, paceGroceries).overBy, dec('0.01'));
    });

    test('a child category item counts toward its parent budget', () {
      final items = [
        ...paceItems(),
        _expense(_diningChildID, '10.00', 2),
        _expense(null, '7.00', 2),
      ];
      final result = _forecasts(_paceBudgets(), items: items);

      expect(_forCategory(result, paceDining).spentSoFar, dec('93.90'));
      expect(_forCategory(result, paceGroceries).spentSoFar, dec('73.50'));
      expect(_forCategory(result, paceTransport).spentSoFar, dec('10.00'));
      expect(result.allSpending?.spentSoFar, dec('184.40'));
    });
  });

  group('all spending', () {
    test('uses the derived cap when no budget is unscoped', () {
      final result = _forecasts(_paceBudgets());
      final all = result.allSpending!;

      expect(all.isDerivedCap, isTrue);
      expect(all.budgetID, isNull);
      expect(all.categoryID, isNull);
      expect(all.limit, dec('920'));
      expect(all.spentSoFar, dec('167.40'));
      expect(all.projected, dec('927.30'));
      expect(all.overBy, dec('7.30'));
      expect(result.overCount, 3);
    });

    test('an unscoped budget replaces the derived cap', () {
      final unscoped = Budget(
        id: _unscopedBudgetID,
        categoryID: null,
        limit: dec('900'),
      );
      final result = _forecasts([..._paceBudgets(), unscoped]);
      final all = result.allSpending!;

      expect(all.isDerivedCap, isFalse);
      expect(all.budgetID, _unscopedBudgetID);
      expect(all.limit, dec('900'));
      expect(all.overBy, dec('27.30'));
      expect(result.categoryBudgets, hasLength(3));
      expect(result.overCount, 3);
    });

    test('an unscoped budget above the projection is on pace', () {
      final unscoped = Budget(
        id: _unscopedBudgetID,
        categoryID: null,
        limit: dec('1000'),
      );
      final result = _forecasts([..._paceBudgets(), unscoped]);

      expect(result.allSpending?.isOver, isFalse);
      expect(result.overCount, 2);
    });

    test('an unscoped budget alone leaves no category forecasts', () {
      final unscoped = Budget(
        id: _unscopedBudgetID,
        categoryID: null,
        limit: dec('900'),
      );
      final result = _forecasts([unscoped]);

      expect(result.categoryBudgets, isEmpty);
      expect(result.allSpending?.projected, dec('927.30'));
      expect(result.overCount, 1);
    });

    test('no budgets gives no forecast with a usable baseline', () {
      final result = _forecasts(const []);

      expect(result.allSpending, isNull);
      expect(result.categoryBudgets, isEmpty);
      expect(result.overCount, 0);
      expect(result.hasBaseline, isTrue);
    });

    test('the derived cap sums only the parent when both are budgeted', () {
      final child = Budget(
        id: _childBudgetID,
        categoryID: _diningChildID,
        limit: dec('50'),
      );
      final items = [...paceItems(), _expense(_diningChildID, '10.00', 2)];
      final result = _forecasts([_diningBudget(), child], items: items);
      final childForecast = result.categoryBudgets.singleWhere(
        (f) => f.categoryID == _diningChildID,
      );

      expect(result.allSpending?.limit, paceDiningLimit);
      expect(result.categoryBudgets, hasLength(2));
      expect(childForecast.projected, dec('10.00'));
    });
  });

  group('baseline availability', () {
    test('fewer than three complete months gives no forecasts', () {
      final result = _forecasts(
        _paceBudgets(),
        firstRecordMonth: _augustFirstRecord,
      );

      expect(result.allSpending, isNull);
      expect(result.categoryBudgets, isEmpty);
      expect(result.overCount, 0);
      expect(result.hasBaseline, isFalse);
      expect(result.completeMonthCount, 2);
    });

    test('no first record month gives no forecasts', () {
      final result = budgetForecasts(
        state: _state(_paceBudgets()),
        items: paceItems(),
        firstRecordMonth: null,
        today: paceToday,
      );

      expect(result.hasBaseline, isFalse);
      expect(result.completeMonthCount, 0);
      expect(result.allSpending, isNull);
    });

    test('the last day of the month projects the spend so far', () {
      final result = _forecasts(_paceBudgets(), today: _lastDayOfOctober);

      expect(_forCategory(result, paceDining).projected, dec('83.90'));
      expect(_forCategory(result, paceGroceries).projected, dec('133.50'));
      expect(_forCategory(result, paceTransport).projected, dec('10.00'));
      expect(result.allSpending?.projected, dec('227.40'));
      expect(result.month, _october);
    });
  });

  group('value semantics', () {
    test('equal inputs give equal results', () {
      final a = _forecasts(_paceBudgets());
      final b = _forecasts(_paceBudgets());
      final other = _forecasts([_diningBudget(dec('351'))]);

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a.categoryBudgets.first, b.categoryBudgets.first);
      expect(
        a.categoryBudgets.first.hashCode,
        b.categoryBudgets.first.hashCode,
      );
      expect(a, isNot(other));
      expect(a.categoryBudgets.first, isNot(other.categoryBudgets.first));
    });

    test('the category list is unmodifiable', () {
      final result = _forecasts(_paceBudgets());

      expect(
        () => result.categoryBudgets.add(result.categoryBudgets.first),
        throwsUnsupportedError,
      );
    });
  });
}
