part of 'ledger_state.dart';

extension LedgerStatePockets on LedgerState {
  // MARK: - Mutators

  List<LedgerChange> addPocket(SubPocket pocket, String rawAccountID) {
    final accountID = normalizedID(rawAccountID);
    final parent = _moneySources[accountID]?.asAccount;
    if (parent == null) throw UnknownAccount(accountID);
    if (_moneySources.containsKey(pocket.id)) throw IdCollision(pocket.id);
    if (!parent.lifecycle.isActive) throw InactiveReference(accountID);

    final linked = parent.addSubPocket(pocket.id);
    _moneySources[pocket.id] = PocketSource(pocket);
    _moneySources[linked.id] = AccountSource(linked);
    return _checked([UpsertPocket(pocket), UpsertAccount(linked)]);
  }

  List<LedgerChange> updatePocket(SubPocket pocket) {
    final existing = _moneySources[pocket.id]?.asPocket;
    if (existing == null) throw UnknownHolder(pocket.id);

    final requested = pocket.settingLifecycle(
      _editableLifecycle(existing.lifecycle),
    );
    final stored = _willOutliveParentAccount(requested)
        ? requested.settingLifecycle(existing.lifecycle)
        : requested;
    _moneySources[stored.id] = PocketSource(stored);
    return _checked([UpsertPocket(stored)]);
  }

  // MARK: - Deletion and restore

  List<LedgerChange> deletePocket(String rawID) {
    final id = normalizedID(rawID);
    final pocket = _moneySources[id]?.asPocket;
    if (pocket == null || !pocket.lifecycle.isActive) return _checked([]);

    final archived = pocket.settingLifecycle(LifecycleState.archived);
    _moneySources[id] = PocketSource(archived);
    return _checked([UpsertPocket(archived)]);
  }

  List<LedgerChange> restorePocket(String rawID) {
    final id = normalizedID(rawID);
    final pocket = _moneySources[id]?.asPocket;
    if (pocket == null || pocket.lifecycle != LifecycleState.archived) {
      return _checked([]);
    }
    final restored = pocket.settingLifecycle(LifecycleState.active);
    if (_willOutliveParentAccount(restored)) return _checked([]);

    _moneySources[id] = PocketSource(restored);
    return _checked([UpsertPocket(restored)]);
  }

  // MARK: - Helpers

  bool _willOutliveParentAccount(SubPocket pocket) {
    final parent = _owningAccount(pocket.id);
    if (parent == null) return true;

    return !parent.lifecycle.isAtLeastAsAliveAs(pocket.lifecycle);
  }
}
