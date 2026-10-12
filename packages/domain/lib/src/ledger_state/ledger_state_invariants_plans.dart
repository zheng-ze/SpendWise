part of 'ledger_state.dart';

const _clausePlanReferences = 7;
const _clausePlanNotExhausted = 8;
const _clausePlansReferenceActive = 14;

extension LedgerStatePlanInvariants on LedgerState {
  // MARK: - References

  void _assertNoDanglingPlanReference() {
    for (final plan in _plans.values) {
      for (final holderID in plan.template.holderIDs) {
        if (!_moneySources.containsKey(holderID)) {
          throw _violation(
            _clausePlanReferences,
            'plan ${plan.id} references unknown $holderID',
          );
        }
      }

      final categoryID = plan.template.categoryID;
      if (categoryID != null && !_categories.containsKey(categoryID)) {
        throw _violation(
          _clausePlanReferences,
          'plan ${plan.id} references unknown $categoryID',
        );
      }
    }
  }

  void _assertPlansReferenceActiveRows() {
    bool isLeaving(LifecycleState lifecycle) =>
        lifecycle == LifecycleState.referenceOnly ||
        lifecycle == LifecycleState.tombstoned;

    for (final plan in _plans.values) {
      for (final holderID in plan.template.holderIDs) {
        final holder = _moneySources[holderID];
        if (holder == null || !isLeaving(holder.lifecycle)) continue;

        throw _violation(
          _clausePlansReferenceActive,
          'plan ${plan.id} references ${holder.lifecycle.name} $holderID',
        );
      }

      final categoryID = plan.template.categoryID;
      if (categoryID == null) continue;

      final category = _categories[categoryID];
      if (category == null || !isLeaving(category.lifecycle)) continue;

      throw _violation(
        _clausePlansReferenceActive,
        'plan ${plan.id} references ${category.lifecycle.name} $categoryID',
      );
    }
  }

  // MARK: - Exhaustion

  void _assertNoExhaustedPlanStored() {
    for (final plan in _plans.values) {
      final endDate = plan.endDate;
      if (endDate == null) continue;

      if (!plan.lastResolvedDate.isBefore(endDate)) {
        throw _violation(
          _clausePlanNotExhausted,
          'plan ${plan.id} is stored exhausted',
        );
      }
    }
  }
}
