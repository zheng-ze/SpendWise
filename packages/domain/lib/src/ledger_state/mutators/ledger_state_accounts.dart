part of '../ledger_state.dart';

extension LedgerStateAccounts on LedgerState {
  // MARK: - Mutators

  List<LedgerChange> _addAccount(Account account) {
    if (_moneySources.containsKey(account.id)) {
      throw IdCollision(account.id);
    }
    final stored = account
        .withNormalizedStatementDay()
        .withEligibleTransferFlag()
        .withSubPockets(const {});
    _moneySources[stored.id] = AccountSource(stored);
    return _checked([UpsertAccount(stored)]);
  }

  List<LedgerChange> _updateAccount(Account account) {
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

  // MARK: - Deletion and restore

  List<LedgerChange> _deleteAccount(String rawID) {
    final id = normalizedID(rawID);
    final account = _moneySources[id]?.asAccount;
    if (account == null || !account.lifecycle.isActive) return _checked([]);

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

  List<LedgerChange> _restoreAccount(String rawID) {
    final id = normalizedID(rawID);
    final account = _moneySources[id]?.asAccount;
    if (account == null || account.lifecycle != LifecycleState.archived) {
      return _checked([]);
    }

    return _checked(
      _moveAccountTree(
        account,
        from: LifecycleState.archived,
        to: LifecycleState.active,
      ),
    );
  }

  // MARK: - Helpers

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
}
