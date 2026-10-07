part of 'ledger_state.dart';

const _clauseKeysMatchIDs = 1;
const _clausePocketLinks = 2;
const _clauseNoOrphanPocket = 3;
const _clauseEntryReferences = 4;
const _clauseCategoryNesting = 5;
const _clauseEntryCategory = 6;
const _clausePlanReferences = 7;
const _clausePlanNotExhausted = 8;
const _clauseEntriesActive = 9;
const _clauseNoStoredTombstone = 10;
const _clauseReferenceOnlyReferenced = 11;
const _clauseLifecycleMonotonic = 12;
const _clauseStatementDay = 13;
const _clausePlansReferenceActive = 14;
const _clausePocketLiveness = 15;
const _clauseBudgetCategory = 16;
const _clauseBudgetLimitEvents = 17;

extension LedgerStateInvariants on LedgerState {
  void _assertChecked() {
    assertInvariants();
    _assertLifecycleMonotonic();
    _lifecycleAtLastCheck = _lifecycleSnapshot();
  }

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
  }

  void _assertKeysMatchIDs() {
    for (final MapEntry(:key, :value) in _moneySources.entries) {
      if (key != value.id) {
        throw _violation(
          _clauseKeysMatchIDs,
          'money source $key holds ${value.id}',
        );
      }
    }
    for (final MapEntry(:key, :value) in _entries.entries) {
      if (key != value.id) {
        throw _violation(_clauseKeysMatchIDs, 'entry $key holds ${value.id}');
      }
    }
    for (final MapEntry(:key, :value) in _categories.entries) {
      if (key != value.id) {
        throw _violation(
          _clauseKeysMatchIDs,
          'category $key holds ${value.id}',
        );
      }
    }
  }

  void _assertPocketLinksResolveAndAreExclusive() {
    final claimedBy = <String, String>{};
    for (final account in _accounts) {
      for (final pocketID in account.subPocketIDs) {
        if (_moneySources[pocketID]?.asPocket == null) {
          throw _violation(
            _clausePocketLinks,
            'account ${account.id} links unresolved $pocketID',
          );
        }

        final other = claimedBy[pocketID];
        if (other != null) {
          throw _violation(
            _clausePocketLinks,
            'pocket $pocketID linked by $other and ${account.id}',
          );
        }
        claimedBy[pocketID] = account.id;
      }
    }
  }

  void _assertNoOrphanPocket() {
    for (final source in _moneySources.values) {
      final pocket = source.asPocket;
      if (pocket == null) continue;

      if (_owningAccount(pocket.id) == null) {
        throw _violation(
          _clauseNoOrphanPocket,
          'pocket ${pocket.id} has no owning account',
        );
      }
    }
  }

  void _assertNoDanglingEntryReference() {
    for (final entry in _entries.values) {
      for (final holderID in entry.holderIDs) {
        if (!_moneySources.containsKey(holderID)) {
          throw _violation(
            _clauseEntryReferences,
            'entry ${entry.id} references unknown $holderID',
          );
        }
      }
    }
  }

  void _assertCategoryNesting() {
    for (final category in _categories.values) {
      final parentID = category.parentID;
      if (parentID == null) continue;

      final parent = _categories[parentID];
      if (parent == null) {
        throw _violation(
          _clauseCategoryNesting,
          'category ${category.id} has unknown parent',
        );
      }
      if (parent.parentID != null) {
        throw _violation(
          _clauseCategoryNesting,
          'category ${category.id} nests below depth 2',
        );
      }
      if (parent.kind != category.kind) {
        throw _violation(
          _clauseCategoryNesting,
          'category ${category.id} kind differs from parent',
        );
      }

      if (!parent.lifecycle.isAtLeastAsAliveAs(category.lifecycle) &&
          !parent.lifecycle.isAtLeastAsAliveAs(LifecycleState.archived)) {
        throw _violation(
          _clauseCategoryNesting,
          'category ${category.id} sits under ${parent.lifecycle.name} parent',
        );
      }
    }
  }

  void _assertEntryCategoryCoherence() {
    for (final entry in _entries.values) {
      final categoryID = entry.categoryID;
      if (categoryID == null) continue;

      final category = _categories[categoryID];
      if (category == null) continue;

      final expected = entry.expectedCategoryKind;
      if (expected == null) {
        throw _violation(
          _clauseEntryCategory,
          'transfer ${entry.id} carries a category',
        );
      }
      if (category.kind != expected) {
        throw _violation(
          _clauseEntryCategory,
          'entry ${entry.id} kind differs from its category',
        );
      }
    }
  }

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

  void _assertEntriesActive() {
    for (final entry in _entries.values) {
      if (!entry.lifecycle.isActive) {
        throw _violation(
          _clauseEntriesActive,
          'entry ${entry.id} is ${entry.lifecycle.name}',
        );
      }
    }
  }

  void _assertNoStoredTombstone() {
    for (final source in _moneySources.values) {
      if (source.lifecycle == LifecycleState.tombstoned) {
        throw _violation(
          _clauseNoStoredTombstone,
          'money source ${source.id} is stored tombstoned',
        );
      }
    }
    for (final category in _categories.values) {
      if (category.lifecycle == LifecycleState.tombstoned) {
        throw _violation(
          _clauseNoStoredTombstone,
          'category ${category.id} is stored tombstoned',
        );
      }
    }
  }

  void _assertReferenceOnlyImpliesReferenced() {
    for (final category in _categories.values) {
      if (category.lifecycle != LifecycleState.referenceOnly) continue;

      if (_isCategoryReferenced(category.id)) continue;

      throw _violation(
        _clauseReferenceOnlyReferenced,
        'referenceOnly category ${category.id} unreferenced',
      );
    }

    for (final source in _moneySources.values) {
      if (source.lifecycle != LifecycleState.referenceOnly) continue;
      if (_isHolderReferenced(source.id)) continue;

      throw _violation(
        _clauseReferenceOnlyReferenced,
        'referenceOnly ${source.id} has no reference',
      );
    }
  }

  void _assertStatementDayInRange() {
    for (final account in _accounts) {
      final statementDay = account.statementDay;
      if (account.type != AccountType.card) {
        if (statementDay != null) {
          throw _violation(
            _clauseStatementDay,
            '${account.type.name} account ${account.id} carries a statement day',
          );
        }
        continue;
      }

      if (statementDay != null &&
          (statementDay < Account.minStatementDay ||
              statementDay > Account.maxStatementDay)) {
        throw _violation(
          _clauseStatementDay,
          'card ${account.id} has statement day $statementDay',
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

  void _assertPocketNotMoreAliveThanAccount() {
    for (final account in _accounts) {
      for (final pocketID in account.subPocketIDs) {
        final pocket = _moneySources[pocketID]?.asPocket;
        if (pocket == null) continue;

        if (!account.lifecycle.isAtLeastAsAliveAs(pocket.lifecycle)) {
          throw _violation(
            _clausePocketLiveness,
            '${account.lifecycle.name} account ${account.id} holds '
            '${pocket.lifecycle.name} pocket $pocketID',
          );
        }
      }
    }
  }

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

  Iterable<Account> get _accounts =>
      _moneySources.values.map((source) => source.asAccount).nonNulls;

  StateError _violation(int clause, String detail) =>
      StateError('Ledger invariant $clause violated: $detail');
}
