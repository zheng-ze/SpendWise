part of 'ledger_state.dart';

extension LedgerStateInvariants on LedgerState {
  // Only `_checked` calls this. `assertInvariants` stays snapshot-only so a
  // caller can validate a state it did not build, as persistence replay does.
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

  // Lifecycle only moves toward less alive, except archived back to active.
  // Needs the prior snapshot because the resulting state alone is legal.
  void _assertLifecycleMonotonic() {
    final before = _lifecycleAtLastCheck;
    if (before == null) return;

    for (final MapEntry(:key, value: now) in _lifecycleSnapshot().entries) {
      final then = before[key];
      if (then == null || now == then) continue;

      if (now.isAtLeastAsAliveAs(then) &&
          !(then == LifecycleState.archived && now == LifecycleState.active)) {
        throw _violation(
          12,
          'row $key moved from ${then.name} back to ${now.name}',
        );
      }
    }
  }

  /// Throws [StateError] naming the first clause violated.
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
  }

  void _assertKeysMatchIDs() {
    for (final MapEntry(:key, :value) in _moneySources.entries) {
      if (key != value.id) {
        throw _violation(1, 'money source $key holds ${value.id}');
      }
    }
    for (final MapEntry(:key, :value) in _entries.entries) {
      if (key != value.id) throw _violation(1, 'entry $key holds ${value.id}');
    }
    for (final MapEntry(:key, :value) in _categories.entries) {
      if (key != value.id) {
        throw _violation(1, 'category $key holds ${value.id}');
      }
    }
  }

  void _assertPocketLinksResolveAndAreExclusive() {
    final claimedBy = <String, String>{};
    for (final account in _accounts) {
      for (final pocketID in account.subPocketIDs) {
        if (_moneySources[pocketID]?.asPocket == null) {
          throw _violation(
            2,
            'account ${account.id} links unresolved $pocketID',
          );
        }

        final other = claimedBy[pocketID];
        if (other != null) {
          throw _violation(
            2,
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
        throw _violation(3, 'pocket ${pocket.id} has no owning account');
      }
    }
  }

  void _assertNoDanglingEntryReference() {
    for (final entry in _entries.values) {
      for (final holderID in entry.holderIDs) {
        if (!_moneySources.containsKey(holderID)) {
          throw _violation(4, 'entry ${entry.id} references unknown $holderID');
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
        throw _violation(5, 'category ${category.id} has unknown parent');
      }
      if (parent.parentID != null) {
        throw _violation(5, 'category ${category.id} nests below depth 2');
      }
      if (parent.kind != category.kind) {
        throw _violation(5, 'category ${category.id} kind differs from parent');
      }

      // An archived parent is fine, since archiving cascades to children. A
      // referenceOnly or tombstoned one should have taken the child down too.
      if (!parent.lifecycle.isAtLeastAsAliveAs(category.lifecycle) &&
          !parent.lifecycle.isAtLeastAsAliveAs(LifecycleState.archived)) {
        throw _violation(
          5,
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
        throw _violation(6, 'transfer ${entry.id} carries a category');
      }
      if (category.kind != expected) {
        throw _violation(6, 'entry ${entry.id} kind differs from its category');
      }
    }
  }

  void _assertNoDanglingPlanReference() {
    for (final plan in _plans.values) {
      for (final holderID in plan.template.holderIDs) {
        if (!_moneySources.containsKey(holderID)) {
          throw _violation(7, 'plan ${plan.id} references unknown $holderID');
        }
      }

      final categoryID = plan.template.categoryID;
      if (categoryID != null && !_categories.containsKey(categoryID)) {
        throw _violation(7, 'plan ${plan.id} references unknown $categoryID');
      }
    }
  }

  void _assertNoExhaustedPlanStored() {
    for (final plan in _plans.values) {
      final endDate = plan.endDate;
      if (endDate == null) continue;

      if (!plan.lastResolvedDate.isBefore(endDate)) {
        throw _violation(8, 'plan ${plan.id} is stored exhausted');
      }
    }
  }

  void _assertEntriesActive() {
    for (final entry in _entries.values) {
      if (!entry.lifecycle.isActive) {
        throw _violation(9, 'entry ${entry.id} is ${entry.lifecycle.name}');
      }
    }
  }

  void _assertNoStoredTombstone() {
    for (final source in _moneySources.values) {
      if (source.lifecycle == LifecycleState.tombstoned) {
        throw _violation(10, 'money source ${source.id} is stored tombstoned');
      }
    }
    for (final category in _categories.values) {
      if (category.lifecycle == LifecycleState.tombstoned) {
        throw _violation(10, 'category ${category.id} is stored tombstoned');
      }
    }
  }

  void _assertReferenceOnlyImpliesReferenced() {
    for (final category in _categories.values) {
      if (category.lifecycle != LifecycleState.referenceOnly) continue;

      if (_isCategoryReferenced(category.id)) continue;

      throw _violation(
        11,
        'referenceOnly category ${category.id} unreferenced',
      );
    }

    for (final source in _moneySources.values) {
      if (source.lifecycle != LifecycleState.referenceOnly) continue;
      if (_isHolderReferenced(source.id)) continue;

      throw _violation(11, 'referenceOnly ${source.id} has no reference');
    }
  }

  // The mutators clamp on the write path. This catches a row that arrived
  // through the seeding constructor or a future import instead.
  void _assertStatementDayInRange() {
    for (final account in _accounts) {
      final statementDay = account.statementDay;
      if (account.type != AccountType.card) {
        if (statementDay != null) {
          throw _violation(
            13,
            '${account.type.name} account ${account.id} carries a statement day',
          );
        }
        continue;
      }

      if (statementDay != null && (statementDay < 1 || statementDay > 28)) {
        throw _violation(
          13,
          'card ${account.id} has statement day $statementDay',
        );
      }
    }
  }

  // Lifecycle only, existence is covered elsewhere. An archived row is legal
  // since archiving freezes a plan; a leaving row means a cascade missed it.
  void _assertPlansReferenceActiveRows() {
    bool isLeaving(LifecycleState lifecycle) =>
        lifecycle == LifecycleState.referenceOnly ||
        lifecycle == LifecycleState.tombstoned;

    for (final plan in _plans.values) {
      for (final holderID in plan.template.holderIDs) {
        final holder = _moneySources[holderID];
        if (holder == null || !isLeaving(holder.lifecycle)) continue;

        throw _violation(
          14,
          'plan ${plan.id} references ${holder.lifecycle.name} $holderID',
        );
      }

      final categoryID = plan.template.categoryID;
      if (categoryID == null) continue;

      final category = _categories[categoryID];
      if (category == null || !isLeaving(category.lifecycle)) continue;

      throw _violation(
        14,
        'plan ${plan.id} references ${category.lifecycle.name} $categoryID',
      );
    }
  }

  // updatePocket enforces this on the write path but only judges the child,
  // so a path that moves the parent instead escapes it uncaught until here.
  void _assertPocketNotMoreAliveThanAccount() {
    for (final account in _accounts) {
      for (final pocketID in account.subPocketIDs) {
        final pocket = _moneySources[pocketID]?.asPocket;
        if (pocket == null) continue;

        if (!account.lifecycle.isAtLeastAsAliveAs(pocket.lifecycle)) {
          throw _violation(
            15,
            '${account.lifecycle.name} account ${account.id} holds '
            '${pocket.lifecycle.name} pocket $pocketID',
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
