part of 'ledger_state.dart';

extension LedgerStateSweep on LedgerState {
  // MARK: - Sweep

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
      ..._removeBudgetCategorized(categoryID),
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

    final parent = _owningAccount(holderID);
    final changes = [
      ..._detachAndTombstonePocket(holderID),
      ..._removePlansReferencing({holderID}),
    ];
    if (parent == null) return changes;

    return [...changes, ..._sweepHolder(parent.id)];
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
}
