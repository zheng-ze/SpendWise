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
  /// A `referenceOnly` pocket keeps its parent: purge pins the parent too
  /// rather than detaching it.
  Account? owningAccount(String rawPocketID) =>
      _owningAccount(canonicalID(rawPocketID));

  String? sourceName(String? rawID) {
    final id = canonicalOptionalID(rawID);
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
    final holderID = canonicalID(rawHolderID);
    return _entries.values.where((entry) => entry.references(holderID)).length;
  }

  int entryCount(Set<String> rawIDs) {
    final ids = rawIDs.map(canonicalID).toSet();
    return _entries.values.where((entry) => entry.touches(ids)).length;
  }

  int entryCountReferencing(String rawCategoryID) {
    final categoryID = canonicalID(rawCategoryID);
    return _entries.values
        .where((entry) => entry.categoryID == categoryID)
        .length;
  }

  /// Expects an already-canonical id. Decides referenceOnly versus tombstone
  /// for both the purge rule and the dereference sweep.
  ///
  /// A parent counts as referenced through a pocket only when that pocket is
  /// itself referenced, not merely because its row is still in the table. The
  /// weaker test would pin a parent at referenceOnly forever if a tombstoned
  /// pocket ever failed to clear, since nothing would re-examine the link.
  /// Rows already gone are skipped so a stale id can never revive a parent.
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
}
