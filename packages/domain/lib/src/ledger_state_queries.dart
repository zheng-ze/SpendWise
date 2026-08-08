part of 'ledger_state.dart';

extension LedgerStateQueries on LedgerState {
  Set<String> get activeSources => _sourceIDsWith(LifecycleState.active);

  Set<String> get binnedSources => _sourceIDsWith(LifecycleState.archived);

  Set<String> get activeCategories => _categoryIDsWith(LifecycleState.active);

  Set<String> get binnedCategories => _categoryIDsWith(LifecycleState.archived);

  List<Account> get activeAccounts {
    final accounts = moneySources.values
        .map((source) => source.asAccount)
        .nonNulls
        .where((account) => account.lifecycle.isActive)
        .toList();
    accounts.sort((a, b) => a.name.compareTo(b.name));
    return accounts;
  }

  List<SubPocket> activePockets(Account account) {
    final pockets = account.subPocketIDs
        .map((id) => moneySources[id]?.asPocket)
        .nonNulls
        .where((pocket) => pocket.lifecycle.isActive)
        .toList();
    pockets.sort((a, b) => a.name.compareTo(b.name));
    return pockets;
  }

  String? sourceName(String? id) {
    if (id == null) return null;
    switch (moneySources[id]) {
      case null:
        return null;
      case AccountSource(:final account):
        return account.name;
      case PocketSource(:final pocket):
        final parent = _owningAccount(id);
        return parent == null ? pocket.name : '${parent.name}/${pocket.name}';
    }
  }

  int entriesReferencing(String holderID) =>
      entries.values.where((entry) => entry.references(holderID)).length;

  int entryCount(Set<String> ids) =>
      entries.values.where((entry) => entry.touches(ids)).length;

  int entryCountReferencing(String categoryID) =>
      entries.values.where((entry) => entry.categoryID == categoryID).length;

  Set<String> _sourceIDsWith(LifecycleState lifecycle) => moneySources.values
      .where((source) => source.lifecycle == lifecycle)
      .map((source) => source.id)
      .toSet();

  Set<String> _categoryIDsWith(LifecycleState lifecycle) => categories.values
      .where((category) => category.lifecycle == lifecycle)
      .map((category) => category.id)
      .toSet();

  Account? _owningAccount(String pocketID) => moneySources.values
      .map((source) => source.asAccount)
      .nonNulls
      .where((account) => account.subPocketIDs.contains(pocketID))
      .firstOrNull;
}
