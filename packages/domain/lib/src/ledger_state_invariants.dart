part of 'ledger_state.dart';

extension LedgerStateInvariants on LedgerState {
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

      throw _violation(11, 'referenceOnly category ${category.id} unreferenced');
    }

    for (final source in _moneySources.values) {
      if (source.lifecycle != LifecycleState.referenceOnly) continue;
      if (_isHolderReferenced(source.id)) continue;

      throw _violation(11, 'referenceOnly ${source.id} has no reference');
    }
  }

  Iterable<Account> get _accounts =>
      _moneySources.values.map((source) => source.asAccount).nonNulls;

  StateError _violation(int clause, String detail) =>
      StateError('Ledger invariant $clause violated: $detail');
}
