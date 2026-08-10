part of 'ledger_state.dart';

extension LedgerStateCategories on LedgerState {
  List<LedgerChange> addCategory(TransactionCategory category) {
    if (_categories.containsKey(category.id)) throw IdCollision(category.id);

    _validateParent(category);
    _categories[category.id] = category;
    return _checked([UpsertCategory(category)]);
  }

  List<LedgerChange> updateCategory(TransactionCategory category) {
    final existing = _categories[category.id];
    if (existing == null) throw UnknownCategory(category.id);

    // Kind is fixed at creation: a swap would strand both the entries whose
    // sign it contradicts and the children that inherit it.
    if (existing.kind != category.kind) throw const CategoryKindMismatch();

    // Max depth is two, so a subcategory cannot have children of its own.
    if (category.parentID != null && _children(category.id).isNotEmpty) {
      throw const CategoryTooDeep();
    }

    _validateParent(category);

    final requested = category.settingLifecycle(
      _editableLifecycle(category.lifecycle, existing.lifecycle),
    );
    final stored = _willOutliveParentCategory(requested)
        ? requested.settingLifecycle(existing.lifecycle)
        : requested;
    _categories[stored.id] = stored;

    // A parent held up solely by this child's link is re-judged once it moves.
    final droppedParent = existing.parentID == stored.parentID
        ? null
        : existing.parentID;
    return _checked([
      UpsertCategory(stored),
      if (droppedParent != null) ..._sweepCategory(droppedParent),
    ]);
  }

  bool _willOutliveParentCategory(TransactionCategory category) {
    final parentID = category.parentID;
    if (parentID == null) return false;

    final parent = _categories[parentID];
    if (parent == null) return false;

    return !parent.lifecycle.isAtLeastAsAliveAs(category.lifecycle);
  }

  List<LedgerChange> deleteCategory(String rawID) {
    final id = canonicalID(rawID);
    final category = _categories[id];
    if (category == null || !category.lifecycle.isActive) return _checked([]);

    // Archiving freezes plans rather than dropping them, as for a pocket.
    return _checked(
      _moveCategoryTree(
        category,
        from: LifecycleState.active,
        to: LifecycleState.archived,
      ),
    );
  }

  List<LedgerChange> restoreCategory(String rawID) {
    final id = canonicalID(rawID);
    final category = _categories[id];
    if (category == null || category.lifecycle != LifecycleState.archived) {
      return _checked([]);
    }
    final parentID = category.parentID;
    if (parentID != null &&
        _categories[parentID]?.lifecycle == LifecycleState.archived) {
      return _checked([]);
    }

    return _checked(
      _moveCategoryTree(
        category,
        from: LifecycleState.archived,
        to: LifecycleState.active,
      ),
    );
  }

  /// The parent moves first, then every child sitting in [from]. A child in any
  /// other state is left where it is: `referenceOnly` has left the bin for good,
  /// and an already-archived child must not be dragged along by an archive.
  List<LedgerChange> _moveCategoryTree(
    TransactionCategory category, {
    required LifecycleState from,
    required LifecycleState to,
  }) {
    final moved = category.settingLifecycle(to);
    _categories[moved.id] = moved;
    final changes = <LedgerChange>[UpsertCategory(moved)];

    for (final child in _children(category.id)) {
      if (child.lifecycle != from) continue;

      final movedChild = child.settingLifecycle(to);
      _categories[child.id] = movedChild;
      changes.add(UpsertCategory(movedChild));
    }
    return changes;
  }

  List<TransactionCategory> _children(String parentID) => _categories.values
      .where((category) => category.parentID == parentID)
      .toList();

  void _validateParent(TransactionCategory category) {
    final parentID = category.parentID;
    if (parentID == null) return;

    // A category cannot be its own parent.
    if (parentID == category.id) throw const CategoryTooDeep();

    final parent = _categories[parentID];
    if (parent == null) throw UnknownCategory(parentID);
    if (parent.parentID != null) throw const CategoryTooDeep();
    if (parent.kind != category.kind) throw const CategoryKindMismatch();

    // An archived parent is allowed, since purgeCategory sweeps children
    // regardless of lifecycle. A `referenceOnly` one is rejected because the
    // dereference sweep deletes it without looking for children, orphaning
    // the child.
    if (!parent.lifecycle.isAtLeastAsAliveAs(LifecycleState.archived)) {
      throw InactiveReference(parentID);
    }
  }
}
