import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ui/budgets/budget_list/budget_scope_options.dart';

import '../../../support/ledger_fixtures.dart';

LedgerState _state(
  List<TransactionCategory> categories, [
  List<Budget> budgets = const [],
]) => LedgerState(
  categories: {for (final category in categories) category.id: category},
  budgets: {for (final budget in budgets) budget.id: budget},
);

List<String> _labels(List<BudgetScopeOption> options) => [
  for (final option in options) option.label,
];

BudgetScopeOption _option(List<BudgetScopeOption> options, String label) =>
    options.firstWhere((option) => option.label == label);

void main() {
  test('lists All spending first, then roots by name with their children', () {
    final transport = testCategory(
      name: 'Transport',
      colorHex: '#00AA00',
      symbol: 'restaurant',
    );
    final food = testCategory(
      name: 'Food',
      colorHex: '#00AA00',
      symbol: 'restaurant',
    );
    final snacks = testCategory(
      name: 'Snacks',
      colorHex: '#00AA00',
      symbol: 'restaurant',
      parentID: food.id,
    );
    final dining = testCategory(
      name: 'Dining',
      colorHex: '#00AA00',
      symbol: 'restaurant',
      parentID: food.id,
    );

    final options = budgetScopeOptions(
      _state([transport, snacks, food, dining]),
    );

    expect(_labels(options), [
      'All spending',
      'Food',
      'Dining',
      'Snacks',
      'Transport',
    ]);
    expect(_option(options, 'Dining').isChild, isTrue);
    expect(_option(options, 'Food').isChild, isFalse);
  });

  test('All spending is disabled once an unscoped budget exists', () {
    final overall = Budget(categoryID: null, limit: Decimal.fromInt(10));

    final options = budgetScopeOptions(_state([], [overall]));

    expect(_option(options, 'All spending').disabled, isTrue);
  });

  test('All spending is enabled when only category budgets exist', () {
    final food = testCategory(
      name: 'Food',
      colorHex: '#00AA00',
      symbol: 'restaurant',
    );
    final budget = Budget(categoryID: food.id, limit: Decimal.fromInt(10));

    final options = budgetScopeOptions(_state([food], [budget]));

    expect(_option(options, 'All spending').disabled, isFalse);
  });

  test(
    'a budgeted root is disabled while its unbudgeted child stays enabled',
    () {
      final food = testCategory(
        name: 'Food',
        colorHex: '#00AA00',
        symbol: 'restaurant',
      );
      final dining = testCategory(
        name: 'Dining',
        colorHex: '#00AA00',
        symbol: 'restaurant',
        parentID: food.id,
      );
      final budget = Budget(categoryID: food.id, limit: Decimal.fromInt(10));

      final options = budgetScopeOptions(_state([food, dining], [budget]));

      expect(_option(options, 'Food').disabled, isTrue);
      expect(_option(options, 'Dining').disabled, isFalse);
    },
  );

  test('inactive and income categories are excluded', () {
    final food = testCategory(
      name: 'Food',
      colorHex: '#00AA00',
      symbol: 'restaurant',
    );
    final binned = testCategory(
      name: 'Binned',
      colorHex: '#00AA00',
      symbol: 'restaurant',
      lifecycle: LifecycleState.archived,
    );
    final salary = testCategory(
      name: 'Salary',
      colorHex: '#00AA00',
      symbol: 'restaurant',
      kind: CategoryKind.income,
    );
    final orphan = testCategory(
      name: 'Orphan',
      colorHex: '#00AA00',
      symbol: 'restaurant',
      parentID: binned.id,
    );

    final options = budgetScopeOptions(_state([food, binned, salary, orphan]));

    expect(_labels(options), ['All spending', 'Food']);
  });

  test('choices compare by value', () {
    expect(const AllSpendingChosen(), const AllSpendingChosen());
    expect(const CategoryChosen('a'), const CategoryChosen('a'));
    expect(const CategoryChosen('a'), isNot(const CategoryChosen('b')));
    expect(const CategoryChosen('a'), isNot(const AllSpendingChosen()));
  });
}
