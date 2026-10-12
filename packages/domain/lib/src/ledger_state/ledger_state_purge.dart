part of 'ledger_state.dart';

extension LedgerStatePurge on LedgerState {
  // MARK: - Holder purge

  List<LedgerChange> purgeAccount(String rawID) {
    final id = normalizedID(rawID);
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
    final id = normalizedID(rawID);
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

  // MARK: - Category purge

  List<LedgerChange> purgeCategory(String rawID) {
    final id = normalizedID(rawID);
    final category = _categories[id];
    if (category == null || category.lifecycle != LifecycleState.archived) {
      return _checked([]);
    }

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
      ..._removeBudgetCategorized(category.id),
    ];
  }
}
