part of 'ledger_state.dart';

extension LedgerStatePlans on LedgerState {
  // MARK: - Mutators

  List<LedgerChange> addPlan(RecurringPlan plan) {
    if (_plans.containsKey(plan.id)) throw IdCollision(plan.id);

    _validatePlan(plan);
    _plans[plan.id] = plan;
    return _checked([UpsertPlan(plan)]);
  }

  List<LedgerChange> updatePlan(RecurringPlan plan) {
    final stored = _plans[plan.id];
    if (stored == null) throw UnknownPlan(plan.id);

    final schedulesChanged =
        stored.anchor != plan.anchor || stored.frequency != plan.frequency;
    if (schedulesChanged && stored.lastResolvedDate.isAfter(stored.anchor)) {
      throw StaleResolutionCursor(plan.id);
    }

    _validatePlan(plan);
    _plans[plan.id] = plan;
    return _checked([UpsertPlan(plan)]);
  }

  List<LedgerChange> deletePlan(String rawID) {
    final id = normalizedID(rawID);
    if (_plans.remove(id) == null) return _checked([]);

    return _checked([DeletePlan(id)]);
  }

  // MARK: - Validation

  void _validatePlan(RecurringPlan plan) {
    final template = plan.template;
    final source = _moneySources[template.sourceID];
    if (source == null) throw UnknownHolder(template.sourceID);
    if (!source.lifecycle.isActive) throw InactiveReference(template.sourceID);

    final destinationID = template.destinationID;
    if (destinationID != null) {
      final destination = _moneySources[destinationID];
      if (destination == null) throw UnknownHolder(destinationID);
      if (!destination.lifecycle.isActive) {
        throw InactiveReference(destinationID);
      }
    }

    final categoryID = template.categoryID;
    if (categoryID != null) {
      final category = _categories[categoryID];
      if (category == null) throw UnknownCategory(categoryID);
      final expected = template.expectedCategoryKind;
      if (expected == null) throw const CategoryKindMismatch();
      if (category.kind != expected) throw const CategoryKindMismatch();
      if (!category.lifecycle.isActive) throw InactiveReference(categoryID);
    }

    final endDate = plan.endDate;
    if (endDate != null && endDate.isBefore(plan.anchor)) {
      throw ExhaustedPlan(plan.id);
    }
    if (endDate != null && !plan.lastResolvedDate.isBefore(endDate)) {
      throw ExhaustedPlan(plan.id);
    }
  }

  // MARK: - Cascade removal

  List<LedgerChange> _removePlansReferencing(Set<String> ids) =>
      _removePlansWhere((plan) => plan.template.touches(ids));

  List<LedgerChange> _removePlansCategorized(String categoryID) =>
      _removePlansWhere((plan) => plan.template.categoryID == categoryID);

  List<LedgerChange> _removePlansWhere(bool Function(RecurringPlan) doomed) {
    final removed = _plans.values.where(doomed).map((plan) => plan.id).toList();
    for (final planID in removed) {
      _plans.remove(planID);
    }
    return removed.map(DeletePlan.new).toList();
  }
}
