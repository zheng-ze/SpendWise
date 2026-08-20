part of 'ledger_state.dart';

extension LedgerStateBudgets on LedgerState {
  List<LedgerChange> addBudget(
    String? categoryID,
    Decimal initialAmount,
    RolloverMode rolloverMode, {
    Decimal? carryCap,
  }) {
    final normalizedCategoryID = normalizedOptionalID(categoryID);
    _validateCategoryReference(normalizedCategoryID);
    _validateCategoryUniqueness(normalizedCategoryID);
    if (initialAmount <= Decimal.zero) throw const ZeroAmount();
    _validateCarryCap(carryCap, rolloverMode);

    final createdAtMonth = YearMonth.fromUtc(DateTime.now().toUtc());
    final budget = Budget(
      categoryID: normalizedCategoryID,
      limitEvents: [
        LimitEvent(
          effectiveFromMonth: null,
          value: initialAmount,
          kind: LimitEventKind.defaultLimit,
        ),
      ],
      rolloverMode: rolloverMode,
      carryCap: carryCap,
      createdAtMonth: createdAtMonth,
    );
    _budgets[budget.id] = budget;
    return _checked([UpsertBudget(budget)]);
  }

  List<LedgerChange> updateBudgetAmount(
    String rawBudgetID,
    Decimal newAmount,
    YearMonth effectiveFromMonth,
  ) {
    final budgetID = normalizedID(rawBudgetID);
    final stored = _budgets[budgetID];
    if (stored == null) throw UnknownBudget(budgetID);

    if (newAmount <= Decimal.zero) throw const ZeroAmount();

    final updated = _appendEvent(
      stored,
      LimitEvent(
        effectiveFromMonth: effectiveFromMonth,
        value: newAmount,
        kind: LimitEventKind.defaultLimit,
      ),
    );
    _budgets[updated.id] = updated;
    return _checked([UpsertBudget(updated)]);
  }

  List<LedgerChange> setBudgetMonthOverride(
    String rawBudgetID,
    YearMonth month,
    Decimal value,
  ) {
    final budgetID = normalizedID(rawBudgetID);
    final stored = _budgets[budgetID];
    if (stored == null) throw UnknownBudget(budgetID);

    if (value <= Decimal.zero) throw const ZeroAmount();

    final updated = _appendEvent(
      stored,
      LimitEvent(
        effectiveFromMonth: month,
        value: value,
        kind: LimitEventKind.override,
      ),
    );
    _budgets[updated.id] = updated;
    return _checked([UpsertBudget(updated)]);
  }

  List<LedgerChange> deleteBudget(String rawID) {
    final id = normalizedID(rawID);
    if (_budgets.remove(id) == null) return _checked([]);

    return _checked([DeleteBudget(id)]);
  }

  Budget _appendEvent(Budget stored, LimitEvent event) => Budget(
    id: stored.id,
    categoryID: stored.categoryID,
    limitEvents: [...stored.limitEvents, event],
    rolloverMode: stored.rolloverMode,
    carryCap: stored.carryCap,
    createdAtMonth: stored.createdAtMonth,
  );

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

  void _validateCarryCap(Decimal? carryCap, RolloverMode rolloverMode) {
    if (rolloverMode == RolloverMode.none) {
      if (carryCap != null) throw const CarryCapInvalid();
      return;
    }
    if (carryCap != null && carryCap <= Decimal.zero) {
      throw const CarryCapInvalid();
    }
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
