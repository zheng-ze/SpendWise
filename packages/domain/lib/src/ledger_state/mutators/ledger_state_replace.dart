part of '../ledger_state.dart';

extension LedgerStateReplace on LedgerState {
  // MARK: - Replace

  List<LedgerChange> replaceContents(LedgerState replacement) {
    replacement.assertInvariants();

    final changes = [
      ..._deletesForAllRows(),
      ...replacement._upsertsForAllRows(),
    ];
    apply(changes);
    _lifecycleAtLastCheck = null;
    return _checked(changes);
  }

  List<LedgerChange> _deletesForAllRows() => [
    for (final id in _budgets.keys) DeleteBudget(id),
    for (final id in _plans.keys) DeletePlan(id),
    for (final id in _entries.keys) DeleteEntry(id),
    for (final id in _binnedEntries.keys) DeleteEntry(id),
    for (final id in _categories.keys) DeleteCategory(id),
    for (final id in _moneySources.keys) DeleteMoneySource(id),
  ];

  List<LedgerChange> _upsertsForAllRows() {
    final sources = _moneySources.values;
    final categories = _categories.values;
    return [
      for (final source in sources)
        if (source.asAccount case final account?) UpsertAccount(account),
      for (final source in sources)
        if (source.asPocket case final pocket?) UpsertPocket(pocket),
      for (final category in categories)
        if (category.parentID == null) UpsertCategory(category),
      for (final category in categories)
        if (category.parentID != null) UpsertCategory(category),
      for (final entry in _entries.values) UpsertEntry(entry),
      for (final entry in _binnedEntries.values) UpsertEntry(entry),
      for (final plan in _plans.values) UpsertPlan(plan),
      for (final budget in _budgets.values) UpsertBudget(budget),
    ];
  }
}
