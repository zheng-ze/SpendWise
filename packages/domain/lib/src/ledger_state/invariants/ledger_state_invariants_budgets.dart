part of '../ledger_state.dart';

const _clauseBudgetCategory = 16;
const _clauseBudgetLimit = 17;

extension LedgerStateBudgetInvariants on LedgerState {
  // MARK: - Category scope

  void _assertBudgetCategoryResolves() {
    for (final budget in _budgets.values) {
      final categoryID = budget.categoryID;
      if (categoryID == null) continue;

      if (!_categories.containsKey(categoryID)) {
        throw _violation(
          _clauseBudgetCategory,
          'budget ${budget.id} references unknown $categoryID',
        );
      }
    }
  }

  // MARK: - Limit

  void _assertBudgetLimitPositive() {
    for (final budget in _budgets.values) {
      if (budget.limit <= Decimal.zero) {
        throw _violation(
          _clauseBudgetLimit,
          'budget ${budget.id} has a nonpositive limit',
        );
      }
    }
  }
}
