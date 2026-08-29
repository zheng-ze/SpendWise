part of 'ledger_state.dart';

extension LedgerStateHolders on LedgerState {
  List<LedgerChange> addAccount(Account account) {
    if (_moneySources.containsKey(account.id)) {
      throw IdCollision(account.id);
    }
    // Links are owned by pocket creation, so a caller-supplied set is dropped.
    final stored = account
        .withNormalizedStatementDay()
        .withEligibleTransferFlag()
        .withSubPockets(const {});
    _moneySources[stored.id] = AccountSource(stored);
    return _checked([UpsertAccount(stored)]);
  }

  /// An edit can neither add nor drop a pocket link.
  // Links come from the stored row. Only addPocket and the purge detach may
  // move them.
  List<LedgerChange> updateAccount(Account account) {
    final existing = _moneySources[account.id]?.asAccount;
    if (existing == null) throw UnknownAccount(account.id);

    final stored = account
        .withNormalizedStatementDay()
        .withEligibleTransferFlag()
        .withSubPockets(existing.subPocketIDs)
        .settingLifecycle(_editableLifecycle(existing.lifecycle));
    _moneySources[stored.id] = AccountSource(stored);
    return _checked([UpsertAccount(stored), ..._demotePocketsBelow(stored)]);
  }

  // A pocket may never be more alive than its account, so an edit that moves
  // the parent down has to carry its pockets down with it.
  List<LedgerChange> _demotePocketsBelow(Account account) {
    final changes = <LedgerChange>[];
    for (final pocketID in account.subPocketIDs) {
      final pocket = _moneySources[pocketID]?.asPocket;
      if (pocket == null ||
          account.lifecycle.isAtLeastAsAliveAs(pocket.lifecycle)) {
        continue;
      }

      final demoted = pocket.settingLifecycle(account.lifecycle);
      _moneySources[pocketID] = PocketSource(demoted);
      changes.add(UpsertPocket(demoted));
    }
    return changes;
  }

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

  bool _willOutliveParentAccount(SubPocket pocket) {
    final parent = _owningAccount(pocket.id);
    if (parent == null) return true;

    return !parent.lifecycle.isAtLeastAsAliveAs(pocket.lifecycle);
  }

  List<LedgerChange> deleteAccount(String rawID) {
    final id = normalizedID(rawID);
    final account = _moneySources[id]?.asAccount;
    if (account == null || !account.lifecycle.isActive) return _checked([]);

    // Links are kept so restore can find the pockets again.
    final changes = _moveAccountTree(
      account,
      from: LifecycleState.active,
      to: LifecycleState.archived,
    );
    return _checked([
      ...changes,
      ..._removePlansReferencing({id, ...account.subPocketIDs}),
    ]);
  }

  List<LedgerChange> _moveAccountTree(
    Account account, {
    required LifecycleState from,
    required LifecycleState to,
  }) {
    final moved = account.settingLifecycle(to);
    _moneySources[moved.id] = AccountSource(moved);
    final changes = <LedgerChange>[UpsertAccount(moved)];

    for (final pocketID in moved.subPocketIDs) {
      final pocket = _moneySources[pocketID]?.asPocket;
      if (pocket == null || pocket.lifecycle != from) continue;

      final movedPocket = pocket.settingLifecycle(to);
      _moneySources[pocketID] = PocketSource(movedPocket);
      changes.add(UpsertPocket(movedPocket));
    }
    return changes;
  }

  List<LedgerChange> deletePocket(String rawID) {
    final id = normalizedID(rawID);
    final pocket = _moneySources[id]?.asPocket;
    if (pocket == null || !pocket.lifecycle.isActive) return _checked([]);

    // No plan cascade here. Archiving freezes plans so a restore is not lossy,
    // and their occurrences fail validation meanwhile, which resolving reports.
    final archived = pocket.settingLifecycle(LifecycleState.archived);
    _moneySources[id] = PocketSource(archived);
    return _checked([UpsertPocket(archived)]);
  }

  List<LedgerChange> restoreAccount(String rawID) {
    final id = normalizedID(rawID);
    final account = _moneySources[id]?.asAccount;
    if (account == null || account.lifecycle != LifecycleState.archived) {
      return _checked([]);
    }

    // referenceOnly pockets stay put, having left the bin permanently.
    return _checked(
      _moveAccountTree(
        account,
        from: LifecycleState.archived,
        to: LifecycleState.active,
      ),
    );
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
}
