part of '../ledger_state.dart';

const _clauseLifecycleMonotonic = 12;

extension LedgerStateInvariants on LedgerState {
  // MARK: - Checks

  void assertInvariants() {
    _assertKeysMatchIDs();
    _assertPocketLinksResolveAndAreExclusive();
    _assertNoOrphanPocket();
    _assertNoDanglingEntryReference();
    _assertCategoryNesting();
    _assertEntryCategoryCoherence();
    _assertNoDanglingPlanReference();
    _assertNoExhaustedPlanStored();
    _assertEntriesActive();
    _assertNoStoredTombstone();
    _assertReferenceOnlyImpliesReferenced();
    _assertStatementDayInRange();
    _assertPlansReferenceActiveRows();
    _assertPocketNotMoreAliveThanAccount();
    _assertBudgetCategoryResolves();
    _assertBudgetLimitEventShape();
    _assertEntryInOneTable();
  }

  void _assertChecked() {
    assertInvariants();
    _assertLifecycleMonotonic();
    _lifecycleAtLastCheck = _lifecycleSnapshot();
  }

  // MARK: - Lifecycle tracking

  Map<String, LifecycleState> _lifecycleSnapshot() => {
    for (final MapEntry(:key, :value) in _moneySources.entries)
      key: value.lifecycle,
    for (final MapEntry(:key, :value) in _categories.entries)
      key: value.lifecycle,
  };

  void _assertLifecycleMonotonic() {
    final before = _lifecycleAtLastCheck;
    if (before == null) return;

    for (final MapEntry(:key, value: now) in _lifecycleSnapshot().entries) {
      final then = before[key];
      if (then == null || now == then) continue;

      if (now.isAtLeastAsAliveAs(then) &&
          !(then == LifecycleState.archived && now == LifecycleState.active)) {
        throw _violation(
          _clauseLifecycleMonotonic,
          'row $key moved from ${then.name} back to ${now.name}',
        );
      }
    }
  }

  // MARK: - Helpers

  Iterable<MapEntry<String, Entry>> get _allEntryPairs =>
      _entries.entries.followedBy(_binnedEntries.entries);

  Iterable<Account> get _accounts =>
      _moneySources.values.map((source) => source.asAccount).nonNulls;

  StateError _violation(int clause, String detail) =>
      StateError('Ledger invariant $clause violated: $detail');
}
