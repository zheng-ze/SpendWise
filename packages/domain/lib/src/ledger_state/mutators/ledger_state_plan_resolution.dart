part of '../ledger_state.dart';

extension LedgerStatePlanResolution on LedgerState {
  // MARK: - Resolution

  PlanResolution _resolvePlans(DateTime now) {
    final changes = <LedgerChange>[];
    final failures = <PlanFailure>[];

    final planIDs = _plans.keys.toList()..sort();
    for (final planID in planIDs) {
      final plan = _plans[planID]!;
      final due = plan.occurrences(after: plan.lastResolvedDate, upTo: now);

      var cursor = plan.lastResolvedDate;
      var sawFailure = false;

      for (final date in due) {
        final entry = plan.template.makeEntry(plan.id, date);
        if (_entries.containsKey(entry.id) ||
            _binnedEntries.containsKey(entry.id)) {
          if (!sawFailure) cursor = date;
          continue;
        }

        try {
          final stored = _validated(entry);
          _entries[stored.id] = stored;
          changes.add(UpsertEntry(stored));
          if (!sawFailure) cursor = date;
        } on LedgerError catch (error) {
          failures.add(
            PlanFailure(planID: plan.id, occurrence: date, error: error),
          );
          sawFailure = true;
        }
      }

      final advanced = plan.resolvedAt(sawFailure ? cursor : now);
      if (advanced.isExhausted(asOf: now)) {
        _plans.remove(plan.id);
        changes.add(DeletePlan(plan.id));
      } else if (due.isNotEmpty) {
        _plans[plan.id] = advanced;
        changes.add(UpsertPlan(advanced));
      }
    }

    return _checkedResolution(
      PlanResolution(changes: changes, failures: failures),
    );
  }
}
