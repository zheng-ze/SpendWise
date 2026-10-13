part of '../ledger_state.dart';

const _clauseBudgetCategory = 16;
const _clauseBudgetLimitEvents = 17;

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

  // MARK: - Limit event shape

  void _assertBudgetLimitEventShape() {
    for (final budget in _budgets.values) {
      final events = budget.limitEvents;
      if (events.isEmpty) {
        throw _violation(
          _clauseBudgetLimitEvents,
          'budget ${budget.id} has no limit events',
        );
      }

      final first = events.first;
      if (first.effectiveFromMonth != null) {
        throw _violation(
          _clauseBudgetLimitEvents,
          'budget ${budget.id} first event names a month',
        );
      }
      if (first.kind != LimitEventKind.defaultLimit) {
        throw _violation(
          _clauseBudgetLimitEvents,
          'budget ${budget.id} first event is not a default',
        );
      }

      for (final event in events.skip(1)) {
        if (event.effectiveFromMonth == null) {
          throw _violation(
            _clauseBudgetLimitEvents,
            'budget ${budget.id} has a later event with no month',
          );
        }
      }
    }
  }
}
