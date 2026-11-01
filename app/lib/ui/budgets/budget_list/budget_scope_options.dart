import 'package:domain/domain.dart';

// MARK: - Constants
const allSpendingLabel = 'All spending';

// MARK: - BudgetScopeChoice
sealed class BudgetScopeChoice {
  const BudgetScopeChoice();

  String? get categoryID;
}

final class AllSpendingChosen extends BudgetScopeChoice {
  const AllSpendingChosen();

  @override
  String? get categoryID => null;

  @override
  bool operator ==(Object other) => other is AllSpendingChosen;

  @override
  int get hashCode => (AllSpendingChosen).hashCode;
}

final class CategoryChosen extends BudgetScopeChoice {
  const CategoryChosen(this.categoryID);

  @override
  final String categoryID;

  @override
  bool operator ==(Object other) =>
      other is CategoryChosen && other.categoryID == categoryID;

  @override
  int get hashCode => Object.hash(CategoryChosen, categoryID);
}

// MARK: - BudgetScopeOption
class BudgetScopeOption {
  const BudgetScopeOption({
    required this.choice,
    required this.label,
    required this.isChild,
    required this.disabled,
    this.category,
  });

  final BudgetScopeChoice choice;
  final String label;
  final bool isChild;
  final bool disabled;
  final TransactionCategory? category;
}

// MARK: - Options
List<BudgetScopeOption> budgetScopeOptions(LedgerState state) {
  final budgeted = {
    for (final budget in state.budgets.values) budget.categoryID,
  };
  final active = [
    for (final category in state.categories.values)
      if (category.lifecycle.isActive && category.kind == CategoryKind.expense)
        category,
  ]..sort((a, b) => a.name.compareTo(b.name));

  BudgetScopeOption option(
    TransactionCategory category, {
    bool isChild = false,
  }) {
    return BudgetScopeOption(
      choice: CategoryChosen(category.id),
      label: category.name,
      isChild: isChild,
      disabled: budgeted.contains(category.id),
      category: category,
    );
  }

  final allSpending = BudgetScopeOption(
    choice: const AllSpendingChosen(),
    label: allSpendingLabel,
    isChild: false,
    disabled: budgeted.contains(null),
  );
  final roots = active.where((category) => category.parentID == null);

  return [
    allSpending,
    for (final root in roots) ...[
      option(root),
      for (final child in active.where((c) => c.parentID == root.id))
        option(child, isChild: true),
    ],
  ];
}
