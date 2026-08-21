part of 'ledger_state.dart';

extension LedgerStateQueries on LedgerState {
  Set<String> get activeSources => _sourceIDsWith(LifecycleState.active);

  Set<String> get binnedSources => _sourceIDsWith(LifecycleState.archived);

  Set<String> get activeCategories => _categoryIDsWith(LifecycleState.active);

  Set<String> get binnedCategories => _categoryIDsWith(LifecycleState.archived);

  List<Account> get activeAccounts {
    final accounts = _moneySources.values
        .map((source) => source.asAccount)
        .nonNulls
        .where((account) => account.lifecycle.isActive)
        .toList();
    accounts.sort((a, b) => a.name.compareTo(b.name));
    return accounts;
  }

  List<SubPocket> activePockets(Account account) {
    final pockets = account.subPocketIDs
        .map((id) => _moneySources[id]?.asPocket)
        .nonNulls
        .where((pocket) => pocket.lifecycle.isActive)
        .toList();
    pockets.sort((a, b) => a.name.compareTo(b.name));
    return pockets;
  }

  /// Null for an account, an unknown id, or a pocket no account still holds.
  /// Resolves a `referenceOnly` pocket too, since its account link stays live.
  Account? owningAccount(String rawPocketID) =>
      _owningAccount(normalizedID(rawPocketID));

  String? sourceName(String? rawID) {
    final id = normalizedOptionalID(rawID);
    if (id == null) return null;
    switch (_moneySources[id]) {
      case null:
        return null;
      case AccountSource(:final account):
        return account.name;
      case PocketSource(:final pocket):
        final parent = _owningAccount(id);
        return parent == null ? pocket.name : '${parent.name}/${pocket.name}';
    }
  }

  int entriesReferencing(String rawHolderID) {
    final holderID = normalizedID(rawHolderID);
    return _entries.values.where((entry) => entry.references(holderID)).length;
  }

  int entryCount(Set<String> rawIDs) {
    final ids = rawIDs.map(normalizedID).toSet();
    return _entries.values.where((entry) => entry.touches(ids)).length;
  }

  int entryCountReferencing(String rawCategoryID) {
    final categoryID = normalizedID(rawCategoryID);
    return _entries.values
        .where((entry) => entry.categoryID == categoryID)
        .length;
  }

  // Expects an already-normalized id. A parent counts as referenced through a
  // pocket only when that pocket is itself referenced, not merely present.
  bool _isHolderReferenced(String holderID) {
    final source = _moneySources[holderID];
    if (source == null) return false;
    if (entriesReferencing(holderID) > 0) return true;

    final account = source.asAccount;
    if (account == null) return false;

    return account.subPocketIDs
        .where(_moneySources.containsKey)
        .any(_isHolderReferenced);
  }

  Set<String> _sourceIDsWith(LifecycleState lifecycle) => _moneySources.values
      .where((source) => source.lifecycle == lifecycle)
      .map((source) => source.id)
      .toSet();

  Set<String> _categoryIDsWith(LifecycleState lifecycle) => _categories.values
      .where((category) => category.lifecycle == lifecycle)
      .map((category) => category.id)
      .toSet();

  Account? _owningAccount(String pocketID) => _moneySources.values
      .map((source) => source.asAccount)
      .nonNulls
      .where((account) => account.subPocketIDs.contains(pocketID))
      .firstOrNull;

  List<TransactionCategory> categoriesGroupedByParent(CategoryKind kind) {
    final active = activeCategories;
    final matching = categories.values
        .where(
          (category) => active.contains(category.id) && category.kind == kind,
        )
        .toList();

    final roots =
        matching.where((category) => category.parentID == null).toList()
          ..sort(_byName);
    final childrenByParent = <String, List<TransactionCategory>>{};
    for (final category in matching) {
      final parentID = category.parentID;
      if (parentID == null) continue;

      childrenByParent.putIfAbsent(parentID, () => []).add(category);
    }
    for (final children in childrenByParent.values) {
      children.sort(_byName);
    }

    return [
      for (final root in roots) ...[root, ...?childrenByParent[root.id]],
    ];
  }

  // Ordinal, so the order is identical on every platform.
  static int _byName(TransactionCategory a, TransactionCategory b) =>
      a.name.compareTo(b.name);
}
