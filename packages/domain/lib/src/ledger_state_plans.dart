part of 'ledger_state.dart';

extension LedgerStatePlans on LedgerState {
  List<LedgerChange> addPlan(RecurringPlan plan) {
    if (_plans.containsKey(plan.id)) throw IdCollision(plan.id);

    _validatePlan(plan);
    _plans[plan.id] = plan;
    return _checked([UpsertPlan(plan)]);
  }

  List<LedgerChange> updatePlan(RecurringPlan plan) {
    if (!_plans.containsKey(plan.id)) throw UnknownPlan(plan.id);

    _validatePlan(plan);
    _plans[plan.id] = plan;
    return _checked([UpsertPlan(plan)]);
  }

  List<LedgerChange> deletePlan(String rawID) {
    final id = canonicalID(rawID);
    if (_plans.remove(id) == null) return _checked([]);

    return _checked([DeletePlan(id)]);
  }

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
    if (endDate != null && !plan.lastResolvedDate.isBefore(endDate)) {
      throw ExhaustedPlan(plan.id);
    }
  }

  PlanResolution resolvePlans(DateTime now) {
    final changes = <LedgerChange>[];
    final failures = <PlanFailure>[];

    // Sorted so the emitted change list is reproducible.
    final planIDs = _plans.keys.toList()..sort();
    for (final planID in planIDs) {
      final plan = _plans[planID]!;
      final due = plan.occurrences(after: plan.lastResolvedDate, upTo: now);

      for (final date in due) {
        final entry = plan.template.makeEntry(plan.id, date);
        if (_entries.containsKey(entry.id)) continue;

        try {
          final stored = _validated(entry);
          _entries[stored.id] = stored;
          changes.add(UpsertEntry(stored));
        } on LedgerError catch (error) {
          failures.add(
            PlanFailure(planID: plan.id, occurrence: date, error: error),
          );
        }
      }

      final advanced = plan.resolvedAt(now);
      if (advanced.isExhausted(asOf: now)) {
        _plans.remove(plan.id);
        changes.add(DeletePlan(plan.id));
      } else if (due.isNotEmpty) {
        _plans[plan.id] = advanced;
        changes.add(UpsertPlan(advanced));
      }
      // An idle plan is left alone: a stale cursor only gates past
      // occurrences, so replaying yields the same empty result.
    }

    return _checkedResolution(
      PlanResolution(changes: changes, failures: failures),
    );
  }

  List<LedgerChange> _removePlansReferencing(Set<String> ids) =>
      _removePlansWhere((plan) => plan.template.touches(ids));

  List<LedgerChange> _removePlansCategorized(String categoryID) =>
      _removePlansWhere((plan) => plan.template.categoryID == categoryID);

  List<LedgerChange> _removePlansWhere(bool Function(RecurringPlan) doomed) {
    // Materialized before the removal loop: mutating _plans mid-iteration throws.
    final removed = _plans.values.where(doomed).map((plan) => plan.id).toList();
    for (final planID in removed) {
      _plans.remove(planID);
    }
    return removed.map(DeletePlan.new).toList();
  }
}
