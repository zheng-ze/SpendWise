part of '../ledger_state.dart';

extension LedgerStateBudgets on LedgerState {
  // MARK: - Mutators

  List<LedgerChange> addBudget(String? categoryID, Decimal limit) {
    final normalizedCategoryID = normalizedOptionalID(categoryID);
    _validateCategoryReference(normalizedCategoryID);
    _validateCategoryUniqueness(normalizedCategoryID);
    if (limit <= Decimal.zero) throw const ZeroAmount();

    final budget = Budget(categoryID: normalizedCategoryID, limit: limit);
    _budgets[budget.id] = budget;
    return _checked([UpsertBudget(budget)]);
  }

  List<LedgerChange> updateBudgetLimit(String rawBudgetID, Decimal limit) {
    final budgetID = normalizedID(rawBudgetID);
    final stored = _budgets[budgetID];
    if (stored == null) throw UnknownBudget(budgetID);

    if (limit <= Decimal.zero) throw const ZeroAmount();

    final updated = Budget(
      id: stored.id,
      categoryID: stored.categoryID,
      limit: limit,
    );
    _budgets[updated.id] = updated;
    return _checked([UpsertBudget(updated)]);
  }

  List<LedgerChange> deleteBudget(String rawID) {
    final id = normalizedID(rawID);
    if (_budgets.remove(id) == null) return _checked([]);

    return _checked([DeleteBudget(id)]);
  }

  // MARK: - Helpers

  void _validateCategoryReference(String? categoryID) {
    if (categoryID == null) return;

    final category = _categories[categoryID];
    if (category == null) throw UnknownCategory(categoryID);
    if (!category.lifecycle.isActive) throw InactiveReference(categoryID);
  }

  void _validateCategoryUniqueness(String? categoryID) {
    final collides = _budgets.values.any(
      (budget) => budget.categoryID == categoryID,
    );
    if (collides) throw const CategoryAlreadyBudgeted();
  }

  List<LedgerChange> _removeBudgetCategorized(String categoryID) {
    final match = _budgets.values
        .where((budget) => budget.categoryID == categoryID)
        .map((budget) => budget.id)
        .toList();
    for (final budgetID in match) {
      _budgets.remove(budgetID);
    }
    return match.map(DeleteBudget.new).toList();
  }
}
