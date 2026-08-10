part of 'ledger_state.dart';

extension LedgerStatePurge on LedgerState {
  /// Pockets settle first so the account sees their survival when it judges its
  /// own referencedness.
  List<LedgerChange> purgeAccount(String rawID) {
    final id = canonicalID(rawID);
    final account = _moneySources[id]?.asAccount;
    if (account == null || account.lifecycle != LifecycleState.archived) {
      return _checked([]);
    }

    final changes = <LedgerChange>[];
    for (final pocketID in account.subPocketIDs.toList()) {
      final pocket = _moneySources[pocketID]?.asPocket;
      if (pocket == null) continue;

      changes.addAll(_purgeHolder(pocketID));
    }

    return _checked([...changes, ..._purgeHolder(id)]);
  }

  List<LedgerChange> purgePocket(String rawID) {
    final id = canonicalID(rawID);
    final pocket = _moneySources[id]?.asPocket;
    if (pocket == null || pocket.lifecycle != LifecycleState.archived) {
      return _checked([]);
    }
    return _checked(_purgeHolder(id));
  }

  List<LedgerChange> _purgeHolder(String holderID) {
    if (!_isHolderReferenced(holderID)) {
      final pocket = _moneySources[holderID]?.asPocket;
      if (pocket != null) return _detachAndTombstonePocket(holderID);

      _moneySources.remove(holderID);
      return [DeleteMoneySource(holderID)];
    }

    final kept = _moneySources[holderID]!.settingLifecycle(
      LifecycleState.referenceOnly,
    );
    _moneySources[holderID] = kept;
    return [LedgerChange.upsertSource(kept)];
  }

  /// The parent upsert precedes the deletion, so a consumer replaying the
  /// changes never sees the link outlive the row.
  List<LedgerChange> _detachAndTombstonePocket(String pocketID) {
    final parent = _owningAccount(pocketID);
    final changes = <LedgerChange>[];

    if (parent != null) {
      final detached = parent.removeSubPocket(pocketID);
      _moneySources[detached.id] = AccountSource(detached);
      changes.add(UpsertAccount(detached));
    }

    _moneySources.remove(pocketID);
    changes.add(DeleteMoneySource(pocketID));
    return changes;
  }

  List<LedgerChange> purgeCategory(String rawID) {
    final id = canonicalID(rawID);
    final category = _categories[id];
    if (category == null || category.lifecycle != LifecycleState.archived) {
      return _checked([]);
    }

    // Children go regardless of lifecycle, unlike the archive and restore
    // cascades, so an active child cannot outlive the row it hangs from. They
    // sweep first so a survivor is visible when the parent is judged, but emit
    // after it.
    final childChanges = [
      for (final child in _children(id)) ..._purgeCategoryRow(child),
    ];
    return _checked([..._purgeCategoryRow(category), ...childChanges]);
  }

  List<LedgerChange> _purgeCategoryRow(TransactionCategory category) {
    if (_isCategoryReferenced(category.id)) {
      final kept = category.settingLifecycle(LifecycleState.referenceOnly);
      _categories[kept.id] = kept;
      return [UpsertCategory(kept)];
    }

    _categories.remove(category.id);
    return [
      DeleteCategory(category.id),
      ..._removePlansCategorized(category.id),
    ];
  }

  bool _isCategoryReferenced(String id, [Set<String>? seen]) {
    final visited = seen ?? <String>{};
    if (!visited.add(id)) return false;
    if (!_categories.containsKey(id)) return false;
    if (entryCountReferencing(id) > 0) return true;

    return _children(
      id,
    ).any((child) => _isCategoryReferenced(child.id, visited));
  }

  /// The only referenceOnly to tombstoned path. Holders sweep before the
  /// category so a holder losing its last reference cannot be missed.
  List<LedgerChange> _tombstoneDereferenced(
    Set<String> holders,
    String? category,
  ) {
    final changes = <LedgerChange>[];
    for (final holderID in holders) {
      changes.addAll(_sweepHolder(holderID));
    }

    if (category == null) return changes;

    return [...changes, ..._sweepCategory(category)];
  }

  List<LedgerChange> _sweepCategory(String categoryID) {
    final stored = _categories[categoryID];
    if (stored == null ||
        stored.lifecycle != LifecycleState.referenceOnly ||
        _isCategoryReferenced(categoryID)) {
      return [];
    }

    final parentID = stored.parentID;
    _categories.remove(categoryID);
    final changes = <LedgerChange>[
      DeleteCategory(categoryID),
      ..._removePlansCategorized(categoryID),
    ];
    if (parentID == null) return changes;

    return [...changes, ..._sweepCategory(parentID)];
  }

  List<LedgerChange> _sweepHolder(String holderID) {
    final source = _moneySources[holderID];
    if (source == null ||
        source.lifecycle != LifecycleState.referenceOnly ||
        _isHolderReferenced(holderID)) {
      return [];
    }

    if (source.asPocket == null) {
      _moneySources.remove(holderID);
      return [
        DeleteMoneySource(holderID),
        ..._removePlansReferencing({holderID}),
      ];
    }

    // Read before the detach below, which clears the link.
    final parent = _owningAccount(holderID);
    final changes = [
      ..._detachAndTombstonePocket(holderID),
      ..._removePlansReferencing({holderID}),
    ];
    if (parent == null) return changes;

    return [...changes, ..._sweepHolder(parent.id)];
  }
}
